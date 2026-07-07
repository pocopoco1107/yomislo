class PromotionsController < ApplicationController
  # ASP ドメインのホワイトリスト。target_url の host がここに含まれるものだけリダイレクト許可。
  # 契約 ASP が増えたら追記する。サブドメインは末尾一致で通す (例: "px.a8.net" は "a8.net" にマッチ)。
  ALLOWED_HOSTS = %w[
    a8.net
    moshimo.com
    valuecommerce.ne.jp
    linksynergy.com
    afl.rakuten.co.jp
    accesstrade.net
  ].freeze

  # /p/:id → クリック数を加算し、Promotion.target_url へ 302 リダイレクト。
  # 外部 ASP への遷移を全て自社経由にして計測 + Open Redirect 防止 (target_url は管理者のみ編集可能)。
  def click
    promo = Promotion.active.find_by(id: params[:id])
    return redirect_to(root_path) unless promo

    target = promo.target_url
    return redirect_to(root_path) if target.blank? || target == "#"

    # target_url の host が無いものや http(s) 以外は弾く (Promotion バリデーションでも防御済みだが二重防御)
    begin
      uri = URI.parse(target)
    rescue URI::InvalidURIError
      return redirect_to(root_path)
    end
    return redirect_to(root_path) unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    return redirect_to(root_path) if uri.host.blank?
    return redirect_to(root_path) unless host_allowed?(uri.host)

    promo.increment_clicks!
    redirect_to target, allow_other_host: true, status: :found
  end

  private

  # ALLOWED_HOSTS に完全一致 or サブドメイン (末尾 ".<allowed>") で許可。
  def host_allowed?(host)
    host = host.downcase
    ALLOWED_HOSTS.any? { |allowed| host == allowed || host.end_with?(".#{allowed}") }
  end
end
