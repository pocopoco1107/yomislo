class PrefecturesController < ApplicationController
  def show
    @prefecture = Prefecture.find_by!(slug: params[:slug])

    # Single query: load all shops with columns needed for stats + display
    all_shops = @prefecture.shops
                  .select(:id, :name, :slug, :address,
                          :business_hours, :parking_spaces, :morning_entry,
                          :prefecture_id, :slot_machines, :total_machines, :phone_number,
                          :features)
                  .order(:address, :name)
                  .to_a

    @total_shops_count = all_shops.size

    # 市区町村グループ化 (アコーディオン表示用)
    @grouped_shops = all_shops.group_by { |s| extract_city(s.address) || "その他" }
                              .sort_by { |city, shops| [ -shops.size, city ] }

    # Compute all stats in a single pass over the loaded shops array
    opening_counts = Hash.new(0)
    closing_counts = Hash.new(0)
    parking_total = 0
    parking_sum = 0
    parking_max = 0
    morning_entry_count = 0

    all_shops.each do |shop|
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

    @opening_hours_stats = opening_counts.sort_by { |k, _| k }
    @closing_hours_stats = closing_counts.sort_by { |k, _| k }

    @parking_stats = {
      total: parking_total,
      avg: parking_total > 0 ? (parking_sum.to_f / parking_total).round : nil,
      max: parking_total > 0 ? parking_max : nil
    }

    @morning_entry_count = morning_entry_count

    # 関連集計を1クエリずつでまとめて取得 (shop_id => count / avg)
    shop_ids = all_shops.map(&:id)
    @machine_counts = ShopMachineModel.where(shop_id: shop_ids)
                                       .group(:shop_id)
                                       .count
    @review_averages = ShopReview.where(shop_id: shop_ids)
                                  .group(:shop_id)
                                  .average(:rating)
                                  .transform_values { |v| v.round(1) }

    # おすすめ店舗 (県内TOP3)
    @recommendations = RecommendationService.top_for_prefecture(@prefecture, limit: 3)

    desc = "#{@prefecture.name}のパチスロ店舗#{@total_shops_count}件の設定・リセット記録情報一覧。"
    set_meta_tags title: "#{@prefecture.name}のパチスロ店舗一覧",
                  description: desc,
                  keywords: "#{@prefecture.name}, パチスロ, 設定, リセット, 店舗",
                  og: { title: "#{@prefecture.name}のパチスロ店舗一覧 | ヨミスロ",
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
