ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: "ダッシュボード" do
    columns do
      column do
        panel "サイト統計" do
          ul do
            li "ユーザー数: #{User.count}"
            li "店舗数: #{Shop.count}"
            li "機種数: #{MachineModel.count}"
            li "総投票数: #{Vote.count}"
            li "今日の投票数: #{Vote.where(voted_on: Date.current).count}"
          end
        end
      end
      column do
        panel "未解決通報 (#{Report.unresolved.count}件)" do
          table_for Report.unresolved.order(created_at: :desc).limit(10) do
            column("通報者") { |r| r.reporter.nickname }
            column("対象") { |r| "#{r.reportable_type} ##{r.reportable_id}" }
            column("理由") { |r| r.reason }
            column("日時") { |r| r.created_at.strftime("%Y/%m/%d %H:%M") }
          end
        end
      end
    end
  end
end
