module AdminAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_admin_user if respond_to?(:helper_method)
  end

  def authenticate_admin_user!
    authenticate_user!
    unless current_user&.admin?
      flash[:alert] = "管理者権限が必要です"
      redirect_to root_path
    end
  end

  def current_admin_user
    current_user if current_user&.admin?
  end
end
