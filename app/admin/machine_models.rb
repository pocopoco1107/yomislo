ActiveAdmin.register MachineModel do
  permit_params :name, :maker, :machine_type, :spec_type, :slug, :released_on

  index do
    selectable_column
    id_column
    column :name
    column :maker
    column :machine_type
    column :spec_type
    column :slug
    actions
  end

  filter :name
  filter :maker
  filter :machine_type, as: :select, collection: MachineModel.machine_types
  filter :spec_type, as: :select, collection: MachineModel.spec_types

  form do |f|
    f.inputs do
      f.input :name
      f.input :maker
      f.input :machine_type, as: :select, collection: MachineModel.machine_types.keys
      f.input :spec_type, as: :select, collection: MachineModel.spec_types.keys
      f.input :slug
      f.input :released_on, as: :datepicker
    end
    f.actions
  end
end
