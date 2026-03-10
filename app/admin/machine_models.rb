ActiveAdmin.register MachineModel do
  permit_params :name, :maker, :machine_type, :spec_type, :slug, :released_on

  action_item :import_csv, only: :index do
    link_to "CSVインポート", action: :import_csv_form
  end

  collection_action :import_csv_form, method: :get do
    render "admin/csv_import_form", locals: { resource_name: "機種", path: import_csv_admin_machine_models_path }
  end

  collection_action :import_csv, method: :post do
    file = params[:csv_file]
    if file.nil?
      redirect_to admin_machine_models_path, alert: "ファイルを選択してください"
      return
    end

    require "csv"
    created = 0
    updated = 0
    errors = []
    line_num = 1

    CSV.foreach(file.path, headers: true, encoding: "UTF-8") do |row|
      line_num += 1

      unless row["name"].present?
        errors << "行#{line_num}: 機種名が空です"
        next
      end

      slug = row["slug"] || row["name"].parameterize
      machine = MachineModel.find_or_initialize_by(slug: slug)
      is_new = machine.new_record?

      attrs = {
        name: row["name"],
        slug: slug
      }
      attrs[:maker] = row["maker"] if row["maker"].present?
      attrs[:generation] = row["generation"] if row["generation"].present?
      attrs[:is_smart_slot] = row["is_smart_slot"]&.downcase == "true" if row["is_smart_slot"].present?
      attrs[:payout_rate_min] = row["payout_rate_min"].to_f if row["payout_rate_min"].present?
      attrs[:payout_rate_max] = row["payout_rate_max"].to_f if row["payout_rate_max"].present?
      attrs[:machine_type] = row["machine_type"] if row["machine_type"].present?
      attrs[:spec_type] = row["spec_type"] if row["spec_type"].present?
      attrs[:released_on] = row["released_on"] if row["released_on"].present?

      # Defaults for new records
      attrs[:machine_type] ||= "slot" if is_new
      attrs[:spec_type] ||= "type_at" if is_new

      machine.assign_attributes(attrs)

      if machine.save
        is_new ? created += 1 : updated += 1
      else
        errors << "行#{line_num}: #{row['name']} - #{machine.errors.full_messages.join(', ')}"
      end
    end

    message = "新規#{created}件 / 更新#{updated}件"
    message += " (#{errors.size}件のエラー: #{errors.first(3).join('; ')})" if errors.any?
    redirect_to admin_machine_models_path, notice: message
  end

  index do
    selectable_column
    id_column
    column :name
    column :maker
    column :machine_type
    column :spec_type
    column :slug
    actions
  end

  filter :name
  filter :maker
  filter :machine_type, as: :select, collection: MachineModel.machine_types
  filter :spec_type, as: :select, collection: MachineModel.spec_types

  form do |f|
    f.inputs do
      f.input :name
      f.input :maker
      f.input :machine_type, as: :select, collection: MachineModel.machine_types.keys
      f.input :spec_type, as: :select, collection: MachineModel.spec_types.keys
      f.input :slug
      f.input :released_on, as: :datepicker
    end
    f.actions
  end
end
