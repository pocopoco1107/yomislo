class CreateVoterRankings < ActiveRecord::Migration[8.0]
  def change
    create_table :voter_rankings do |t|
      t.string :voter_token, null: false
      t.integer :period_type, default: 0, null: false
      t.string :period_key, null: false
      t.string :scope_type, default: "national", null: false
      t.bigint :scope_id
      t.integer :vote_count, default: 0, null: false
      t.integer :rank_position, null: false

      t.timestamps
    end

    add_index :voter_rankings, [ :period_type, :period_key, :scope_type, :scope_id, :voter_token ],
              unique: true, name: "idx_voter_rankings_unique"
    add_index :voter_rankings, [ :period_type, :period_key, :scope_type, :scope_id, :rank_position ],
              name: "idx_voter_rankings_lookup"
    add_index :voter_rankings, :voter_token
  end
end
