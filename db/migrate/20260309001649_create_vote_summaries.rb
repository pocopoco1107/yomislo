class CreateVoteSummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :vote_summaries do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :machine_model, null: false, foreign_key: true
      t.date :target_date, null: false
      t.integer :total_votes, default: 0
      t.integer :reset_yes_count, default: 0
      t.integer :reset_no_count, default: 0
      t.decimal :setting_avg, precision: 3, scale: 1
      t.jsonb :setting_distribution, default: {}

      t.timestamps
    end

    add_index :vote_summaries, [:shop_id, :machine_model_id, :target_date], unique: true, name: "index_vote_summaries_unique_shop_machine_date"
  end
end
