class AddFacilityColumnsToShops < ActiveRecord::Migration[8.0]
  def change
    change_table :shops do |t|
      t.string :entry_method     # "lottery" | "queue" | "other" | nil
      t.string :regular_holiday  # "年中無休" | "不定休" | フリーテキスト | nil

      t.boolean :heated_tobacco_ok     # 加熱式たばこ喫煙遊技エリアあり
      t.boolean :slot_smoking_ok       # 20円/5円スロット喫煙可
      t.boolean :low_rate_slot         # パチスロ低貸あり
      t.boolean :wifi_available        # Wi-Fi利用可
      t.boolean :charging_available    # 携帯電話充電可能
      t.boolean :data_publishing       # データ公開中
      t.boolean :ticket_distribution   # 整理券あり
      t.boolean :open_year_round       # 年中無休
      t.boolean :okislot               # 沖スロ（30Φ）

      t.datetime :facility_parsed_at
    end
  end
end
