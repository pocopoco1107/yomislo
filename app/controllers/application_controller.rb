class ApplicationController < ActionController::Base
  include AdminAuthentication

  allow_browser versions: :modern

  before_action :set_default_meta

  protected

  def set_default_meta
    og_image_url = helpers.image_url("logo.png")
    set_meta_tags og: { image: og_image_url },
                  twitter: { image: og_image_url }
  end

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

  # 記録成功後にペット(育成キャラ)を成長させる。
  # ペット側の失敗で本来の記録フローを壊さないよう、例外は握りつぶしてログのみ。
  # 戻り値: Pet::RegistrationResult もしくは nil
  def grow_companion(recorded_on:, count: 1)
    return nil if count.to_i < 1

    Pet.register!(voter_token: voter_token, recorded_on: recorded_on, count: count)
  rescue StandardError => e
    Rails.logger.warn("[Pet] grow_companion failed: #{e.class}: #{e.message}")
    nil
  end
end
