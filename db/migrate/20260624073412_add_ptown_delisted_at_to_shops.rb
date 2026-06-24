class AddPtownDelistedAtToShops < ActiveRecord::Migration[8.1]
  def change
    add_column :shops, :ptown_delisted_at, :datetime
  end
end
