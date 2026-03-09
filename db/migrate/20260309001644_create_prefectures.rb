class CreatePrefectures < ActiveRecord::Migration[8.0]
  def change
    create_table :prefectures do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :prefectures, :name, unique: true
    add_index :prefectures, :slug, unique: true
  end
end
