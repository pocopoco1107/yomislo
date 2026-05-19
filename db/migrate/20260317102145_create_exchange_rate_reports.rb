class CreateExchangeRateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_rate_reports do |t|
      t.string     :voter_token,    null: false
      t.references :shop,           null: false, foreign_key: true
      t.integer    :denomination,   null: false # enum: 0=twenty_yen, 1=five_yen
      t.string     :rate_key,       null: false # "touka", "5.6", "5.0", "other"
      t.timestamps
    end

    add_index :exchange_rate_reports, [ :voter_token, :shop_id, :denomination ],
              unique: true, name: "idx_exchange_rate_reports_unique"
    add_index :exchange_rate_reports, [ :shop_id, :denomination ],
              name: "idx_exchange_rate_reports_aggregation"
  end
end
