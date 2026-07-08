# frozen_string_literal: true

require "rake"

# Monthly job to fully sync shops, machines, and details from DMMぱちタウン.
# sync_shop_machines フェーズが47都道府県を1回のジョブ実行時間内に処理しきれないため、
# MonthlySyncProgress で都道府県単位の進捗を永続化し、cron の複数日実行
# (render.yaml: 毎月1〜5日) にまたがって再開できるようにしている。
# Each step runs independently — a failure in one step doesn't block the next.
class MonthlyShopDetailsJob < ApplicationJob
  include StepRunner

  queue_as :default

  SYNC_SHOP_MACHINES_TIME_BUDGET = 10.hours

  def perform
    $stdout.sync = true
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    progress = MonthlySyncProgress.current_cycle

    if progress.completed?
      Rails.logger.info("[#{log_prefix}] #{progress.cycle_month} は既に同期完了済みのためスキップ")
      return
    end

    unless progress.shops_imported?
      run_step("import_shops") do
        Rake::Task["ptown:import_shops"].invoke
        Rake::Task["ptown:import_shops"].reenable
      end
      progress.update!(shops_imported: true)
    end

    unless progress.machines_imported?
      run_step("import_machines") do
        Rake::Task["ptown:import_machines"].invoke
        Rake::Task["ptown:import_machines"].reenable
      end
      progress.update!(machines_imported: true)
    end

    unless progress.details_imported?
      run_step("import_details") do
        Rake::Task["ptown:import_details"].invoke
        Rake::Task["ptown:import_details"].reenable
      end
      progress.update!(details_imported: true)
    end

    deadline = Time.current + SYNC_SHOP_MACHINES_TIME_BUDGET
    run_step("sync_shop_machines") do
      ENV["FORCE"] = "1"
      progress.remaining_prefectures.each do |pref|
        break if Time.current > deadline

        Rake::Task["ptown:sync_shop_machines"].invoke(pref.slug)
        Rake::Task["ptown:sync_shop_machines"].reenable
        progress.update!(last_synced_prefecture_id: pref.id)
      end
      ENV.delete("FORCE")
    end

    if progress.remaining_prefectures.empty?
      run_step("geocode_shops") do
        Rake::Task["geocode:shops"].invoke
        Rake::Task["geocode:shops"].reenable
      end

      run_step("merge_duplicates") do
        Rake::Task["ptown:merge_duplicates"].invoke
        Rake::Task["ptown:merge_duplicates"].reenable
      end

      run_step("cleanup") { deactivate_orphan_machines }

      progress.update!(completed: true)
      log_summary
    else
      Rails.logger.info("[#{log_prefix}] #{progress.remaining_prefectures.count}都道府県が未処理。次回cron実行で継続")
    end
  end

  private

  def log_summary
    shops = Shop.count
    active = MachineModel.where(active: true).count
    synced = Shop.where.not(last_synced_at: nil).count
    smm = ShopMachineModel.count
    Rails.logger.info("[#{log_prefix}] サマリー: 店舗=#{shops}, アクティブ機種=#{active}, 同期済み=#{synced}/#{shops}, SMM=#{smm}")
  end
end
