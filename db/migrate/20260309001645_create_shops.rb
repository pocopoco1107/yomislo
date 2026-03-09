class CreateShops < ActiveRecord::Migration[8.0]
  def change
    create_table :shops do |t|
      t.references :prefecture, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address
      t.decimal :lat, precision: 10, scale: 7
      t.decimal :lng, precision: 10, scale: 7
      t.string :slug, null: false

      t.timestamps
    end

    add_index :shops, :slug, unique: true
  end
end
