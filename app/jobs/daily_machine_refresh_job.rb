# frozen_string_literal: true

require "rake"

# Daily job to sync machine master and shop machines from DMMぱちタウン.
# Each step runs independently — a failure in one step doesn't block the next.
class DailyMachineRefreshJob < ApplicationJob
  include StepRunner

  queue_as :default

  def perform
    return if Date.current.day == 1

    $stdout.sync = true
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    run_step("import_machines") do
      Rake::Task["ptown:import_machines"].invoke
      Rake::Task["ptown:import_machines"].reenable
    end

    run_step("sync_shop_machines") do
      Rake::Task["ptown:sync_shop_machines"].invoke
      Rake::Task["ptown:sync_shop_machines"].reenable
    end

    run_step("cleanup") { deactivate_orphan_machines }

    log_summary
  end

  private

  def log_summary
    active = MachineModel.where(active: true).count
    synced = Shop.where.not(last_synced_at: nil).where(last_synced_at: 24.hours.ago..).count
    total = Shop.where.not(ptown_shop_id: nil).count
    smm = ShopMachineModel.count
    Rails.logger.info("[#{log_prefix}] サマリー: アクティブ機種=#{active}, 同期済み店舗=#{synced}/#{total}, SMM=#{smm}")
  end
end
