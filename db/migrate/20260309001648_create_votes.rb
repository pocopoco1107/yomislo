class CreateVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :shop, null: false, foreign_key: true
      t.references :machine_model, null: false, foreign_key: true
      t.date :voted_on, null: false
      t.integer :reset_vote
      t.integer :setting_vote

      t.timestamps
    end

    add_index :votes, [:user_id, :shop_id, :machine_model_id, :voted_on], unique: true, name: "index_votes_unique_per_user_shop_machine_date"
    add_index :votes, [:shop_id, :machine_model_id, :voted_on], name: "index_votes_for_aggregation"
  end
end
