class DropSnsReports < ActiveRecord::Migration[8.1]
  def up
    drop_table :sns_reports
  end

  def down
    create_table :sns_reports do |t|
      t.references :machine_model, null: false, foreign_key: true
      t.references :shop, foreign_key: true
      t.string :source, null: false
      t.text :raw_text, null: false
      t.string :source_url
      t.string :source_title
      t.date :reported_on
      t.integer :status, default: 0, null: false
      t.integer :confidence, default: 0, null: false
      t.jsonb :structured_data, default: {}
      t.string :trophy_type
      t.string :suggested_setting
      t.timestamps
    end

    add_index :sns_reports, [ :machine_model_id, :reported_on ]
    add_index :sns_reports, :status
    add_index :sns_reports, :source_url, unique: true, where: "source_url IS NOT NULL"
    add_index :sns_reports, :source
  end
end
