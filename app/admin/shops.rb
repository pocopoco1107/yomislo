ActiveAdmin.register Shop do
  permit_params :prefecture_id, :name, :address, :lat, :lng, :slug,
                :exchange_rate, :total_machines, :slot_machines,
                :business_hours, :holidays, :opened_on, :former_event_days, :notes,
                slot_rates: []

  action_item :import_csv, only: :index do
    link_to "CSVインポート", action: :import_csv_form
  end

  collection_action :import_csv_form, method: :get do
    render "admin/csv_import_form", locals: { resource_name: "店舗", path: import_csv_admin_shops_path }
  end

  collection_action :import_csv, method: :post do
    file = params[:csv_file]
    if file.nil?
      redirect_to admin_shops_path, alert: "ファイルを選択してください"
      return
    end

    require "csv"
    imported = 0
    errors = []

    CSV.foreach(file.path, headers: true, encoding: "UTF-8") do |row|
      prefecture = Prefecture.find_by(slug: row["prefecture_slug"]) || Prefecture.find_by(name: row["prefecture_name"])
      unless prefecture
        errors << "行#{$.}: 都道府県 '#{row['prefecture_slug'] || row['prefecture_name']}' が見つかりません"
        next
      end

      slug = row["slug"] || row["name"].parameterize
      shop = Shop.find_or_initialize_by(slug: slug)
      shop.assign_attributes(
        prefecture: prefecture,
        name: row["name"],
        address: row["address"],
        slug: slug,
        slot_rates: row["slot_rates"]&.split("|") || [],
        exchange_rate: row["exchange_rate"] || "unknown_rate",
        total_machines: row["total_machines"],
        slot_machines: row["slot_machines"],
        business_hours: row["business_hours"],
        holidays: row["holidays"] || "年中無休",
        former_event_days: row["former_event_days"],
        notes: row["notes"]
      )

      if shop.save
        imported += 1
      else
        errors << "行#{$.}: #{shop.name} - #{shop.errors.full_messages.join(', ')}"
      end
    end

    message = "#{imported}件の店舗をインポートしました"
    message += " (#{errors.size}件のエラー: #{errors.first(3).join('; ')})" if errors.any?
    redirect_to admin_shops_path, notice: message
  end

  index do
    selectable_column
    id_column
    column :name
    column :prefecture
    column("レート") { |s| s.slot_rates_display }
    column("換金率") { |s| s.exchange_rate_display }
    column :slot_machines
    column :address
    actions
  end

  filter :name
  filter :prefecture
  filter :exchange_rate, as: :select, collection: Shop.exchange_rates
  filter :address

  show do
    attributes_table do
      row :name
      row :prefecture
      row :address
      row :slug
      row("レート") { |s| s.slot_rates_display }
      row("換金率") { |s| s.exchange_rate_display }
      row :total_machines
      row :slot_machines
      row :business_hours
      row :holidays
      row :opened_on
      row :former_event_days
      row :notes
      row :lat
      row :lng
    end
  end

  form do |f|
    f.inputs "基本情報" do
      f.input :prefecture
      f.input :name
      f.input :address
      f.input :slug
      f.input :lat
      f.input :lng
    end
    f.inputs "店舗詳細" do
      f.input :slot_rates, as: :check_boxes, collection: Shop::SLOT_RATES
      f.input :exchange_rate, as: :select, collection: [["未設定", "unknown_rate"], ["等価", "equal_rate"], ["5.6枚交換", "rate_56"], ["5.0枚交換", "rate_50"], ["非等価", "non_equal"]]
      f.input :total_machines
      f.input :slot_machines
      f.input :business_hours, placeholder: "10:00〜22:45"
      f.input :holidays, placeholder: "年中無休"
      f.input :opened_on, as: :datepicker
      f.input :former_event_days, placeholder: "毎月7日, 17日, 27日"
      f.input :notes, as: :text
    end
    f.actions
  end
end
