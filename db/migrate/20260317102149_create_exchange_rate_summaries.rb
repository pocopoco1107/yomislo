class CreateExchangeRateSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_rate_summaries do |t|
      t.references :shop,              null: false, foreign_key: true
      t.integer    :denomination,      null: false
      t.jsonb      :rate_distribution, default: {}
      t.integer    :total_reports,     default: 0
      t.string     :consensus_rate
      t.timestamps
    end

    add_index :exchange_rate_summaries, [ :shop_id, :denomination ],
              unique: true, name: "idx_exchange_rate_summaries_unique"
  end
end
