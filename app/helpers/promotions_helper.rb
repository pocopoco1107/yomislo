module PromotionsHelper
  # スロットに紐づくアクティブな Promotion を 1 件取得して描画する。
  # variant: :banner（横長） / :card（レクタングル）
  # ENV['PROMOTIONS_ENABLED'] が "true" でないか、該当 Promotion が無ければ何も返さない。
  def render_promotion(slot_key, variant: :card)
    return unless promotions_enabled?

    promo = pick_promotion(slot_key)
    return unless promo

    partial = case variant
              when :banner then "shared/promotion_banner"
              else "shared/promotion_card"
              end

    render partial: partial, locals: { promotion: promo, slot_key: slot_key.to_s }
  end

  def promotions_enabled?
    ENV["PROMOTIONS_ENABLED"].to_s == "true"
  end

  private

  def pick_promotion(slot_key)
    candidates = Promotion.active.for_slot(slot_key).prioritized.to_a
    return if candidates.empty?

    top_priority = candidates.first.priority
    top = candidates.select { |p| p.priority == top_priority }
    top.sample
  end
end
