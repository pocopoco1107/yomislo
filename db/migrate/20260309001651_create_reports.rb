class CreateReports < ActiveRecord::Migration[8.0]
  def change
    create_table :reports do |t|
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.references :reportable, polymorphic: true, null: false
      t.integer :reason, null: false, default: 0
      t.boolean :resolved, default: false

      t.timestamps
    end
  end
end
