class RefreshPlayRecordSummaryJob < ApplicationJob
  queue_as :default

  # create/update は id 経由。destroy は行が消えるため属性(machine_model_id等)を直接渡す
  def perform(play_record_id, machine_model_id: nil, shop_id: nil, prefecture_id: nil, played_on: nil)
    if play_record_id
      record = PlayRecord.find_by(id: play_record_id)
      return unless record

      machine_model_id = record.machine_model_id
      shop_id = record.shop_id
      prefecture_id = record.shop&.prefecture_id
      played_on = record.played_on
    end

    return if played_on.blank?
    played_on = Date.parse(played_on) if played_on.is_a?(String)
    month_key = played_on.strftime("%Y-%m")

    if machine_model_id
      PlayRecordSummary.refresh_for_machine_model!(machine_model_id, period_key: month_key)
      PlayRecordSummary.refresh_for_machine_model!(machine_model_id, period_key: nil)
    end

    if shop_id
      PlayRecordSummary.refresh_for_shop!(shop_id, period_key: month_key)
      PlayRecordSummary.refresh_for_shop!(shop_id, period_key: nil)
    end

    if prefecture_id
      PlayRecordSummary.refresh_for_prefecture!(prefecture_id, period_key: month_key)
      PlayRecordSummary.refresh_for_prefecture!(prefecture_id, period_key: nil)
    end
  end
end
