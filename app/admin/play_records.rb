ActiveAdmin.register PlayRecord do
  permit_params :voter_token, :shop_id, :machine_model_id, :played_on,
                :result_amount, :investment, :payout, :memo, :is_public, tags: []

  index do
    selectable_column
    id_column
    column :voter_token do |r|
      "ユーザー##{r.voter_token.last(4)}"
    end
    column :shop
    column :machine_model
    column :played_on
    column :result_amount do |r|
      color = r.result_amount >= 0 ? "green" : "red"
      span style: "color: #{color}; font-weight: bold;" do
        number_with_delimiter(r.result_amount)
      end
    end
    column :is_public
    column :created_at
    actions
  end

  filter :shop
  filter :machine_model
  filter :played_on
  filter :result_amount
  filter :is_public
  filter :voter_token

  controller do
    def scoped_collection
      super.includes(:shop, :machine_model)
    end
  end

  show do
    attributes_table do
      row :id
      row :voter_token do |r|
        "ユーザー##{r.voter_token.last(4)}"
      end
      row :shop
      row :machine_model
      row :played_on
      row :result_amount do |r|
        number_with_delimiter(r.result_amount)
      end
      row :investment do |r|
        r.investment ? number_with_delimiter(r.investment) : "-"
      end
      row :payout do |r|
        r.payout ? number_with_delimiter(r.payout) : "-"
      end
      row :memo
      row :tags do |r|
        r.tags.join(", ")
      end
      row :is_public
      row :created_at
      row :updated_at
    end
  end
end
