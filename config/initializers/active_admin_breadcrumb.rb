Rails.application.config.to_prepare do
  ActiveAdmin::BreadcrumbHelper.module_eval do
    def default_breadcrumb_links(path, html_options = {})
      parts = path.split("/").select(&:present?)[0..-2]

      parts.each_with_index.map do |part, index|
        decoded = CGI.unescape(part)
        name = nil
        config = nil

        if index > 0
          parent = active_admin_config.belongs_to_config.try(:target)
          config = parent && parent.resource_name.route_key == parts[index - 1] ? parent : active_admin_config

          if config&.respond_to?(:find_resource)
            resource = begin
              config.find_resource(decoded)
            rescue ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid
              nil
            end

            if resource.nil? && config.respond_to?(:resource_class)
              klass = config.resource_class
              if klass.respond_to?(:column_names) && klass.column_names.include?("slug")
                resource = klass.find_by(slug: decoded)
              end
            end

            name = display_name(resource) if resource
          end
        end

        name ||= I18n.t("activerecord.models.#{decoded.singularize}", count: 2.1, default: decoded.titlecase)

        if !config || config.defined_actions.include?(:show)
          link_to name, "/" + parts[0..index].join("/"), html_options
        else
          name
        end
      end
    end
  end
end
