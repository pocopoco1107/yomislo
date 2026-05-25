ActiveAdmin.register SnsReport do
  menu priority: 4, label: "SNS情報"

  actions :index, :show, :destroy

  scope :all
  scope :pending, default: true
  scope :approved
  scope :rejected

  filter :machine_model
  filter :source, as: :select, collection: %w[rss google_cse manual]
  filter :trophy_type
  filter :suggested_setting
  filter :confidence, as: :select, collection: SnsReport.confidences
  filter :reported_on
  filter :created_at

  # Batch actions
  batch_action :approve, confirm: "選択したレポートを承認しますか？" do |ids|
    batch_action_collection.find(ids).each do |report|
      report.update!(status: :approved)
    end
    redirect_to collection_path, notice: "#{ids.size}件を承認しました"
  end

  batch_action :reject, confirm: "選択したレポートを却下しますか？" do |ids|
    batch_action_collection.find(ids).each do |report|
      report.update!(status: :rejected)
    end
    redirect_to collection_path, notice: "#{ids.size}件を却下しました"
  end

  batch_action :parse, confirm: "選択したレポートを再解析しますか？" do |ids|
    count = 0
    batch_action_collection.find(ids).each do |report|
      SnsParser.new(report).parse!
      count += 1
    end
    redirect_to collection_path, notice: "#{count}件を解析しました"
  end

  index do
    selectable_column
    id_column
    column("機種") { |r| r.machine_model.name }
    column("ソース") { |r| status_tag r.source, class: source_badge_class(r.source) }
    column :source_title
    column :trophy_type
    column :suggested_setting
    column("信頼度") { |r| status_tag r.confidence }
    column("状態") { |r| status_tag r.status }
    column :reported_on
    actions
  end

  show do
    attributes_table do
      row("機種") { |r| r.machine_model.name }
      row("店舗") { |r| r.shop&.name || "なし" }
      row :source
      row("URL") { |r| r.source_url.present? ? link_to(r.source_url.truncate(60), r.source_url, target: "_blank", rel: "noopener") : "なし" }
      row :source_title
      row :raw_text
      row :trophy_type
      row :suggested_setting
      row("信頼度") { |r| status_tag r.confidence }
      row("状態") { |r| status_tag r.status }
      row("構造化データ") { |r| pre JSON.pretty_generate(r.structured_data) if r.structured_data.present? }
      row :reported_on
      row :created_at
    end
  end

  sidebar "統計", only: :index do
    div do
      para "全件: #{SnsReport.count}"
      para "未処理: #{SnsReport.pending.count}"
      para "承認済: #{SnsReport.approved.count}"
      para "却下: #{SnsReport.rejected.count}"
      hr
      para "ソース別:"
      %w[rss google_cse manual].each do |src|
        para "  #{src}: #{SnsReport.where(source: src).count}"
      end
    end
  end

  action_item :approve, only: :show do
    if resource.pending?
      link_to "承認", approve_admin_sns_report_path(resource), method: :put
    end
  end

  action_item :reject, only: :show do
    if resource.pending?
      link_to "却下", reject_admin_sns_report_path(resource), method: :put
    end
  end

  action_item :reparse, only: :show do
    link_to "再解析", reparse_admin_sns_report_path(resource), method: :put
  end

  member_action :approve, method: :put do
    resource.update!(status: :approved)
    redirect_to admin_sns_report_path(resource), notice: "承認しました"
  end

  member_action :reject, method: :put do
    resource.update!(status: :rejected)
    redirect_to admin_sns_report_path(resource), notice: "却下しました"
  end

  member_action :reparse, method: :put do
    SnsParser.new(resource).parse!
    redirect_to admin_sns_report_path(resource), notice: "再解析しました"
  end

  controller do
    def scoped_collection
      super.includes(:machine_model)
    end

    private

    # Helper available in views
    helper_method :source_badge_class

    def source_badge_class(source)
      case source
      when "rss"         then "ok"
      when "google_cse"  then "warning"
      when "manual"      then "yes"
      else ""
      end
    end
  end
end
