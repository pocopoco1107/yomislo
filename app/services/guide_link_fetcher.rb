# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

# Google Custom Search API を使って機種攻略リンクを自動取得する。
#
# Usage:
#   fetcher = GuideLinkFetcher.new
#   fetcher.fetch_for(machine_model)          # 1機種
#   fetcher.fetch_all(limit: 50)              # 全アクティブ機種 (上限付き)
#   fetcher.fetch_by_slug("juggler-classic")  # slug指定
#
class GuideLinkFetcher
  # 信頼サイトのドメイン => 表示名
  TRUSTED_SITES = {
    "chonborista.com"      => "ちょんぼりすた",
    "slopachi-quest.com"   => "すろぱちくえすと",
    "nana-press.com"       => "なな徹",
    "slotjin.com"          => "スロットジン",
    "pachislot-navi.com"   => "パチスロナビ",
    "p-town.dmm.com"       => "DMMぱちタウン",
    "game8.jp"             => "Game8",
    "slot-expectation.com" => "スロット期待値見える化"
  }.freeze

  # ドメイン => link_type 自動判定マッピング
  DOMAIN_LINK_TYPE = {
    "slotjin.com"        => :analysis,
    "chonborista.com"    => :trophy,
    "nana-press.com"     => :analysis,
    "slopachi-quest.com" => :analysis,
    "game8.jp"           => :analysis
  }.freeze

  # 検索クエリテンプレート => デフォルト link_type (ドメイン判定が優先)
  SEARCH_QUERIES = {
    "{name} 天井 期待値"  => :ceiling,
    "{name} 設定判別"     => :trophy,
    "{name} 解析 まとめ"  => :analysis
  }.freeze

  # 無料枠の日次上限
  DAILY_QUOTA = 100

  attr_reader :api_key, :cse_id, :dry_run, :api_call_count

  def initialize(api_key: nil, cse_id: nil, dry_run: false)
    @api_key = api_key || ENV["GOOGLE_CSE_API_KEY"]
    @cse_id  = cse_id  || ENV["GOOGLE_CSE_ID"]
    @dry_run = dry_run
    @api_call_count = 0
    @total_created = 0
    @total_skipped = 0
  end

  # ENV未設定ならスキップ (true = スキップした)
  def skip?
    @api_key.blank? || @cse_id.blank?
  end

  # 全アクティブ機種を処理
  def fetch_all(limit: nil)
    return log_missing_env if skip?

    scope = MachineModel.active.order(:name)
    scope = scope.limit(limit) if limit
    machines = scope.to_a

    puts "対象機種: #{machines.count}件"
    puts "DRY RUN モード（保存しません）" if dry_run

    machines.each_with_index do |machine, idx|
      break if quota_exceeded?
      puts "#{idx + 1}/#{machines.count} #{machine.name}"
      fetch_for(machine)
    end

    print_summary
  end

  # slug指定で1機種を処理
  def fetch_by_slug(slug)
    return log_missing_env if skip?

    machine = MachineModel.find_by(slug: slug)
    unless machine
      puts "機種が見つかりません: #{slug}"
      return
    end

    puts "対象機種: #{machine.name}"
    puts "DRY RUN モード（保存しません）" if dry_run

    fetch_for(machine)
    print_summary
  end

  # 1機種の攻略リンクを取得
  def fetch_for(machine)
    SEARCH_QUERIES.each do |query_template, default_link_type|
      break if quota_exceeded?

      query = query_template.gsub("{name}", machine.name)
      results = google_search(query)

      results.each do |item|
        process_search_result(machine, item, default_link_type)
      end

      sleep 1 # API rate limit 対策
    end
  end

  private

  def google_search(query)
    @api_call_count += 1

    if quota_exceeded?
      puts "  日次API上限(#{DAILY_QUOTA}回)に達しました。中断します。"
      return []
    end

    uri = URI("https://www.googleapis.com/customsearch/v1")
    uri.query = URI.encode_www_form(
      key: api_key,
      cx: cse_id,
      q: query,
      num: 5,
      lr: "lang_ja"
    )

    response = Net::HTTP.get_response(uri)

    if response.code == "200"
      data = JSON.parse(response.body)
      data["items"] || []
    else
      puts "  API Error (#{response.code}): #{response.body.to_s.truncate(200)}"
      []
    end
  rescue StandardError => e
    puts "  リクエストエラー: #{e.message}"
    []
  end

  def process_search_result(machine, item, default_link_type)
    url    = item["link"]
    title  = item["title"]
    domain = URI.parse(url).host rescue nil
    return unless domain

    # 信頼サイトのみ取り込む
    site_key = TRUSTED_SITES.keys.find { |d| domain.include?(d) }
    return unless site_key

    source_name = TRUSTED_SITES[site_key]
    link_type   = detect_link_type(site_key, default_link_type)

    if dry_run
      puts "  [DRY] #{link_type}: #{source_name} - #{title}"
      puts "        #{url}"
      @total_created += 1
      return
    end

    link = MachineGuideLink.find_or_initialize_by(
      machine_model: machine,
      url: url
    )

    if link.new_record?
      link.assign_attributes(
        title: title&.truncate(255),
        source: source_name,
        link_type: link_type,
        status: :pending
      )
      if link.save
        @total_created += 1
        puts "  + #{link_type}: #{source_name} - #{title}"
      else
        puts "  ! 保存エラー: #{link.errors.full_messages.join(', ')}"
      end
    else
      @total_skipped += 1
    end
  end

  # ドメインから link_type を自動判定。マッチしなければクエリのデフォルトを使う
  def detect_link_type(domain_key, default_type)
    DOMAIN_LINK_TYPE.fetch(domain_key, default_type)
  end

  def quota_exceeded?
    api_call_count > DAILY_QUOTA
  end

  def log_missing_env
    puts "GOOGLE_CSE_API_KEY / GOOGLE_CSE_ID が未設定です。スキップします。"
    puts "  export GOOGLE_CSE_API_KEY=your_key"
    puts "  export GOOGLE_CSE_ID=your_cse_id"
  end

  def print_summary
    puts "\n完了: 新規#{@total_created}件, スキップ#{@total_skipped}件, API呼出#{api_call_count}回/#{DAILY_QUOTA}"
  end
end
