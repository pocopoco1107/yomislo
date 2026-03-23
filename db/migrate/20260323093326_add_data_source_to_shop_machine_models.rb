class AddDataSourceToShopMachineModels < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_machine_models, :data_source, :string, default: "ptown"
  end
end
