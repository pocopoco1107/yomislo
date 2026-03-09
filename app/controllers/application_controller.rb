class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  protected

  def current_date
    @current_date ||= Date.current
  end
  helper_method :current_date

  def voter_token
    cookies[:voter_token] ||= {
      value: SecureRandom.hex(16),
      expires: 1.year.from_now,
      httponly: true,
      same_site: :lax
    }
    cookies[:voter_token]
  end
  helper_method :voter_token
end
