ActiveAdmin.register ShopReview do
  actions :index, :show, :destroy

  index do
    selectable_column
    id_column
    column :shop
    column(:rating) { |r| "★" * r.rating }
    column(:category) { |r| r.category_label }
    column(:title) { |r| truncate(r.title.to_s, length: 30) }
    column(:body) { |r| truncate(r.body, length: 50) }
    column :reviewer_name
    column :created_at
    actions
  end

  filter :shop
  filter :rating
  filter :category, as: :select, collection: ShopReview::CATEGORY_LABELS.map { |k, v| [ v, k ] }
  filter :created_at

  show do
    attributes_table do
      row :id
      row :shop
      row(:rating) { |r| "★" * r.rating }
      row(:category) { |r| r.category_label }
      row :title
      row :body
      row :reviewer_name
      row :voter_token
      row :created_at
      row :updated_at
    end
  end
end
