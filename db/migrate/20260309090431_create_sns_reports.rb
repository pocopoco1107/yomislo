class CreateSnsReports < ActiveRecord::Migration[8.0]
  def change
    create_table :sns_reports do |t|
      t.references :machine_model, foreign_key: true
      t.references :shop, foreign_key: true, null: true
      t.string :source, null: false          # "rss", "google_search", "manual"
      t.string :source_url
      t.string :source_title
      t.text :raw_text                       # 元テキスト（スニペット等）
      t.jsonb :structured_data, default: {}  # Claude Haikuで構造化した結果
      t.string :trophy_type                  # "金トロフィー", "虹トロフィー" etc
      t.string :suggested_setting            # "4以上", "6確" etc
      t.integer :confidence, default: 0      # 0=未判定, 1=低, 2=中, 3=高
      t.integer :status, default: 0          # 0=pending, 1=approved, 2=rejected
      t.date :reported_on                    # 情報の対象日
      t.timestamps
    end

    add_index :sns_reports, [ :machine_model_id, :reported_on ]
    add_index :sns_reports, :status
  end
end
