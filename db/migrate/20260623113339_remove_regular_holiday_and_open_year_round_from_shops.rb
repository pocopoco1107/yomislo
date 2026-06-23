class RemoveRegularHolidayAndOpenYearRoundFromShops < ActiveRecord::Migration[8.1]
  def change
    # 全国ほぼ不定休で情報価値が薄いため、定休日(自由テキスト)と
    # 年中無休フラグ(検索フィルタ)を項目ごと削除する。
    remove_column :shops, :regular_holiday, :string
    remove_column :shops, :open_year_round, :boolean
  end
end
