ActiveAdmin.register Promotion do
  menu priority: 4, label: "おすすめ案件"

  permit_params :title, :description, :image_url, :target_url, :category,
                :priority, :active, slot_keys: []

  index do
    selectable_column
    id_column
    column :title
    column("カテゴリ") { |p| p.category_label }
    column("スロット") { |p| p.slot_keys.join(", ") }
    column :priority
    column :active
    column :clicks_count
    column :updated_at
    actions
  end

  filter :title
  filter :category, as: :select, collection: Promotion::CATEGORY_LABELS.map { |k, v| [ v, k ] }
  filter :active
  filter :created_at

  show do
    attributes_table do
      row :id
      row :title
      row :description
      row :image_url do |p|
        if p.image_url.present?
          image_tag p.image_url, style: "max-width: 240px;"
        end
      end
      row :target_url do |p|
        link_to p.target_url, p.target_url, target: "_blank", rel: "noopener"
      end
      row("カテゴリ") { |p| p.category_label }
      row("スロット") { |p| p.slot_keys.join(", ") }
      row :priority
      row :active
      row :clicks_count
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "おすすめ案件" do
      f.input :title, hint: "例: 楽天カード"
      f.input :description, hint: "1〜2行の紹介文（最大120文字）"
      f.input :image_url, hint: "カード画像URL"
      f.input :target_url, hint: "アフィリエイトリンク（ASP契約後に差し替え）"
      f.input :category, as: :select,
                         collection: Promotion::CATEGORY_LABELS.map { |k, v| [ v, k ] },
                         include_blank: false
      f.input :slot_keys, as: :check_boxes, collection: Promotion::SLOT_KEYS
      f.input :priority, hint: "数字が大きいほど優先表示"
      f.input :active
    end
    f.actions
  end
end
