ActiveAdmin.register Report do
  permit_params :resolved

  scope :all
  scope :unresolved, default: true

  index do
    selectable_column
    id_column
    column("通報者") { |r| r.reporter.nickname }
    column :reportable_type
    column :reportable_id
    column :reason
    column :resolved
    column :created_at
    actions
  end

  action_item :resolve, only: :show do
    link_to "解決済みにする", resolve_admin_report_path(resource), method: :put unless resource.resolved?
  end

  member_action :resolve, method: :put do
    resource.update!(resolved: true)
    redirect_to admin_report_path(resource), notice: "解決済みにしました"
  end

  filter :reason, as: :select, collection: Report.reasons
  filter :resolved
end
