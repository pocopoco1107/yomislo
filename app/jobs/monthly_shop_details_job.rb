# frozen_string_literal: true

require "rake"

# Monthly job to fully sync shops, machines, and details from DMMぱちタウン.
# Each step runs independently — a failure in one step doesn't block the next.
class MonthlyShopDetailsJob < ApplicationJob
  include StepRunner

  queue_as :default

  def perform
    $stdout.sync = true
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    run_step("import_shops") do
      Rake::Task["ptown:import_shops"].invoke
      Rake::Task["ptown:import_shops"].reenable
    end

    run_step("import_machines") do
      Rake::Task["ptown:import_machines"].invoke
      Rake::Task["ptown:import_machines"].reenable
    end

    run_step("import_details") do
      Rake::Task["ptown:import_details"].invoke
      Rake::Task["ptown:import_details"].reenable
    end

    run_step("sync_shop_machines") do
      ENV["FORCE"] = "1"
      Rake::Task["ptown:sync_shop_machines"].invoke
      Rake::Task["ptown:sync_shop_machines"].reenable
      ENV.delete("FORCE")
    end

    # 新規店舗（lat/lng が NULL）を GSI + Nominatim でジオコード。
    # Monthly は新店追加が一気に走るため、ここで埋めておかないと「現在地から探す」に
    # 1ヶ月間出てこない期間が生じる。Daily にも同等のステップが入っており冗長安全策。
    run_step("geocode_shops") do
      Rake::Task["geocode:shops"].invoke
      Rake::Task["geocode:shops"].reenable
    end

    run_step("cleanup") { deactivate_orphan_machines }

    log_summary
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
