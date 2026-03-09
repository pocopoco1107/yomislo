ActiveAdmin.register Comment, as: "UserComment" do
  actions :index, :show, :destroy

  index do
    selectable_column
    id_column
    column :user
    column(:body) { |c| truncate(c.body, length: 50) }
    column :commentable_type
    column :target_date
    column :created_at
    actions
  end

  filter :user
  filter :target_date
  filter :commentable_type
end
