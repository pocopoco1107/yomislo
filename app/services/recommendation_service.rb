class RecommendationService
  # 直近何日間のデータを使うか
  LOOKBACK_DAYS = 7

  # スコア算出の重み
  WEIGHTS = {
    vote_volume: 0.3,     # 記録数の多さ
    high_setting: 0.3,    # 高設定割合
    reset_rate: 0.2,      # リセット率
    review_rating: 0.2    # レビュー平均評価
  }.freeze

  Result = Data.define(:shop, :score, :reasons)

  # 全国TOP N
  def self.top_nationwide(limit: 10)
    new.top_shops(scope: Shop.all, limit: limit)
  end

  # 都道府県別TOP N
  def self.top_for_prefecture(prefecture, limit: 5)
    new.top_shops(scope: prefecture.shops, limit: limit)
  end

  # 将来のAI連携用インターフェース
  # 現時点ではテンプレート文言を返す
  def self.generate_comment(shop, data)
    reasons = data[:reasons] || []
    return nil if reasons.empty?

    primary = reasons.first
    case primary[:type]
    when :vote_volume
      "#{shop.name}は直近で記録が集中しており注目度が高いです"
    when :high_setting
      "#{shop.name}は直近で高設定記録が多く期待度が高いです"
    when :reset_rate
      "#{shop.name}はリセット率が高く狙い目の可能性があります"
    when :review_rating
      "#{shop.name}はユーザー評価が高く人気の店舗です"
    else
      "#{shop.name}は直近の記録データから注目されています"
    end
  end

  def top_shops(scope:, limit:)
    shop_ids = scope.pluck(:id)
    return [] if shop_ids.empty?

    start_date = Date.current - LOOKBACK_DAYS
    end_date = Date.current

    # 1クエリで集計: 投票数・高設定割合・リセット率
    vote_stats = fetch_vote_stats(shop_ids, start_date, end_date)

    # レビュー平均 (shop_reviewsテーブルがある場合)
    review_stats = fetch_review_stats(shop_ids)

    # データがある店舗のみ対象
    candidate_shop_ids = vote_stats.keys
    return [] if candidate_shop_ids.empty?

    # 正規化用の最大値を計算
    max_votes = vote_stats.values.map { |s| s[:total_votes] }.max.to_f
    max_votes = 1.0 if max_votes.zero?

    # スコア算出
    scored = candidate_shop_ids.filter_map do |shop_id|
      vs = vote_stats[shop_id]
      next if vs[:total_votes].zero?

      score, reasons = calculate_score(vs, review_stats[shop_id], max_votes)
      next if score.zero?

      { shop_id: shop_id, score: score, reasons: reasons }
    end

    # スコア降順でTOP N
    top = scored.sort_by { |s| -s[:score] }.first(limit)
    return [] if top.empty?

    # 店舗オブジェクトを1クエリで取得
    shops_by_id = Shop.where(id: top.map { |s| s[:shop_id] })
                      .includes(:prefecture)
                      .index_by(&:id)

    top.filter_map do |entry|
      shop = shops_by_id[entry[:shop_id]]
      next unless shop

      Result.new(
        shop: shop,
        score: entry[:score].round(2),
        reasons: entry[:reasons]
      )
    end
  end

  private

  def fetch_vote_stats(shop_ids, start_date, end_date)
    high_setting_sql = "COALESCE(SUM(" \
      "(setting_distribution->>'4')::int + " \
      "(setting_distribution->>'5')::int + " \
      "(setting_distribution->>'6')::int" \
      "), 0)"

    total_setting_sql = "COALESCE(SUM(" \
      "(setting_distribution->>'1')::int + " \
      "(setting_distribution->>'2')::int + " \
      "(setting_distribution->>'3')::int + " \
      "(setting_distribution->>'4')::int + " \
      "(setting_distribution->>'5')::int + " \
      "(setting_distribution->>'6')::int" \
      "), 0)"

    rows = VoteSummary
      .where(shop_id: shop_ids, target_date: start_date..end_date)
      .group(:shop_id)
      .pluck(
        Arel.sql("shop_id"),
        Arel.sql("COALESCE(SUM(total_votes), 0)"),
        Arel.sql("COALESCE(SUM(reset_yes_count), 0)"),
        Arel.sql("COALESCE(SUM(reset_no_count), 0)"),
        Arel.sql(high_setting_sql),
        Arel.sql(total_setting_sql)
      )

    rows.each_with_object({}) do |row, hash|
      hash[row[0]] = {
        total_votes: row[1].to_i,
        reset_yes: row[2].to_i,
        reset_no: row[3].to_i,
        high_setting_votes: row[4].to_i,
        total_setting_votes: row[5].to_i
      }
    end
  end

  def fetch_review_stats(shop_ids)
    return {} unless defined?(ShopReview)

    ShopReview
      .where(shop_id: shop_ids)
      .group(:shop_id)
      .pluck(Arel.sql("shop_id"), Arel.sql("AVG(rating)"))
      .each_with_object({}) do |(shop_id, avg), hash|
        hash[shop_id] = avg&.to_f&.round(1)
      end
  rescue StandardError
    {}
  end

  def calculate_score(vote_stat, review_avg, max_votes)
    score = 0.0
    reasons = []

    # 記録量スコア (0〜1に正規化)
    vote_ratio = vote_stat[:total_votes] / max_votes
    vote_score = vote_ratio * WEIGHTS[:vote_volume]
    score += vote_score
    if vote_ratio >= 0.5
      reasons << { type: :vote_volume, label: "記録が多い", value: vote_stat[:total_votes] }
    end

    # 高設定割合スコア (設定4以上の割合)
    if vote_stat[:total_setting_votes] >= 3
      high_ratio = vote_stat[:high_setting_votes].to_f / vote_stat[:total_setting_votes]
      high_score = high_ratio * WEIGHTS[:high_setting]
      score += high_score
      if high_ratio >= 0.3
        pct = (high_ratio * 100).round
        reasons << { type: :high_setting, label: "高設定記録#{pct}%", value: pct }
      end
    end

    # リセット率スコア
    total_reset = vote_stat[:reset_yes] + vote_stat[:reset_no]
    if total_reset >= 3
      reset_ratio = vote_stat[:reset_yes].to_f / total_reset
      reset_score = reset_ratio * WEIGHTS[:reset_rate]
      score += reset_score
      if reset_ratio >= 0.5
        pct = (reset_ratio * 100).round
        reasons << { type: :reset_rate, label: "リセット率#{pct}%", value: pct }
      end
    end

    # レビュー評価スコア (1〜5を0〜1に正規化)
    if review_avg && review_avg > 0
      review_ratio = (review_avg - 1.0) / 4.0  # 1→0, 5→1
      review_score = review_ratio * WEIGHTS[:review_rating]
      score += review_score
      if review_avg >= 3.5
        reasons << { type: :review_rating, label: "評価#{review_avg}", value: review_avg }
      end
    end

    # 理由をスコア影響度順にソート
    reasons.sort_by! { |r| -score_for_type(r[:type]) }

    [ score, reasons ]
  end

  def score_for_type(type)
    WEIGHTS[type] || 0
  end
end
