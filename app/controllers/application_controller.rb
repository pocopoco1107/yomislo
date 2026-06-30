class ApplicationController < ActionController::Base
  include AdminAuthentication

  allow_browser versions: :modern

  before_action :redirect_to_canonical_host
  before_action :set_default_meta

  protected

  # CANONICAL_HOST が設定されている場合、それ以外のホスト経由でのアクセスを
  # 同じパス・クエリのまま 301 で新ドメインへリダイレクトする。
  # ENV 未設定なら何もしないので、デプロイしただけでは挙動が変わらない。
  def redirect_to_canonical_host
    canonical = ENV["CANONICAL_HOST"]
    return if canonical.blank?
    return if request.host == canonical
    return if request.path == "/up"

    redirect_to "https://#{canonical}#{request.fullpath}",
                status: :moved_permanently,
                allow_other_host: true
  end

  def set_default_meta
    og_image_url = helpers.image_url("logo.png")
    set_meta_tags og: { image: og_image_url },
                  twitter: { image: og_image_url }
  end

  def current_date
    @current_date ||= Date.current
  end
  helper_method :current_date

  # 既存トークンがあればそれを返し、無ければ新規発行して signed cookie に保存する。
  # 旧 plain cookie が残っている古い訪問者は、初回アクセス時に signed へ移行する。
  def voter_token
    existing_voter_token || begin
      new_token = SecureRandom.hex(16)
      cookies.signed[:voter_token] = voter_token_cookie_options(new_token)
      new_token
    end
  end
  helper_method :voter_token

  # 副作用なし版。cookie が無ければ nil を返す。
  # 新規訪問者にトークンを発行したくない箇所（ホームのペット読み込み等）で使う。
  def existing_voter_token
    signed = cookies.signed[:voter_token]
    return signed if signed.present?

    legacy = cookies[:voter_token]
    return nil if legacy.blank?

    # 旧 plain cookie → signed cookie へ無停止移行。
    # plain は意図的に残す: signed が常に優先されるため、改ざん耐性は維持される。
    cookies.signed[:voter_token] = voter_token_cookie_options(legacy)
    legacy
  end
  helper_method :existing_voter_token

  def voter_token_cookie_options(value)
    {
      value: value,
      expires: 1.year.from_now,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

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
