ActiveAdmin.register Feedback do
  menu priority: 3, label: "要望・フィードバック"

  actions :index, :show, :destroy

  scope :all
  scope("未読", :unread, default: true) { |s| s.feedback_unread }
  scope("既読", :read) { |s| s.feedback_read }
  scope("解決済", :resolved) { |s| s.feedback_resolved }

  index do
    selectable_column
    id_column
    column("カテゴリ") { |f| f.category_label }
    column("内容") { |f| truncate(f.body, length: 80) }
    column :name
    column("状態") { |f| status_tag f.status }
    column :created_at
    actions
  end

  show do
    attributes_table do
      row("カテゴリ") { |f| f.category_label }
      row :name
      row :email
      row :body
      row("状態") { |f| status_tag f.status }
      row :voter_token
      row :created_at
    end
  end

  action_item :mark_read, only: :show do
    if resource.feedback_unread?
      link_to "既読にする", mark_read_admin_feedback_path(resource), method: :put
    end
  end

  action_item :mark_resolved, only: :show do
    unless resource.feedback_resolved?
      link_to "解決済みにする", mark_resolved_admin_feedback_path(resource), method: :put
    end
  end

  member_action :mark_read, method: :put do
    resource.update!(status: :read)
    redirect_to admin_feedback_path(resource), notice: "既読にしました"
  end

  member_action :mark_resolved, method: :put do
    resource.update!(status: :resolved)
    redirect_to admin_feedback_path(resource), notice: "解決済みにしました"
  end
end
