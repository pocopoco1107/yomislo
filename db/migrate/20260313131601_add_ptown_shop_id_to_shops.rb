class AddPtownShopIdToShops < ActiveRecord::Migration[8.0]
  def change
    add_column :shops, :ptown_shop_id, :integer
    add_index :shops, :ptown_shop_id, unique: true
  end
end
