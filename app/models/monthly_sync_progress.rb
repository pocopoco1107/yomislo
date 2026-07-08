# frozen_string_literal: true

# Render cron `yomislo-monthly` の実行チェックポイントを月ごとに永続化する。
# sync_shop_machines フェーズが実行時間上限内に全都道府県を処理しきれない前提で、
# 直近まで処理した都道府県 (last_synced_prefecture_id) を記録し、翌日以降の
# cron 実行 (毎月1〜5日) で残りの都道府県から再開できるようにする。
class MonthlySyncProgress < ApplicationRecord
  # 今月分の進捗レコードを取得する。存在しなければ新規作成する。
  def self.current_cycle
    find_or_create_by!(cycle_month: Date.current.beginning_of_month)
  end

  def last_synced_prefecture
    return nil if last_synced_prefecture_id.nil?

    Prefecture.find_by(id: last_synced_prefecture_id)
  end

  def remaining_prefectures
    scope = Prefecture.order(:id)
    return scope if last_synced_prefecture_id.nil?

    scope.where("id > ?", last_synced_prefecture_id)
  end
end
