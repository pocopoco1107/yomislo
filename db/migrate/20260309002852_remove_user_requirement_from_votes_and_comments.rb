class RemoveUserRequirementFromVotesAndComments < ActiveRecord::Migration[8.0]
  def change
    # Make user_id nullable on votes
    change_column_null :votes, :user_id, true

    # Remove foreign key constraint on votes.user_id
    remove_foreign_key :votes, :users

    # Add voter_token for anonymous identification
    add_column :votes, :voter_token, :string
    add_index :votes, :voter_token

    # Replace the unique index to use voter_token instead of user_id
    remove_index :votes, name: :index_votes_unique_per_user_shop_machine_date
    add_index :votes, [:voter_token, :shop_id, :machine_model_id, :voted_on], unique: true, name: 'idx_votes_unique_per_voter'

    # Make user_id nullable on comments
    change_column_null :comments, :user_id, true

    # Remove foreign key constraint on comments.user_id
    remove_foreign_key :comments, :users

    # Add commenter fields for anonymous comments
    add_column :comments, :commenter_name, :string, default: "名無し"
    add_column :comments, :voter_token, :string

    # Make reporter_id nullable on reports
    change_column_null :reports, :reporter_id, true

    # Remove foreign key constraint on reports.reporter_id
    remove_foreign_key :reports, :users, column: :reporter_id

    add_column :reports, :voter_token, :string
  end
end
