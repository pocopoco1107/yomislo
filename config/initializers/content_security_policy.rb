Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, "https://fonts.gstatic.com"
    policy.img_src     :self, :data, "https:"
    policy.object_src  :none
    policy.script_src  :self, "https://www.googletagmanager.com", "https://static.cloudflareinsights.com"
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.connect_src :self, "https://*.ingest.sentry.io",
                       "https://www.google-analytics.com", "https://*.analytics.google.com",
                       "https://cloudflareinsights.com"
    policy.frame_src   :none
    policy.base_uri    :self
    policy.form_action :self
  end

  # nonce は per-request でランダム生成 (以前は session.id ベースだったが、同一セッション内で
  # 同じ値を使い回すため CSP のリプレイ耐性が弱かった)。SecureRandom.base64(16) で毎回別値に。
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
