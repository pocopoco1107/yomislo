# frozen_string_literal: true

require "rake"

# Monthly job to fully sync shops, machines, and details from DMMぱちタウン.
# sync_shop_machines フェーズが47都道府県を1回のジョブ実行時間内に処理しきれないため、
# MonthlySyncProgress で都道府県単位の進捗を永続化し、cron の複数日実行
# (render.yaml: UTC 1〜5日 18:00 = JST 2〜6日 03:00) にまたがって再開できるようにしている。
# Each step runs independently — a failure in one step doesn't block the next.
class MonthlyShopDetailsJob < ApplicationJob
  include StepRunner

  queue_as :default

  # Render は cron の1回の実行を12時間で打ち切る (https://render.com/docs/cronjobs)。
  # 打ち切りは SIGTERM で、処理中の都道府県は中途半端なまま実行が failed 扱いになる。
  # 全フェーズの合計をジョブ開始からの経過時間で測り、12時間まで余裕を残して自力で終わる。
  # 余裕の1.5時間は最大の都道府県 (東京都 468店舗 ≒ 55分) の推定誤差と 429 リトライ待ちの分。
  JOB_TIME_BUDGET = 10.5.hours

  # 店舗1件あたりの所要 (詳細ページ取得 + sleep REQUEST_INTERVAL 5.0秒 + DB更新)。
  # 2026-08-04 の本番ログで熊本県 103店舗/610秒・大分県 81店舗/476秒 = 5.9秒/店舗。
  # 次の都道府県に進むかの判定に使うので切り上げた値を持つ。
  SECONDS_PER_SHOP = 7.0

  def perform
    $stdout.sync = true
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    @deadline = Time.current + JOB_TIME_BUDGET
    progress = MonthlySyncProgress.current_cycle

    if progress.completed?
      Rails.logger.info("[#{log_prefix}] #{progress.cycle_month} は既に同期完了済みのためスキップ")
      return
    end

    unless progress.shops_imported?
      return log_deferred(progress, "import_shops") unless within_budget?

      run_step("import_shops") { invoke_task("ptown:import_shops") }
      progress.update!(shops_imported: true)
    end

    unless progress.machines_imported?
      return log_deferred(progress, "import_machines") unless within_budget?

      run_step("import_machines") { invoke_task("ptown:import_machines") }
      progress.update!(machines_imported: true)
    end

    unless progress.details_imported?
      return log_deferred(progress, "import_details") unless within_budget?

      run_step("import_details") { invoke_task("ptown:import_details") }
      progress.update!(details_imported: true)
    end

    sync_shop_machines(progress)

    if progress.remaining_prefectures.empty?
      finalize(progress)
    else
      log_deferred(progress, "sync_shop_machines")
    end
  end

  private

  # 都道府県単位でチェックポイントを打ちながら設置機種を同期する。
  # 次の都道府県の推定所要時間が残り予算を超えた時点で打ち切り、Render の強制終了を待たずに
  # ジョブを正常終了させる。残りは翌日以降の cron 実行が last_synced_prefecture_id から再開する。
  def sync_shop_machines(progress)
    run_step("sync_shop_machines") do
      ENV["FORCE"] = "1"
      progress.remaining_prefectures.each do |pref|
        estimate = estimated_seconds_for(pref)
        if estimate > remaining_seconds
          Rails.logger.info(
            "[#{log_prefix}] #{pref.name} の推定所要#{(estimate / 60).round}分が残り予算#{(remaining_seconds / 60).round}分を超えるため中断"
          )
          break
        end

        invoke_task("ptown:sync_shop_machines", pref.slug)
        progress.update!(last_synced_prefecture_id: pref.id)
      end
    ensure
      ENV.delete("FORCE")
    end
  end

  def finalize(progress)
    run_step("geocode_shops") { invoke_task("geocode:shops") }
    run_step("merge_duplicates") { invoke_task("ptown:merge_duplicates") }
    run_step("cleanup") { deactivate_orphan_machines }

    progress.update!(completed: true)
    log_summary
  end

  def estimated_seconds_for(prefecture)
    prefecture.shops.where.not(ptown_shop_id: nil).count * SECONDS_PER_SHOP
  end

  def remaining_seconds
    @deadline - Time.current
  end

  def within_budget?
    remaining_seconds.positive?
  end

  def log_deferred(progress, next_phase)
    Rails.logger.info(
      "[#{log_prefix}] 残り予算#{[ remaining_seconds / 60, 0 ].max.round}分。" \
      "未処理: #{next_phase} / #{progress.remaining_prefectures.count}都道府県。次回cron実行で継続"
    )
  end

  def log_summary
    shops = Shop.count
    active = MachineModel.where(active: true).count
    synced = Shop.where.not(last_synced_at: nil).count
    smm = ShopMachineModel.count
    Rails.logger.info("[#{log_prefix}] サマリー: 店舗=#{shops}, アクティブ機種=#{active}, 同期済み=#{synced}/#{shops}, SMM=#{smm}")
  end
end
