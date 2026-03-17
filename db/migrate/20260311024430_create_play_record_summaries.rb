class CreatePlayRecordSummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :play_record_summaries do |t|
      t.string :scope_type, null: false
      t.bigint :scope_id, null: false
      t.integer :period_type, default: 0, null: false
      t.string :period_key, null: false
      t.integer :total_records, default: 0, null: false
      t.integer :total_result, default: 0, null: false
      t.integer :avg_result, default: 0, null: false
      t.integer :win_count, default: 0, null: false
      t.integer :lose_count, default: 0, null: false
      t.decimal :win_rate, precision: 5, scale: 1, default: 0.0
      t.jsonb :weekday_stats, default: {}

      t.timestamps
    end

    add_index :play_record_summaries, [ :scope_type, :scope_id, :period_type, :period_key ],
              unique: true, name: "idx_play_record_summaries_unique"
    add_index :play_record_summaries, [ :scope_type, :period_type, :period_key ],
              name: "idx_play_record_summaries_lookup"
  end
end
