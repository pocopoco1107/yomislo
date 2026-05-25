ActiveAdmin.register Shop do
  FACILITY_BOOLEAN_FIELDS = %i[
    heated_tobacco_ok slot_smoking_ok low_rate_slot wifi_available
    charging_available data_publishing okislot open_year_round ticket_distribution
  ].freeze

  TRISTATE_COLLECTION = [
    [ "未確認", nil ], [ "あり", true ], [ "なし", false ]
  ].freeze

  permit_params :prefecture_id, :name, :address, :lat, :lng, :slug,
                :total_machines, :slot_machines,
                :business_hours, :opened_on,
                :parking_spaces, :phone_number, :morning_entry, :access_info, :features,
                :entry_method, :regular_holiday, :facility_parsed_at,
                *FACILITY_BOOLEAN_FIELDS

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
      attrs[:total_machines] = row["total_machines"] if row["total_machines"].present?
      attrs[:slot_machines] = row["slot_machines"] if row["slot_machines"].present?
      attrs[:business_hours] = row["business_hours"] if row["business_hours"].present?
      attrs[:parking_spaces] = row["parking_spaces"] if row["parking_spaces"].present?
      attrs[:phone_number] = row["phone_number"] if row["phone_number"].present?
      attrs[:morning_entry] = row["morning_entry"] if row["morning_entry"].present?
      attrs[:access_info] = row["access_info"] if row["access_info"].present?
      attrs[:features] = row["features"] if row["features"].present?

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
    column :slot_machines
    column :facility_parsed_at
    column :address
    actions
  end

  filter :name
  filter :prefecture
  filter :address
  filter :facility_parsed_at
  filter :entry_method, as: :select, collection: [ [ "抽選", "lottery" ], [ "並び順", "queue" ], [ "その他", "other" ] ]
  filter :wifi_available
  filter :slot_smoking_ok, label: "スロット喫煙可"
  filter :heated_tobacco_ok, label: "加熱式タバコエリアあり"

  show do
    attributes_table do
      row :name
      row :prefecture
      row :address
      row :slug
      row :total_machines
      row :slot_machines
      row :business_hours
      row :opened_on
      row :parking_spaces
      row :phone_number
      row :morning_entry
      row :access_info
      row :features
      row :lat
      row :lng
    end
    panel "設備・サービス (DMM取得)" do
      attributes_table_for shop do
        row :facility_parsed_at
        row :entry_method
        row :regular_holiday
        FACILITY_BOOLEAN_FIELDS.each { |attr| row attr }
      end
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
      f.input :total_machines
      f.input :slot_machines
      f.input :business_hours, placeholder: "10:00〜22:45"
      f.input :opened_on, as: :date_picker
      f.input :parking_spaces
      f.input :phone_number
      f.input :morning_entry, placeholder: "09:40 抽選受付..."
      f.input :access_info, placeholder: "◯◯駅から徒歩5分"
      f.input :features, as: :text, input_html: { rows: 2 }
    end
    f.inputs "設備・サービス (DMMから自動取得、手動編集も可)" do
      f.input :entry_method, as: :select,
              collection: [ [ "未確認", nil ], [ "抽選", "lottery" ], [ "並び順", "queue" ], [ "その他", "other" ] ],
              include_blank: false
      f.input :regular_holiday, placeholder: "年中無休 / 不定休 / 毎週月曜 等"
      FACILITY_BOOLEAN_FIELDS.each do |attr|
        f.input attr, as: :select, collection: TRISTATE_COLLECTION, include_blank: false
      end
    end
    f.actions
  end

  controller do
    def scoped_collection
      super.includes(:prefecture)
    end

    def find_resource
      scoped_collection.find_by(slug: params[:id]) || super
    end
  end
end
