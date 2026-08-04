# frozen_string_literal: true

require "rake"

# Daily job to sync machine master and shop machines from DMMぱちタウン.
# Each step runs independently — a failure in one step doesn't block the next.
class DailyMachineRefreshJob < ApplicationJob
  include StepRunner

  queue_as :default

  def perform
    # yomislo-monthly は都道府県単位のチェックポイント再開のため UTC 1〜5日に再実行される。
    # 両ジョブとも 18:00 UTC 起動 = JST 翌日 03:00 なので、monthly が動くのは JST 2〜6日。
    # その期間中に月次サイクルが未完了なら、DMMぱちタウンへの同時アクセスを避けるためdailyを休止する。
    return if (2..6).cover?(Date.current.day) && !MonthlySyncProgress.current_cycle.completed?

    $stdout.sync = true
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    run_step("import_machines") { invoke_task("ptown:import_machines") }
    run_step("sync_shop_machines") { invoke_task("ptown:sync_shop_machines") }

    # lat/lng が NULL の店舗を GSI (primary) + Nominatim (fallback) でジオコード。
    # 「現在地から探す」検索ロジックは lat/lng NULL の店舗を完全除外するため、
    # 新規店舗が DMM ぱちタウンで追加された日のうちに必ず座標を埋める必要がある。
    run_step("geocode_shops") { invoke_task("geocode:shops") }

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
