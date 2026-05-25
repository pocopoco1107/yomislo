ActiveAdmin.register Vote do
  actions :index, :show, :destroy

  index do
    selectable_column
    id_column
    column :user
    column :shop
    column :machine_model
    column :voted_on
    column :reset_vote
    column :setting_vote
    actions
  end

  filter :voted_on
  filter :shop
  filter :machine_model

  controller do
    def scoped_collection
      super.includes(:user, :shop, :machine_model)
    end
  end
end
