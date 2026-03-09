Rails.application.config.after_initialize do
  ApplicationController.include(AdminAuthentication)
end
