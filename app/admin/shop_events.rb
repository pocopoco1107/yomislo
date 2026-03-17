ActiveAdmin.register ShopEvent do
  actions :index, :show, :destroy

  scope :all, default: true
  scope(:pending) { |scope| scope.pending }
  scope(:approved) { |scope| scope.approved }
  scope(:rejected) { |scope| scope.rejected }

  index do
    selectable_column
    id_column
    column :shop
    column(:event_type) { |e| e.event_type_label }
    column :title
    column :event_date
    column(:status) { |e| status_tag e.status, class: e.approved? ? "ok" : (e.rejected? ? "error" : "warning") }
    column :created_at
    actions defaults: true do |event|
      unless event.approved?
        item "承認", approve_admin_shop_event_path(event), method: :put, class: "member_link"
      end
      unless event.rejected?
        item "却下", reject_admin_shop_event_path(event), method: :put, class: "member_link"
      end
    end
  end

  filter :shop
  filter :event_type, as: :select, collection: ShopEvent::EVENT_TYPE_LABELS.map { |k, v| [ v, k ] }
  filter :status, as: :select, collection: ShopEvent.statuses.keys
  filter :event_date
  filter :created_at

  show do
    attributes_table do
      row :id
      row :shop
      row(:event_type) { |e| e.event_type_label }
      row :title
      row :description
      row :event_date
      row(:source_url) { |e| e.source_url.present? ? link_to(e.source_url, e.source_url, target: "_blank", rel: "noopener") : nil }
      row(:status) { |e| status_tag e.status, class: e.approved? ? "ok" : (e.rejected? ? "error" : "warning") }
      row :voter_token
      row :created_at
      row :updated_at
    end
  end

  member_action :approve, method: :put do
    resource.update!(status: :approved)
    redirect_to admin_shop_events_path, notice: "イベントを承認しました"
  end

  member_action :reject, method: :put do
    resource.update!(status: :rejected)
    redirect_to admin_shop_events_path, notice: "イベントを却下しました"
  end

  batch_action :approve do |ids|
    batch_action_collection.find(ids).each { |e| e.update!(status: :approved) }
    redirect_to collection_path, notice: "#{ids.size}件のイベントを承認しました"
  end

  batch_action :reject do |ids|
    batch_action_collection.find(ids).each { |e| e.update!(status: :rejected) }
    redirect_to collection_path, notice: "#{ids.size}件のイベントを却下しました"
  end
end
