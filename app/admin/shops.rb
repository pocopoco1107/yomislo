ActiveAdmin.register Shop do
  permit_params :prefecture_id, :name, :address, :lat, :lng, :slug,
                :exchange_rate, :total_machines, :slot_machines,
                :business_hours, :opened_on, :former_event_days, :notes,
                :parking_spaces, :phone_number, :morning_entry, :access_info, :features,
                :pworld_url,
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
    created = 0
    updated = 0
    errors = []
    line_num = 1

    CSV.foreach(file.path, headers: true, encoding: "UTF-8") do |row|
      line_num += 1
      prefecture = Prefecture.find_by(slug: row["prefecture_slug"]) || Prefecture.find_by(name: row["prefecture_name"])
      unless prefecture
        errors << "行#{line_num}: 都道府県 '#{row['prefecture_slug'] || row['prefecture_name']}' が見つかりません"
        next
      end

      unless row["name"].present?
        errors << "行#{line_num}: 店舗名が空です"
        next
      end

      slug = row["slug"] || row["name"].parameterize
      shop = Shop.find_or_initialize_by(slug: slug)
      is_new = shop.new_record?

      attrs = {
        prefecture: prefecture,
        name: row["name"],
        slug: slug
      }
      # Optional fields: only overwrite if CSV value is present
      attrs[:address] = row["address"] if row["address"].present?
      attrs[:slot_rates] = row["slot_rates"].split(/[|,]/).map(&:strip).reject(&:blank?) if row["slot_rates"].present?
      attrs[:exchange_rate] = row["exchange_rate"] if row["exchange_rate"].present?
      attrs[:total_machines] = row["total_machines"] if row["total_machines"].present?
      attrs[:slot_machines] = row["slot_machines"] if row["slot_machines"].present?
      attrs[:business_hours] = row["business_hours"] if row["business_hours"].present?
      attrs[:former_event_days] = row["former_event_days"] if row["former_event_days"].present?
      attrs[:notes] = row["notes"] if row["notes"].present?
      attrs[:parking_spaces] = row["parking_spaces"] if row["parking_spaces"].present?
      attrs[:phone_number] = row["phone_number"] if row["phone_number"].present?
      attrs[:morning_entry] = row["morning_entry"] if row["morning_entry"].present?
      attrs[:access_info] = row["access_info"] if row["access_info"].present?
      attrs[:features] = row["features"] if row["features"].present?
      attrs[:pworld_url] = row["pworld_url"] if row["pworld_url"].present?

      # Defaults for new records
      attrs[:exchange_rate] ||= "unknown_rate" if is_new


      shop.assign_attributes(attrs)

      if shop.save
        is_new ? created += 1 : updated += 1
      else
        errors << "行#{line_num}: #{row['name']} - #{shop.errors.full_messages.join(', ')}"
      end
    end

    message = "新規#{created}件 / 更新#{updated}件"
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
      row :opened_on
      row :former_event_days
      row :notes
      row :parking_spaces
      row :phone_number
      row :morning_entry
      row :access_info
      row :features
      row :pworld_url
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
      f.input :exchange_rate, as: :select, collection: [ [ "未設定", "unknown_rate" ], [ "等価", "equal_rate" ], [ "5.6枚交換", "rate_56" ], [ "5.0枚交換", "rate_50" ], [ "非等価", "non_equal" ] ]
      f.input :total_machines
      f.input :slot_machines
      f.input :business_hours, placeholder: "10:00〜22:45"
      f.input :opened_on, as: :datepicker
      f.input :former_event_days, placeholder: "毎月7日, 17日, 27日"
      f.input :parking_spaces
      f.input :phone_number
      f.input :morning_entry, placeholder: "09:40 抽選受付..."
      f.input :access_info, placeholder: "◯◯駅から徒歩5分"
      f.input :features, as: :text, input_html: { rows: 2 }
      f.input :notes, as: :text
      f.input :pworld_url
    end
    f.actions
  end
end
