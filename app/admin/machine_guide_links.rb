ActiveAdmin.register MachineGuideLink do
  menu priority: 5, label: "攻略リンク"

  permit_params :machine_model_id, :url, :title, :source, :link_type, :status

  scope :all
  scope :pending, default: true
  scope :approved
  scope :rejected

  filter :machine_model
  filter :source
  filter :link_type, as: :select, collection: MachineGuideLink.link_types
  filter :status, as: :select, collection: MachineGuideLink.statuses
  filter :created_at

  index do
    selectable_column
    id_column
    column("機種") { |l| l.machine_model.name }
    column("タイプ") { |l| status_tag l.link_type_label }
    column :source
    column("タイトル") { |l| l.title&.truncate(50) }
    column("状態") { |l| status_tag l.status }
    column :created_at
    actions
  end

  show do
    attributes_table do
      row("機種") { |l| l.machine_model.name }
      row :url do |l|
        link_to l.url, l.url, target: "_blank", rel: "noopener noreferrer"
      end
      row :title
      row :source
      row("タイプ") { |l| status_tag l.link_type_label }
      row("状態") { |l| status_tag l.status }
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs do
      f.input :machine_model, as: :select, collection: MachineModel.active.order(:name).pluck(:name, :id)
      f.input :url
      f.input :title
      f.input :source
      f.input :link_type, as: :select, collection: MachineGuideLink::LINK_TYPE_LABELS.map { |k, v| [ v, k ] }
      f.input :status, as: :select, collection: MachineGuideLink.statuses.keys.map { |s| [ I18n.t("activerecord.attributes.machine_guide_link.statuses.#{s}", default: s), s ] }
    end
    f.actions
  end

  # 個別承認/却下
  action_item :approve, only: :show do
    if resource.pending?
      link_to "承認", approve_admin_machine_guide_link_path(resource), method: :put
    end
  end

  action_item :reject, only: :show do
    if resource.pending?
      link_to "却下", reject_admin_machine_guide_link_path(resource), method: :put
    end
  end

  member_action :approve, method: :put do
    resource.update!(status: :approved)
    redirect_to admin_machine_guide_link_path(resource), notice: "承認しました"
  end

  member_action :reject, method: :put do
    resource.update!(status: :rejected)
    redirect_to admin_machine_guide_link_path(resource), notice: "却下しました"
  end

  # 一括承認/却下
  batch_action :approve do |ids|
    batch_action_collection.find(ids).each { |link| link.update!(status: :approved) }
    redirect_to collection_path, notice: "#{ids.size}件を承認しました"
  end

  batch_action :reject do |ids|
    batch_action_collection.find(ids).each { |link| link.update!(status: :rejected) }
    redirect_to collection_path, notice: "#{ids.size}件を却下しました"
  end
end
