# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "uri"

# DMMぱちタウン scraping tasks for importing slot machine data.
# Source: https://p-town.dmm.com/machines/slot
#
# List page structure (li.unit > a.link):
#   - href: /machines/{id}
#   - p.title: 機種名
#   - p.lead: メーカー名
#   - p.text: 機械割
#   - span.lead: 導入開始日
#   - img.data-src: 筐体画像URL
#
# Detail page structure:
#   - h1.title: 機種名
#   - table th/td: 型式名, メーカー名, 機械割, 導入開始日, 機種概要
#   - #anc-title-ceiling-天井突入条件 + .wysiwyg-box: 天井情報
#   - #anc-title-ceiling-天井恩恵 + .wysiwyg-box: 天井恩恵
#   - #anc-title-ceiling-リセット仕様 + .wysiwyg-box: リセット情報

module PtownScraper
  BASE_URL = "https://p-town.dmm.com"
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  REQUEST_INTERVAL = 3.0
  MAX_RETRIES = 3

  class << self
    def fetch_page(url)
      uri = URI.parse(url)
      retries = 0

      loop do
        begin
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == "https")
          http.open_timeout = 15
          http.read_timeout = 30

          request = Net::HTTP::Get.new(uri.request_uri)
          request["User-Agent"] = USER_AGENT
          request["Accept"] = "text/html,application/xhtml+xml"
          request["Accept-Language"] = "ja"

          response = http.request(request)

          case response
          when Net::HTTPRedirection
            uri = URI.parse(response["location"])
            next
          when Net::HTTPSuccess
            return Nokogiri::HTML(response.body, nil, "UTF-8")
          when Net::HTTPTooManyRequests
            retries += 1
            if retries <= MAX_RETRIES
              wait = 10 * retries
              puts "  429 Too Many Requests, waiting #{wait}s..."
              sleep wait
              next
            end
            puts "  ERROR: 429 after #{MAX_RETRIES} retries for #{url}"
            return nil
          else
            puts "  ERROR: HTTP #{response.code} for #{url}"
            return nil
          end
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET => e
          retries += 1
          if retries <= MAX_RETRIES
            puts "  #{e.class}, retry #{retries}/#{MAX_RETRIES}..."
            sleep 5
            next
          end
          puts "  ERROR: #{e.class} after #{MAX_RETRIES} retries for #{url}"
          return nil
        end
      end
    end

    def normalize_slug(name)
      name
        .unicode_normalize(:nfkc)
        .gsub(/\s+/, "-")
        .gsub(/[^\p{L}\p{N}\-]/, "")
        .downcase
        .truncate(100, omission: "")
    end

    # Parse list page: extract machine entries with basic info
    def parse_list_page(doc)
      machines = []
      doc.css("li.unit > a[href]").each do |link|
        href = link["href"]
        next unless href&.match?(%r{/machines/\d+})

        ptown_id = href.split("/").last.to_i
        name = link.at_css("p.title")&.text&.strip
        next if name.blank?

        maker = link.at_css("p.lead")&.text&.strip
        payout_text = link.at_css("p.text")&.text&.strip
        intro_text = link.at_css("span.lead")&.text&.strip
        image_tag = link.at_css("img.lazyload")
        image_url = image_tag&.[]("data-src")

        # Parse payout rate: "機械割: 97.5% 〜 112.4%"
        payout_min = nil
        payout_max = nil
        if payout_text&.match(/(\d+\.?\d*)%\s*[〜~]\s*(\d+\.?\d*)%/)
          payout_min = $1.to_f
          payout_max = $2.to_f
        elsif payout_text&.match(/(\d+\.?\d*)%/)
          payout_min = payout_max = $1.to_f
        end

        # Parse intro date: "導入開始日:2025年12月22日(月)" or "導入開始日:2026年06月予定"
        introduced_on = nil
        if intro_text&.match(/(\d{4})年(\d{1,2})月(\d{1,2})日/)
          introduced_on = Date.new($1.to_i, $2.to_i, $3.to_i) rescue nil
        elsif intro_text&.match(/(\d{4})年(\d{1,2})月/)
          introduced_on = Date.new($1.to_i, $2.to_i, 1) rescue nil
        end

        machines << {
          ptown_id: ptown_id,
          name: name.unicode_normalize(:nfkc),
          maker: maker,
          payout_rate_min: payout_min,
          payout_rate_max: payout_max,
          introduced_on: introduced_on,
          image_url: image_url
        }
      end
      machines
    end

    # Parse detail page: extract ceiling, reset, spec info
    def parse_detail_page(doc)
      info = {}

      # 型式名
      doc.css("table .tr").each do |tr|
        th = tr.at_css(".th")&.text&.strip
        td = tr.at_css(".td")
        next unless th && td

        case th
        when "メーカー名"
          # Extract maker name without "(メーカー公式サイト)" suffix
          maker_text = td.at_css("a.textlink")&.text&.strip || td.text.strip
          info[:maker] = maker_text.sub(/（.*）/, "").strip
        when "機械割"
          text = td.text.strip
          if text.match(/(\d+\.?\d*)%\s*[〜~]\s*(\d+\.?\d*)%/)
            info[:payout_rate_min] = $1.to_f
            info[:payout_rate_max] = $2.to_f
          end
        when "導入開始日"
          if td.text.match(/(\d{4})年(\d{1,2})月(\d{1,2})日/)
            info[:introduced_on] = Date.new($1.to_i, $2.to_i, $3.to_i) rescue nil
          end
        when "機種概要"
          info[:description] = td.text.strip.truncate(1000)
        end
      end

      # 天井情報 (ceiling_info)
      ceiling_info = {}

      ceiling_condition = extract_wysiwyg_text(doc, "anc-title-ceiling-天井突入条件")
      ceiling_info["condition"] = ceiling_condition if ceiling_condition.present?

      ceiling_benefit = extract_wysiwyg_text(doc, "anc-title-ceiling-天井恩恵")
      ceiling_info["benefit"] = ceiling_benefit if ceiling_benefit.present?

      info[:ceiling_info] = ceiling_info if ceiling_info.present?

      # リセット情報 (reset_info)
      reset_text = extract_wysiwyg_text(doc, "anc-title-ceiling-リセット仕様")
      info[:reset_info] = { "description" => reset_text } if reset_text.present?

      # 狙い目
      zone_text = extract_wysiwyg_text(doc, "anc-title-ceiling-狙い目・ゾーン狙い")
      info[:zone_info] = zone_text if zone_text.present?

      # タイプ情報 (span.text-icon: "スマスロ", "AT機", "Aタイプ" 等)
      type_tags = doc.css("span.text-icon").map { |t| t.text.strip }.reject(&:blank?)
      info[:type_detail] = type_tags.join("、") if type_tags.any?

      info
    end

    private

    def extract_wysiwyg_text(doc, anchor_id)
      heading = doc.at_xpath("//*[@id='#{anchor_id}']")
      return nil unless heading

      # The wysiwyg-box is a sibling after the h5 in the same .spacebody div
      spacebody = heading.ancestors(".spacebody").first || heading.parent
      wysiwyg = spacebody&.at_css(".wysiwyg-box")
      return nil unless wysiwyg

      # Convert <br> to newlines, strip HTML, clean up
      wysiwyg.inner_html
             .gsub(/<br\s*\/?>/, "\n")
             .gsub(/<[^>]+>/, "")
             .gsub(/&[a-z]+;/) { |m| CGI.unescapeHTML(m) }
             .strip
             .truncate(2000)
    end
  end
end

namespace :ptown do
  desc "DMMぱちタウンからパチスロ機種一覧を取得・更新"
  task import_machines: :environment do
    $stdout.sync = true
    puts "=== DMMぱちタウン 機種インポート開始 ==="

    all_machines = []
    page = 1
    total_pages = nil

    loop do
      url = "#{PtownScraper::BASE_URL}/machines/slot?page=#{page}"
      puts "#{page}/#{total_pages || '?'} ページ取得中..."

      doc = PtownScraper.fetch_page(url)
      break unless doc

      # Detect total pages from pagination on first page
      if total_pages.nil?
        last_page_link = doc.css("a").select { |a| a["href"]&.include?("page=") }.last
        if last_page_link && last_page_link["href"].match(/page=(\d+)/)
          total_pages = $1.to_i
        else
          total_pages = page
        end
        puts "  全#{total_pages}ページ検出"
      end

      machines = PtownScraper.parse_list_page(doc)
      break if machines.empty?

      all_machines.concat(machines)
      puts "  #{machines.size}件取得 (累計: #{all_machines.size})"

      break if page >= total_pages
      page += 1
      sleep PtownScraper::REQUEST_INTERVAL
    end

    puts "\n--- 一覧取得完了: #{all_machines.size}件 ---"

    # Upsert machines
    created = 0
    updated = 0
    skipped = 0

    all_machines.each_with_index do |data, i|
      slug = PtownScraper.normalize_slug(data[:name])
      machine = MachineModel.find_by(slug: slug)

      if machine
        attrs = {}
        attrs[:maker] = data[:maker] if data[:maker].present? && machine.maker.blank?
        attrs[:payout_rate_min] = data[:payout_rate_min] if data[:payout_rate_min] && machine.payout_rate_min.blank?
        attrs[:payout_rate_max] = data[:payout_rate_max] if data[:payout_rate_max] && machine.payout_rate_max.blank?
        attrs[:introduced_on] = data[:introduced_on] if data[:introduced_on] && machine.introduced_on.blank?
        attrs[:image_url] = data[:image_url] if data[:image_url].present? && machine.image_url.blank?
        attrs[:ptown_id] = data[:ptown_id] if data[:ptown_id] && machine.ptown_id.blank?

        if attrs.any?
          machine.update!(attrs)
          updated += 1
        else
          skipped += 1
        end
      else
        MachineModel.create!(
          name: data[:name],
          slug: slug,
          maker: data[:maker],
          payout_rate_min: data[:payout_rate_min],
          payout_rate_max: data[:payout_rate_max],
          introduced_on: data[:introduced_on],
          image_url: data[:image_url],
          ptown_id: data[:ptown_id],
          active: true
        )
        created += 1
      end

      print "\r  処理中: #{i + 1}/#{all_machines.size}" if (i + 1) % 50 == 0
    end

    puts "\n\n=== 結果 ==="
    puts "新規作成: #{created}"
    puts "更新: #{updated}"
    puts "スキップ: #{skipped}"
    puts "合計: #{MachineModel.active.count} 件 (アクティブ)"
  end

  desc "DMMぱちタウンから機種詳細（天井・リセット・スペック）を取得"
  task import_details: :environment do
    $stdout.sync = true
    puts "=== DMMぱちタウン 機種詳細インポート開始 ==="

    # Only fetch details for active machines that have a ptown_id or we can match
    # First pass: build ptown_id mapping from list pages if not yet stored
    machines_with_id = fetch_ptown_id_mapping

    total = machines_with_id.size
    puts "対象機種: #{total}件"

    updated = 0
    skipped = 0
    errors = 0

    machines_with_id.each_with_index do |(machine, ptown_id), i|
      puts "#{i + 1}/#{total} #{machine.name} (ID: #{ptown_id})"

      url = "#{PtownScraper::BASE_URL}/machines/#{ptown_id}"
      doc = PtownScraper.fetch_page(url)

      if doc.nil?
        errors += 1
        next
      end

      begin
        info = PtownScraper.parse_detail_page(doc)

        attrs = {}
        attrs[:maker] = info[:maker] if info[:maker].present? && machine.maker.blank?
        attrs[:payout_rate_min] = info[:payout_rate_min] if info[:payout_rate_min] && machine.payout_rate_min.blank?
        attrs[:payout_rate_max] = info[:payout_rate_max] if info[:payout_rate_max] && machine.payout_rate_max.blank?
        attrs[:introduced_on] = info[:introduced_on] if info[:introduced_on] && machine.introduced_on.blank?

        # 天井・リセット情報は上書き（DMMぱちタウンの方が正確な場合が多い）
        attrs[:ceiling_info] = info[:ceiling_info] if info[:ceiling_info].present?
        attrs[:reset_info] = info[:reset_info] if info[:reset_info].present?
        attrs[:type_detail] = info[:type_detail] if info[:type_detail].present? && machine.type_detail.blank?

        if attrs.any?
          machine.update!(attrs)
          updated += 1
          puts "  → 更新 (#{attrs.keys.join(', ')})"
        else
          skipped += 1
          puts "  → スキップ（更新項目なし）"
        end
      rescue => e
        errors += 1
        puts "  → ERROR: #{e.message}"
      end

      sleep PtownScraper::REQUEST_INTERVAL
    end

    puts "\n=== 結果 ==="
    puts "更新: #{updated}"
    puts "スキップ: #{skipped}"
    puts "エラー: #{errors}"
  end

  desc "DMMぱちタウン 全取得（一覧→詳細）"
  task import_all: :environment do
    Rake::Task["ptown:import_machines"].invoke
    Rake::Task["ptown:import_details"].invoke
  end

  desc "DMMぱちタウンからイベント情報を取得（取材・新台入替等）"
  task :import_events, [:area] => :environment do |_t, args|
    $stdout.sync = true
    area = args[:area]

    puts "=== DMMぱちタウン イベント取得 ==="

    # DMMぱちタウンのエリアページ一覧（area未指定時は全エリア）
    areas = if area.present?
              [area]
            else
              # 主要エリアスラッグ (DMMぱちタウンの /shops/{area} 形式)
              Prefecture.pluck(:slug)
            end

    created = 0
    skipped = 0
    errors = 0

    areas.each do |area_slug|
      url = "#{PtownScraper::BASE_URL}/shops/#{area_slug}"
      doc = PtownScraper.fetch_page(url)

      unless doc
        puts "  #{area_slug}: ページ取得失敗"
        errors += 1
        next
      end

      # イベント情報のパース (li.eventItem or similar)
      doc.css(".event-item, .eventItem, [class*='event']").each do |event_el|
        begin
          title = event_el.at_css(".title, h3, h4")&.text&.strip
          next if title.blank?

          date_text = event_el.at_css(".date, time, .schedule")&.text&.strip
          next if date_text.blank?

          event_date = if date_text.match(/(\d{4})年(\d{1,2})月(\d{1,2})日/)
                         Date.new($1.to_i, $2.to_i, $3.to_i) rescue nil
                       elsif date_text.match(/(\d{1,2})月(\d{1,2})日/)
                         Date.new(Date.current.year, $1.to_i, $2.to_i) rescue nil
                       end
          next unless event_date

          shop_name = event_el.at_css(".shop-name, .shopName, .name")&.text&.strip
          next if shop_name.blank?

          # 店舗名マッチング (部分一致)
          shop = Shop.where("name LIKE ?", "%#{shop_name.truncate(20, omission: '')}%").first
          next unless shop

          # イベントタイプ判定
          event_type = case title
                       when /取材|来店/ then :filming
                       when /新台|入替|導入/ then :new_machine
                       when /リニューアル/ then :remodel
                       when /特定日|旧イベ/ then :special_day
                       else :other
                       end

          source_url_el = event_el.at_css("a[href]")
          source_url = source_url_el ? "#{PtownScraper::BASE_URL}#{source_url_el['href']}" : nil

          # 重複チェック (同店舗・同日・同タイトル)
          existing = ShopEvent.find_by(shop: shop, event_date: event_date, title: title.truncate(100))
          if existing
            skipped += 1
            next
          end

          ShopEvent.create!(
            shop: shop,
            event_date: event_date,
            event_type: event_type,
            title: title.truncate(100),
            source_url: source_url,
            source: "ptown",
            status: :approved
          )
          created += 1
        rescue => e
          errors += 1
          puts "  ERROR: #{e.message}"
        end
      end

      sleep PtownScraper::REQUEST_INTERVAL
    end

    puts "\n=== 結果 ==="
    puts "新規作成: #{created}"
    puts "スキップ (重複): #{skipped}"
    puts "エラー: #{errors}"
  end
end

# Helper: build mapping of MachineModel -> ptown_id
# Uses DB-stored ptown_id first, falls back to list page scraping for unmatched
def fetch_ptown_id_mapping
  puts "--- ptown_id マッピング構築中... ---"

  # Phase 1: Use already-stored ptown_ids from DB
  matched = MachineModel.active.where.not(ptown_id: nil).map { |m| [m, m.ptown_id] }
  puts "  DB保存済み: #{matched.size}件"

  if matched.size >= MachineModel.active.count / 2
    puts "マッチ: #{matched.size}/#{MachineModel.active.count} (#{(matched.size.to_f / MachineModel.active.count * 100).round(1)}%)"
    return matched
  end

  # Phase 2: Fall back to scraping list pages for remaining
  puts "  一覧ページから追加マッピング取得..."
  ptown_entries = []
  page = 1
  total_pages = nil

  loop do
    url = "#{PtownScraper::BASE_URL}/machines/slot?page=#{page}"
    doc = PtownScraper.fetch_page(url)
    break unless doc

    if total_pages.nil?
      last_page_link = doc.css("a").select { |a| a["href"]&.include?("page=") }.last
      if last_page_link && last_page_link["href"].match(/page=(\d+)/)
        total_pages = $1.to_i
      else
        total_pages = page
      end
    end

    PtownScraper.parse_list_page(doc).each do |entry|
      ptown_entries << entry
    end

    print "\r  一覧取得: #{page}/#{total_pages}"
    break if page >= total_pages
    page += 1
    sleep PtownScraper::REQUEST_INTERVAL
  end
  puts ""

  # Build name -> ptown_id lookup (NFKC normalized)
  ptown_by_slug = ptown_entries.each_with_object({}) do |entry, h|
    slug = PtownScraper.normalize_slug(entry[:name])
    h[slug] = entry[:ptown_id]
  end

  existing_ptown_ids = matched.map(&:last).to_set
  MachineModel.active.where(ptown_id: nil).find_each do |machine|
    slug = PtownScraper.normalize_slug(machine.name)
    ptown_id = ptown_by_slug[slug]
    if ptown_id && !existing_ptown_ids.include?(ptown_id)
      machine.update_column(:ptown_id, ptown_id)
      matched << [machine, ptown_id]
      existing_ptown_ids << ptown_id
    end
  end

  puts "マッチ: #{matched.size}/#{MachineModel.active.count} (#{(matched.size.to_f / MachineModel.active.count * 100).round(1)}%)"
  matched
end
