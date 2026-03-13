ActiveAdmin.register MachineModel do
  permit_params :name, :maker, :slug, :introduced_on,
                :generation, :is_smart_slot, :payout_rate_min, :payout_rate_max,
                :ceiling_info_json, :reset_info_json

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
      attrs[:introduced_on] = row["introduced_on"] if row["introduced_on"].present?

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
    column :generation
    column(:ceiling_info) { |m| m.ceiling_info.present? && m.ceiling_info.any? ? "あり" : "-" }
    column(:reset_info) { |m| m.reset_info.present? && m.reset_info.any? ? "あり" : "-" }
    column :slug
    actions
  end

  filter :name
  filter :maker
  filter :generation

  show do
    attributes_table do
      row :name
      row :slug
      row :maker
      row :generation
      row :is_smart_slot
      row :payout_rate_min
      row :payout_rate_max
      row :introduced_on
      row(:ceiling_info) { |m| pre JSON.pretty_generate(m.ceiling_info) if m.ceiling_info.present? }
      row(:reset_info) { |m| pre JSON.pretty_generate(m.reset_info) if m.reset_info.present? }
    end
  end

  form do |f|
    f.inputs "基本情報" do
      f.input :name
      f.input :maker
      f.input :generation
      f.input :is_smart_slot
      f.input :payout_rate_min
      f.input :payout_rate_max
      f.input :slug
      f.input :introduced_on, as: :datepicker
    end
    f.inputs "天井・期待値情報 (JSON)" do
      f.input :ceiling_info_json, as: :text,
              label: "天井情報 (JSON)",
              hint: '例: {"天井ゲーム数": "800G+α", "恩恵": "AT確定", "期待値目安": "300Gから期待値プラス"}',
              input_html: { rows: 5, value: f.object.ceiling_info.present? ? JSON.pretty_generate(f.object.ceiling_info) : "{}" }
    end
    f.inputs "リセット・据え置き情報 (JSON)" do
      f.input :reset_info_json, as: :text,
              label: "リセット情報 (JSON)",
              hint: '例: {"リセット恩恵": "天井短縮(200G)", "据え置き挙動": "ステージで判別可"}',
              input_html: { rows: 5, value: f.object.reset_info.present? ? JSON.pretty_generate(f.object.reset_info) : "{}" }
    end
    f.actions
  end
end
