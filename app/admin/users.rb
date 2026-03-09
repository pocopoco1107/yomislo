ActiveAdmin.register User do
  permit_params :nickname, :role, :trust_score

  index do
    selectable_column
    id_column
    column :nickname
    column :email
    column :role
    column :trust_score
    column :created_at
    actions
  end

  filter :nickname
  filter :email
  filter :role, as: :select, collection: User.roles
  filter :trust_score

  form do |f|
    f.inputs do
      f.input :nickname
      f.input :role, as: :select, collection: User.roles.keys
      f.input :trust_score
    end
    f.actions
  end
end
