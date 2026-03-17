class CreatePlayRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :play_records do |t|
      t.string :voter_token, null: false
      t.references :shop, null: false, foreign_key: true
      t.references :machine_model, foreign_key: true
      t.date :played_on, null: false
      t.integer :result_amount, null: false
      t.integer :investment
      t.integer :payout
      t.text :memo
      t.string :tags, array: true, default: []
      t.boolean :is_public, default: true, null: false

      t.timestamps
    end

    add_index :play_records, [ :voter_token, :shop_id, :machine_model_id, :played_on ],
              unique: true, name: "idx_play_records_unique"
    add_index :play_records, :voter_token
    add_index :play_records, [ :played_on, :is_public ], name: "idx_play_records_public_date"
    add_index :play_records, :tags, using: :gin
  end
end
