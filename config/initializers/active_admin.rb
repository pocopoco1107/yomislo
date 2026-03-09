ActiveAdmin.setup do |config|
  config.site_title = "スロリセnavi 管理画面"
  config.authentication_method = :authenticate_admin_user!
  config.current_user_method = :current_user
  config.logout_link_path = :destroy_user_session_path
  config.root_to = "dashboard#index"
  config.batch_actions = true
  config.filter_attributes = [:encrypted_password, :password, :password_confirmation]
  config.comments = false
end
