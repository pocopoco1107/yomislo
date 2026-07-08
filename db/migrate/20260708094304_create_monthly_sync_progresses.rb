class CreateMonthlySyncProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :monthly_sync_progresses do |t|
      t.date :cycle_month, null: false
      t.boolean :shops_imported, null: false, default: false
      t.boolean :machines_imported, null: false, default: false
      t.boolean :details_imported, null: false, default: false
      t.bigint :last_synced_prefecture_id
      t.boolean :completed, null: false, default: false
      t.timestamps
    end
    add_index :monthly_sync_progresses, :cycle_month, unique: true
  end
end
