# frozen_string_literal: true

module StepRunner
  extend ActiveSupport::Concern

  private

  def run_step(name)
    Rails.logger.info("[#{log_prefix}] #{name} 開始")
    yield
    Rails.logger.info("[#{log_prefix}] #{name} 完了")
  rescue => e
    Rails.logger.error("[#{log_prefix}] #{name} 失敗: #{e.class} #{e.message}")
    Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
  end

  # rake タスクは1プロセス内で1度しか invoke できないため、同じタスクを都道府県ごとに
  # 繰り返し呼ぶジョブのために毎回 reenable する。
  def invoke_task(name, *args)
    Rake::Task[name].invoke(*args)
    Rake::Task[name].reenable
  end

  def deactivate_orphan_machines
    deactivated = MachineModel.active
      .left_joins(:shop_machine_models)
      .where(shop_machine_models: { id: nil })
      .update_all(active: false)
    Rails.logger.info("[#{log_prefix}] #{deactivated}件の孤立機種を非アクティブ化")
  end

  def log_prefix
    self.class.name.demodulize.underscore.humanize
  end
end
