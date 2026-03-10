class PrefecturesController < ApplicationController
  def show
    @prefecture = Prefecture.find_by!(slug: params[:slug])

    # Single query: load all shops with columns needed for stats + display
    all_shops = @prefecture.shops
                  .includes(:shop_machine_models)
                  .select(:id, :name, :slug, :address, :exchange_rate, :slot_rates,
                          :notes, :business_hours, :parking_spaces, :morning_entry,
                          :prefecture_id, :slot_machines, :total_machines, :phone_number,
                          :pworld_url, :features, :holidays)
                  .order(:address, :name)
                  .to_a

    @total_shops_count = all_shops.size

    # 市区町村グループ化 (アコーディオン表示用)
    @grouped_shops = all_shops.group_by { |s| extract_city(s.address) || "その他" }
                              .sort_by { |city, shops| [-shops.size, city] }

    # Compute all stats in a single pass over the loaded shops array
    exchange_rate_counts = Hash.new(0)
    rate_counts = Hash.new(0)
    facility_counts = Hash.new(0)
    opening_counts = Hash.new(0)
    closing_counts = Hash.new(0)
    parking_total = 0
    parking_sum = 0
    parking_max = 0
    morning_entry_count = 0

    all_shops.each do |shop|
      # 換金率
      er = shop.exchange_rate
      exchange_rate_counts[er] += 1 unless er == "unknown_rate"

      # レート
      if shop.slot_rates.present?
        shop.slot_rates.each { |r| rate_counts[r] += 1 }
      end

      # 設備
      if shop.notes.present?
        shop.notes.split("、").each { |f| facility_counts[f.strip] += 1 }
      end

      # 営業時間
      if shop.business_hours.present?
        parts = shop.business_hours.split(/[〜～]/).map(&:strip)
        if (m = parts[0]&.match(/\A(\d{1,2}:\d{2})\z/))
          opening_counts[m[1]] += 1
        end
        if (m = parts[1]&.match(/\A(\d{1,2}:\d{2})\z/))
          closing_counts[m[1]] += 1
        end
      end

      # 駐車場
      if shop.parking_spaces
        parking_total += 1
        parking_sum += shop.parking_spaces
        parking_max = shop.parking_spaces if shop.parking_spaces > parking_max
      end

      # 朝入場
      morning_entry_count += 1 if shop.morning_entry.present?
    end

    @exchange_rate_stats = exchange_rate_counts
      .transform_keys { |k| Shop.new(exchange_rate: k).exchange_rate_display }
      .sort_by { |_, v| -v }

    @slot_rate_stats = rate_counts.sort_by { |k, _| Shop::SLOT_RATES.index(k) || 99 }

    @facility_stats = facility_counts.sort_by { |_, v| -v }

    @opening_hours_stats = opening_counts.sort_by { |k, _| k }
    @closing_hours_stats = closing_counts.sort_by { |k, _| k }

    @parking_stats = {
      total: parking_total,
      avg: parking_total > 0 ? (parking_sum.to_f / parking_total).round : nil,
      max: parking_total > 0 ? parking_max : nil
    }

    @morning_entry_count = morning_entry_count

    # レビュー平均評価マップ (shop_id => avg_rating)
    shop_ids = all_shops.map(&:id)
    @review_averages = ShopReview.where(shop_id: shop_ids)
                                  .group(:shop_id)
                                  .average(:rating)
                                  .transform_values { |v| v.round(1) }

    # おすすめ店舗 (県内TOP3)
    @recommendations = RecommendationService.top_for_prefecture(@prefecture, limit: 3)

    desc = "#{@prefecture.name}のパチスロ店舗#{@total_shops_count}件の設定・リセット投票情報一覧。"
    set_meta_tags title: "#{@prefecture.name}のパチスロ店舗一覧",
                  description: desc,
                  keywords: "#{@prefecture.name}, パチスロ, 設定, リセット, 店舗",
                  og: { title: "#{@prefecture.name}のパチスロ店舗一覧 | スロリセnavi",
                        description: desc,
                        type: "website",
                        url: request.original_url.split("?").first },
                  twitter: { card: "summary" }
  end

  private

  def extract_city(address)
    return nil if address.blank?
    addr = address.sub(/\A.{2,3}[都道府県]/, "")
    # 政令市の区 (横浜市中区等)
    m = addr.match(/\A(.+?市.+?区)/)
    return m[1] if m
    # 市
    m = addr.match(/\A(.+?市)/)
    return m[1] if m
    # 区 (東京23区)
    m = addr.match(/\A(.+?区)/)
    return m[1] if m
    # 郡+町村
    m = addr.match(/\A(.+?郡.+?[町村])/)
    return m[1] if m
    # 町村
    m = addr.match(/\A(.+?[町村])/)
    return m[1] if m
    nil
  end
end
