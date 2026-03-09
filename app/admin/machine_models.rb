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
    imported = 0
    errors = []

    CSV.foreach(file.path, headers: true, encoding: "UTF-8") do |row|
      slug = row["slug"] || row["name"].parameterize
      machine = MachineModel.find_or_initialize_by(slug: slug)
      machine.assign_attributes(
        name: row["name"],
        maker: row["maker"],
        machine_type: row["machine_type"] || "slot",
        spec_type: row["spec_type"] || "type_at",
        slug: slug,
        released_on: row["released_on"]
      )

      if machine.save
        imported += 1
      else
        errors << "行#{$.}: #{machine.name} - #{machine.errors.full_messages.join(', ')}"
      end
    end

    message = "#{imported}件の機種をインポートしました"
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
