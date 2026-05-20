module ShopsHelper
  # Shop の facility 系フラグを「表示すべきバッジ文字列」の配列に変換する。
  # true のもののみバッジ化し、false/nil は無視。
  FACILITY_BADGE_LABELS = {
    heated_tobacco_ok:   "加熱式OK",
    slot_smoking_ok:     "スロ喫煙可",
    wifi_available:      "Wi-Fi",
    charging_available:  "充電OK",
    low_rate_slot:       "低貸しあり",
    data_publishing:     "データ公開",
    okislot:             "沖スロ",
    ticket_distribution: "整理券あり",
    open_year_round:     "年中無休"
  }.freeze

  def shop_facility_badges(shop)
    FACILITY_BADGE_LABELS.filter_map do |attr, label|
      label if shop.public_send(attr) == true
    end
  end
end
