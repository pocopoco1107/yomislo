ActiveAdmin.register Shop do
  permit_params :prefecture_id, :name, :address, :lat, :lng, :slug

  index do
    selectable_column
    id_column
    column :name
    column :prefecture
    column :address
    column :slug
    actions
  end

  filter :name
  filter :prefecture
  filter :address

  form do |f|
    f.inputs do
      f.input :prefecture
      f.input :name
      f.input :address
      f.input :slug
      f.input :lat
      f.input :lng
    end
    f.actions
  end
end
