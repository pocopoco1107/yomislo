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
  REQUEST_INTERVAL = 5.0
  MAX_RETRIES = 3

  class << self
    def fetch_page(url)
      uri = URI.parse(url)
      retries = 0
      redirects = 0
      timeout_waits = [ 15, 60, 180 ]
      rate_limit_waits = [ 30, 120, 300 ]
      max_wait = 300

      loop do
        begin
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == "https")
          http.open_timeout = 30
          http.read_timeout = 60

          request = Net::HTTP::Get.new(uri.request_uri)
          request["User-Agent"] = USER_AGENT
          request["Accept"] = "text/html,application/xhtml+xml"
          request["Accept-Language"] = "ja"

          response = http.request(request)

          case response
          when Net::HTTPRedirection
            redirects += 1
            if redirects > 5
              puts "  ERROR: Too many redirects for #{url}"
              return nil
            end
            uri = URI.parse(response["location"])
            next
          when Net::HTTPSuccess
            return Nokogiri::HTML(response.body, nil, "UTF-8")
          when Net::HTTPTooManyRequests
            retries += 1
            if retries <= MAX_RETRIES
              retry_after = response["Retry-After"]&.to_i
              wait = if retry_after && retry_after > 0
                       [ retry_after, max_wait ].min
              else
                       rate_limit_waits[retries - 1] || max_wait
              end
              puts "  429 Too Many Requests, waiting #{wait}s (retry #{retries}/#{MAX_RETRIES})..."
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
            wait = timeout_waits[retries - 1] || max_wait
            puts "  #{e.class}, retry #{retries}/#{MAX_RETRIES} (waiting #{wait}s)..."
            sleep wait
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

    # あいまいマッチ用: プレフィックス/サフィックス(型式記号)を除去したコア名
    def core_name(name)
      name
        .unicode_normalize(:nfkc)
        .gsub(/\A[SLPA]\s*(?=[^\x00-\x7F])/, "") # 先頭の型式記号 + 日本語が続く場合 (L, S, P, A)
        .gsub(/\Aパチスロ\s*/, "")                # "パチスロ"プレフィックス
        .gsub(/\Aスロット\s*/, "")                # "スロット"プレフィックス
        .gsub(/\Aスマスロ\s*/, "")                # "スマスロ"プレフィックス
        .gsub(/\Aスマート沖スロ\s*/, "")          # "スマート沖スロ"プレフィックス
        .gsub(/\s+[A-Z]{1,3}\z/, "")             # 末尾の型式コード (KR, ZF, KM等)
        .gsub(/[[:space:]]+/, "")                 # 全スペース除去
        .gsub(/[^\p{L}\p{N}]/, "")               # 記号除去
        .downcase
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
      # ページ全体から取得するため、機種タイプに関係ないタグ("店舗","導入済み"等)を除外
      valid_type_keywords = /\A(スマスロ|スマート|AT|ART|RT|CZ|Aタイプ|ノーマル|ボーナス|天井|純増|疑似|リアル|\d+[\.\d]*号機|\d+Φ|30Φ)/
      type_tags = doc.css("span.text-icon").map { |t| t.text.strip }
                     .reject(&:blank?)
                     .select { |t| t.match?(valid_type_keywords) }
      info[:type_detail] = type_tags.join("、") if type_tags.any?

      info
    end

    # ── 店舗スクレイピング ──

    # 都道府県ページからarea(市区町村)URLリストを抽出
    def parse_prefecture_areas(doc, pref_slug)
      areas = []
      doc.css("a[href*='/shops/#{pref_slug}/area/']").each do |link|
        href = link["href"]
        next unless href.match?(%r{/area/\d+})
        text = link.text.strip
        # "千代田区(5)" → name: "千代田区", count: 5
        name = text.sub(/\(\d+\)$/, "").strip
        count = text.match(/\((\d+)\)/)&.[](1)&.to_i || 0
        areas << { url: "#{BASE_URL}#{href}", name: name, count: count }
      end
      areas
    end

    # areaページから店舗エントリを抽出
    # HTML構造: <a class="link" href="/shops/{pref}/{id}">
    #   <div class="cell"><p class="title">店舗名</p><p class="lead">住所</p><p class="lead">営業時間</p>...</div>
    # </a>
    def parse_area_shops(doc, pref_slug)
      shops = []
      doc.css("a.link[href]").each do |link|
        href = link["href"]
        next unless href.match?(%r{/shops/#{Regexp.escape(pref_slug)}/\d+\z})

        shop_id = href.split("/").last.to_i

        name = link.at_css("p.title")&.text&.strip
        next if name.blank?

        # p.lead: 住所(1個目) と 営業時間(2個目, "営業時間"含む)
        leads = link.css("p.lead").map { |p| p.text.strip }
        address = leads.find { |t| t.match?(/[都道府県]/) }
        hours_text = leads.find { |t| t.match?(/営業時間/) }
        hours = hours_text&.sub(/営業時間[：:]?\s*/, "")&.strip

        shops << {
          ptown_shop_id: shop_id,
          name: name.unicode_normalize(:nfkc),
          address: address&.unicode_normalize(:nfkc),
          business_hours: hours&.unicode_normalize(:nfkc),
          url: "#{BASE_URL}#{href}"
        }
      end
      shops
    end

    # 店舗詳細ページからJSON-LD + 機種リストを抽出
    def parse_shop_detail(doc)
      info = {}

      # JSON-LDから基本情報
      doc.css('script[type="application/ld+json"]').each do |script|
        begin
          data = JSON.parse(script.text)
          next unless data["@type"]&.match?(/Business|LocalBusiness|Entertainment/i)
          info[:name] = data["name"]
          info[:phone_number] = data["telephone"]
          info[:business_hours] = data["openingHours"]
          if data["address"].is_a?(Hash)
            region = data.dig("address", "addressRegion") || ""
            locality = data.dig("address", "addressLocality") || ""
            street = data.dig("address", "streetAddress") || ""
            info[:address] = "#{region}#{locality}#{street}"
          end
          if data["geo"].is_a?(Hash)
            info[:lat] = data.dig("geo", "latitude")&.to_f
            info[:lng] = data.dig("geo", "longitude")&.to_f
          end
        rescue JSON::ParserError
          next
        end
      end

      # 基本情報テーブル (table.default-table) のパース
      basic_info = parse_basic_info_table(doc)
      info[:facility_attrs] = basic_info[:facility_attrs]
      info[:facility_parsed_at] = basic_info[:facility_parsed_at]
      info[:parking_spaces] = basic_info[:parking_spaces] if basic_info[:parking_spaces]
      info[:regular_holiday] = basic_info[:regular_holiday] if basic_info[:regular_holiday]

      # 駐車場フォールバック: テーブルから取れなかったら本文テキストから
      if info[:parking_spaces].nil?
        doc.text.scan(/駐車場[：:]?\s*(\d+)台/).each do |m|
          info[:parking_spaces] = m[0].to_i
        end
      end

      # スロット設置機種リスト (#anc-slot セクション)
      machines = []
      slot_section = doc.at_css("#anc-slot")
      if slot_section
        # #anc-slot以降の要素を走査
        current_rate = nil
        node = slot_section.next_element
        while node
          # レートのh4見出し: "[21.739] スロ"
          if node.name == "h4"
            rate_text = node.text.strip
            if rate_text.match(/\[(.+?)\]\s*スロ/)
              current_rate = $1.strip
            end
          end

          # 機種リストのli要素
          node.css("a[href^='/machines/']").each do |link|
            href = link["href"]
            ptown_id = href.split("/").last.to_i
            machine_name = link.text.strip
            next if machine_name.blank?

            # 台数: 同じli内の<span>
            li = link.ancestors("li").first || link.parent
            unit_text = li&.css("span")&.map(&:text)&.find { |t| t.match?(/\d+\s*台/) }
            unit_count = unit_text&.match(/(\d+)\s*台/)&.[](1)&.to_i

            machines << {
              ptown_id: ptown_id,
              name: machine_name.unicode_normalize(:nfkc),
              unit_count: unit_count,
              rate: current_rate
            }
          end

          # 次のh3(パチンコセクション等)が来たら終了
          break if node.name == "h3" && node["id"] != "anc-slot"
          node = node.next_element
        end
      end

      info[:machines] = machines
      info
    end

    # 基本情報テーブルのキーワード判定マップ
    # サンプリング (lib/tasks/ptown.rake :dump_facility_text 141店) で確定した表記。
    # 各値は { positive: [...], section: :symbol } 形式
    FACILITY_KEYWORD_MAP = {
      heated_tobacco_ok:   { positive: [ "加熱式たばこ喫煙遊技エリア" ],     section: "設備" },
      slot_smoking_ok:     { positive: [ "20円スロット喫煙可", "5円スロット喫煙可" ], section: "設備" },
      low_rate_slot:       { positive: [ "パチスロ低貸あり" ],              section: "特徴" },
      wifi_available:      { positive: [ "Wi-Fi利用可" ],                   section: "サービス" },
      charging_available:  { positive: [ "携帯電話充電可能" ],              section: "サービス" },
      data_publishing:     { positive: [ "データ公開中" ],                  section: "特徴" },
      okislot:             { positive: [ "沖スロ" ],                        section: "特徴" },
      open_year_round:     { positive: [ "年中無休" ],                      section: "定休日" }
    }.freeze

    NEGATION_PATTERNS = %w[なし 不可 非対応 ありません NG].freeze

    # 店舗基本情報テーブルをパース
    # @return [Hash] {facility_attrs:, facility_parsed_at:, parking_spaces:, regular_holiday:}
    def parse_basic_info_table(doc)
      result = {
        facility_attrs: {},
        facility_parsed_at: nil,
        parking_spaces: nil,
        regular_holiday: nil
      }

      table = doc.at_css("table.default-table")
      return result unless table

      # tr.tr の th -> td を Hash 化
      cells = {}
      table.css("tr.tr").each do |tr|
        th = tr.at_css("th.th")&.text&.strip&.gsub(/\s+/, " ")
        td = tr.at_css("td.td")&.text&.strip&.gsub(/\s+/, " ")
        next if th.blank?
        cells[th] = td
      end

      relevant_sections = %w[設備 サービス 特徴 入場ルール ルール詳細 整理券 定休日]
      result[:facility_parsed_at] = Time.current if (cells.keys & relevant_sections).any?

      attrs = {}

      # boolean フラグ判定
      FACILITY_KEYWORD_MAP.each do |attr_name, config|
        section_text = cells[config[:section]]
        next if section_text.blank?
        attrs[attr_name] = keyword_present?(section_text, config[:positive])
      end

      # 整理券 (専用セル: "あり"/"なし"/"--")
      if (ticket = cells["整理券"])
        case ticket.strip
        when "あり" then attrs[:ticket_distribution] = true
        when "なし" then attrs[:ticket_distribution] = false
        end
      end

      # 入場方法
      if (entry = cells["入場ルール"])
        attrs[:entry_method] =
          if entry.include?("抽選") || entry.include?("モバイル抽選") then "lottery"
          elsif entry.include?("並び順") || entry.include?("並び") then "queue"
          elsif entry.include?("その他") then "other"
          end
      end

      # 定休日生テキスト (フリーテキスト保存、フィルタ用は open_year_round)
      if (holiday = cells["定休日"]) && !holiday.match?(/\A-+\z/)
        result[:regular_holiday] = holiday.truncate(200)
      end

      # 駐車場 (テーブル経由で台数抽出)
      if (parking = cells["駐車場"]) && (m = parking.match(/(\d+)\s*台/))
        result[:parking_spaces] = m[1].to_i
      end

      result[:facility_attrs] = attrs
      result
    end

    # text の中にいずれかの positive キーワードが含まれ、
    # かつ前後20文字以内に否定語がなければ true、否定語があれば false、
    # キーワード自体がなければ nil を返す。
    def keyword_present?(text, positives)
      return nil if text.blank?
      positives.each do |kw|
        idx = text.index(kw)
        next unless idx
        window_start = [ idx - 20, 0 ].max
        window_end = [ idx + kw.length + 20, text.length ].min
        window = text[window_start...window_end]
        return false if NEGATION_PATTERNS.any? { |neg| window.include?(neg) }
        return true
      end
      nil
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

    # Build in-memory lookups to avoid N+1 queries
    all_models = MachineModel.select(:id, :name, :slug, :ptown_id, :maker, :payout_rate_min, :payout_rate_max,
                                     :introduced_on, :image_url, :is_smart_slot, :active).to_a
    ptown_id_lookup = all_models.select(&:ptown_id).index_by(&:ptown_id)
    slug_lookup = all_models.index_by(&:slug)
    existing_ptown_ids = Set.new(ptown_id_lookup.keys)
    existing_slugs = Set.new(slug_lookup.keys)

    # core_name lookup (ptown_idなし機種を優先)
    core_name_lookup = {}
    all_models.sort_by { |m| m.ptown_id ? 1 : 0 }.each do |m|
      cn = PtownScraper.core_name(m.name)
      core_name_lookup[cn] = m.id if core_name_lookup[cn].nil? || m.ptown_id.nil?
    end

    all_machines.each_with_index do |data, i|
      # 1. ptown_idで直接検索（最優先）
      machine = ptown_id_lookup[data[:ptown_id]] if data[:ptown_id]
      # 2. slugで検索
      if machine.nil?
        slug = PtownScraper.normalize_slug(data[:name])
        machine = slug_lookup[slug]
      end
      # 3. core_nameであいまい検索
      if machine.nil?
        cn = PtownScraper.core_name(data[:name])
        machine_id = core_name_lookup[cn]
        machine = MachineModel.find_by(id: machine_id) if machine_id
      end

      # スマスロ判定（名前のＬプレフィックスやスマスロキーワード）
      is_smart = data[:name].match?(/\A[Ｌ]/) || data[:name].include?("スマスロ")

      if machine
        # Reload full record for update (lookup used select)
        machine = MachineModel.find(machine.id) if machine.readonly? || !machine.has_attribute?(:ceiling_info)

        attrs = {}
        attrs[:maker] = data[:maker] if data[:maker].present? && machine.maker.blank?
        attrs[:payout_rate_min] = data[:payout_rate_min] if data[:payout_rate_min]
        attrs[:payout_rate_max] = data[:payout_rate_max] if data[:payout_rate_max]
        attrs[:introduced_on] = data[:introduced_on] if data[:introduced_on] && machine.introduced_on.blank?
        attrs[:image_url] = data[:image_url] if data[:image_url].present?  # 常に最新画像で上書き
        # ptown_idセット（未設定の場合）
        if data[:ptown_id] && machine.ptown_id != data[:ptown_id]
          if machine.ptown_id.blank? && !existing_ptown_ids.include?(data[:ptown_id])
            attrs[:ptown_id] = data[:ptown_id]
            existing_ptown_ids.add(data[:ptown_id])
          end
        end
        # ptownの正式名に更新
        if data[:ptown_id] && machine.ptown_id == data[:ptown_id]
          attrs[:name] = data[:name] if machine.name != data[:name]
          new_slug = PtownScraper.normalize_slug(data[:name])
          if machine.slug != new_slug && !existing_slugs.include?(new_slug)
            attrs[:slug] = new_slug
            existing_slugs.delete(machine.slug)
            existing_slugs.add(new_slug)
          end
        end
        attrs[:is_smart_slot] = true if is_smart && !machine.is_smart_slot?
        attrs[:active] = true unless machine.active?

        if attrs.any?
          machine.update!(attrs)
          updated += 1
        else
          skipped += 1
        end
      else
        # 新規作成前にptown_id重複チェック
        if data[:ptown_id] && existing_ptown_ids.include?(data[:ptown_id])
          skipped += 1
          next
        end
        MachineModel.create!(
          name: data[:name],
          slug: slug,
          maker: data[:maker],
          payout_rate_min: data[:payout_rate_min],
          payout_rate_max: data[:payout_rate_max],
          introduced_on: data[:introduced_on],
          image_url: data[:image_url],
          ptown_id: data[:ptown_id],
          is_smart_slot: is_smart,
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

    # 検証
    ptown_count = all_machines.size
    db_count = MachineModel.where.not(ptown_id: nil).count
    diff = ptown_count - db_count
    puts "\n検証: ptown #{ptown_count}機種, DB #{db_count}機種 (差分: #{diff})"
    puts "WARNING: #{diff}機種が未マッチ" if diff > 5
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
        attrs[:type_detail] = info[:type_detail] if info[:type_detail].present?  # ptownが正。常に上書き

        if attrs.any?
          machine.update!(attrs)
          updated += 1
          puts "  → 更新 (#{attrs.keys.join(', ')})"
        else
          skipped += 1
          puts "  → スキップ（更新項目なし）"
        end
      rescue ActiveRecord::RecordInvalid => e
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
  task :import_events, [ :area ] => :environment do |_t, args|
    $stdout.sync = true
    area = args[:area]

    puts "=== DMMぱちタウン イベント取得 ==="

    # DMMぱちタウンのエリアページ一覧（area未指定時は全エリア）
    areas = if area.present?
              [ area ]
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

  desc "DMMぱちタウンから店舗一覧を取得・更新（都道府県指定可）"
  task :import_shops, [ :pref_slug ] => :environment do |_t, args|
    $stdout.sync = true
    pref_slug = args[:pref_slug]

    prefectures = if pref_slug.present?
                    Prefecture.where(slug: pref_slug)
    else
                    Prefecture.order(:id)
    end

    if prefectures.empty?
      puts "ERROR: Prefecture '#{pref_slug}' not found"
      next
    end

    puts "=== DMMぱちタウン 店舗インポート ==="
    total_created = 0
    total_updated = 0
    total_matched = 0
    seen_ptown_ids = Set.new

    prefectures.each do |pref|
      puts "\n--- #{pref.name} (#{pref.slug}) ---"

      # Step 1: 都道府県ページからareaリストを取得
      pref_url = "#{PtownScraper::BASE_URL}/shops/#{pref.slug}"
      pref_doc = PtownScraper.fetch_page(pref_url)
      unless pref_doc
        puts "  ページ取得失敗: #{pref_url}"
        next
      end

      areas = PtownScraper.parse_prefecture_areas(pref_doc, pref.slug)
      puts "  #{areas.size} エリア検出 (計 #{areas.sum { |a| a[:count] }} 店舗)"
      sleep PtownScraper::REQUEST_INTERVAL

      # Step 2: 各areaページから店舗リストを取得
      all_shops = []
      areas.each_with_index do |area, ai|
        next if area[:count] == 0

        area_doc = PtownScraper.fetch_page(area[:url])
        unless area_doc
          puts "  #{area[:name]}: 取得失敗"
          next
        end

        shops = PtownScraper.parse_area_shops(area_doc, pref.slug)
        all_shops.concat(shops)
        print "\r  エリア: #{ai + 1}/#{areas.size} (累計: #{all_shops.size}店舗)"
        sleep PtownScraper::REQUEST_INTERVAL
      end
      puts ""

      # Step 3: 店舗をDB反映
      # 既存店舗との名前マッチング（同県内で名前の完全一致のみ）
      pref_shops = pref.shops.to_a
      existing_shops = pref_shops.index_by { |s| s.name.unicode_normalize(:nfkc).gsub(/[[:space:]]/, "") }

      pref_created = 0
      pref_updated = 0
      pref_matched = 0

      all_shops.each do |shop_data|
        next if seen_ptown_ids.include?(shop_data[:ptown_shop_id])
        seen_ptown_ids.add(shop_data[:ptown_shop_id])
        normalized_name = shop_data[:name].gsub(/[[:space:]]/, "")

        # 1. ptown_shop_idで既存マッチ
        shop = Shop.find_by(ptown_shop_id: shop_data[:ptown_shop_id])

        # 2. 名前完全一致でマッチ（ptown_shop_id未設定の既存店舗用）
        shop = existing_shops[normalized_name] if shop.nil?

        if shop
          attrs = {}
          attrs[:ptown_shop_id] = shop_data[:ptown_shop_id] if shop.ptown_shop_id.blank?
          attrs[:address] = shop_data[:address] if shop_data[:address].present? && shop.address.blank?
          attrs[:business_hours] = shop_data[:business_hours] if shop_data[:business_hours].present? && shop.business_hours.blank?

          if attrs.any?
            shop.update!(attrs)
            pref_updated += 1
          else
            pref_matched += 1
          end
        else
          # 新規店舗（ptownにしかない）
          slug = PtownScraper.normalize_slug(shop_data[:name])
          # slug重複回避
          if Shop.exists?(slug: slug)
            slug = "#{slug}-#{shop_data[:ptown_shop_id]}"
          end

          Shop.create!(
            prefecture: pref,
            name: shop_data[:name],
            slug: slug,
            ptown_shop_id: shop_data[:ptown_shop_id],
            address: shop_data[:address],
            business_hours: shop_data[:business_hours]
          )
          pref_created += 1
        end
      end

      total_created += pref_created
      total_updated += pref_updated
      total_matched += pref_matched
      puts "  #{pref.name}: 新規 #{pref_created}, 更新 #{pref_updated}, 既存 #{pref_matched}"
    end

    puts "\n=== 結果 ==="
    puts "新規作成: #{total_created}"
    puts "更新: #{total_updated}"
    puts "既存マッチ: #{total_matched}"
    puts "合計: #{Shop.count} 店舗"
  end

  desc "DMMぱちタウンから店舗の設置機種リストを同期（都道府県指定可、未同期店舗を優先）"
  task :sync_shop_machines, [ :pref_slug ] => :environment do |_t, args|
    $stdout.sync = true
    pref_slug = args[:pref_slug]
    force = ENV["FORCE"] == "1"

    prefectures = if pref_slug.present?
                    Prefecture.where(slug: pref_slug)
    else
                    Prefecture.order(:id)
    end

    if prefectures.empty?
      puts "ERROR: Prefecture '#{pref_slug}' not found"
      next
    end

    puts "=== DMMぱちタウン 設置機種同期 ==="

    # ptown_id → MachineModel のルックアップ
    machine_by_ptown_id = MachineModel.where.not(ptown_id: nil).index_by(&:ptown_id)

    total_synced = 0
    total_errors = 0
    total_machines_added = 0
    total_machines_removed = 0
    total_skipped = 0
    total_target = 0

    prefectures.each do |pref|
      base_scope = pref.shops.where.not(ptown_shop_id: nil)

      shops = if force
                base_scope.order(:id)
      else
                base_scope.where(last_synced_at: nil).or(base_scope.where(last_synced_at: ...1.day.ago)).order(:last_synced_at)
      end

      pref_total = shops.count
      pref_skipped = base_scope.count - pref_total
      total_skipped += pref_skipped
      total_target += pref_total

      if pref_total == 0
        puts "  #{pref.name}: スキップ (#{pref_skipped}店舗 同期済み)"
        next
      end

      puts "\n--- #{pref.name} (#{pref.slug}): #{pref_total}店舗 (スキップ: #{pref_skipped}) ---"

      pref_synced = 0
      pref_errors = 0
      pref_added = 0
      pref_removed = 0

      shops.find_each.with_index do |shop, i|
        url = "#{PtownScraper::BASE_URL}/shops/#{pref.slug}/#{shop.ptown_shop_id}"

        doc = PtownScraper.fetch_page(url)
        unless doc
          pref_errors += 1
          next
        end

        begin
          info = PtownScraper.parse_shop_detail(doc)

          # 店舗基本情報の更新 (last_synced_atは成功時のみ)
          shop_attrs = {}
          shop_attrs[:phone_number] = info[:phone_number] if info[:phone_number].present? && shop.phone_number.blank?
          shop_attrs[:address] = info[:address] if info[:address].present? && shop.address.blank?
          shop_attrs[:business_hours] = info[:business_hours] if info[:business_hours].present? && shop.business_hours.blank?
          shop_attrs[:parking_spaces] = info[:parking_spaces] if info[:parking_spaces] && shop.parking_spaces.blank?
          shop_attrs[:lat] = info[:lat] if info[:lat] && shop.lat.blank?
          shop_attrs[:lng] = info[:lng] if info[:lng] && shop.lng.blank?

          # 設備情報の更新 (DMM取得値が nil なら既存値維持、true/false/string なら上書き)
          if info[:facility_attrs].is_a?(Hash)
            info[:facility_attrs].each do |key, value|
              shop_attrs[key] = value unless value.nil?
            end
          end
          shop_attrs[:regular_holiday] = info[:regular_holiday] if info[:regular_holiday].present?
          # facility_parsed_at はパース成否（成功/部分成功）のメタ情報として常時更新
          shop_attrs[:facility_parsed_at] = info[:facility_parsed_at] if info[:facility_parsed_at]

          # 設置機種の同期
          page_ptown_ids = info[:machines].map { |m| m[:ptown_id] }.to_set
          existing_smms = shop.shop_machine_models.includes(:machine_model).index_by { |smm| smm.machine_model&.ptown_id }

          # 追加
          info[:machines].each do |m_data|
            machine = machine_by_ptown_id[m_data[:ptown_id]]
            next unless machine  # ptownマスタにない機種はスキップ

            smm = existing_smms[m_data[:ptown_id]]
            if smm
              # 台数更新
              smm.update_column(:unit_count, m_data[:unit_count]) if m_data[:unit_count] && smm.unit_count != m_data[:unit_count]
            else
              smm_new = ShopMachineModel.create(shop: shop, machine_model: machine, unit_count: m_data[:unit_count])
              pref_added += 1 if smm_new.persisted?
            end
          end

          # 削除（ptownに載っていない機種を除去）
          stale = existing_smms.reject { |pid, smm| pid.nil? || page_ptown_ids.include?(pid) || smm.data_source == "pworld" }
          if stale.any?
            ShopMachineModel.where(id: stale.values.map(&:id)).delete_all
            pref_removed += stale.size
          end

          # 成功時のみ last_synced_at を更新
          shop_attrs[:last_synced_at] = Time.current
          shop.update_columns(shop_attrs)

          pref_synced += 1
        rescue ActiveRecord::RecordInvalid, JSON::ParserError => e
          pref_errors += 1
          puts "  ERROR #{shop.name}: #{e.message}"
          # エラー時は last_synced_at を更新しない（次回リトライ対象）
        end

        print "\r  #{pref.name}: #{i + 1}/#{pref_total} 同期済: #{pref_synced} 追加: #{pref_added} 削除: #{pref_removed} エラー: #{pref_errors}" if (i + 1) % 10 == 0
        sleep PtownScraper::REQUEST_INTERVAL
      end

      puts "\n  #{pref.name}: 同期 #{pref_synced}, 追加 #{pref_added}, 削除 #{pref_removed}, エラー #{pref_errors}"

      total_synced += pref_synced
      total_errors += pref_errors
      total_machines_added += pref_added
      total_machines_removed += pref_removed
    end

    puts "\n\n=== 結果 ==="
    puts "同期完了: #{total_synced}"
    puts "機種追加: #{total_machines_added}"
    puts "機種削除: #{total_machines_removed}"
    puts "エラー: #{total_errors}"
    puts "スキップ: #{total_skipped}店舗 (24時間以内に同期済み)"

    synced_count = Shop.where.not(ptown_shop_id: nil).where.not(last_synced_at: nil).count
    all_ptown_count = Shop.where.not(ptown_shop_id: nil).count
    puts "検証: #{synced_count}/#{all_ptown_count}店舗 同期済み"
  end

  desc "DMMぱちタウンとDBのデータ件数を県別に比較検証"
  task verify_data: :environment do
    $stdout.sync = true
    puts "=== データ検証 ==="
    puts ""

    total_ptown = 0
    total_db = 0
    total_smm = 0
    total_synced = 0
    issues = []

    Prefecture.order(:id).each do |pref|
      url = "#{PtownScraper::BASE_URL}/shops/#{pref.slug}"
      doc = PtownScraper.fetch_page(url)
      unless doc
        puts "  #{pref.name}: ページ取得失敗"
        sleep PtownScraper::REQUEST_INTERVAL
        next
      end

      areas = PtownScraper.parse_prefecture_areas(doc, pref.slug)
      ptown_count = areas.sum { |a| a[:count] }

      db_count = pref.shops.where.not(ptown_shop_id: nil).count
      smm_count = pref.shops.joins(:shop_machine_models).distinct.count
      synced_count = pref.shops.where.not(last_synced_at: nil).count

      total_ptown += ptown_count
      total_db += db_count
      total_smm += smm_count
      total_synced += synced_count

      diff = ptown_count - db_count
      mark = diff > 0 ? " ← #{diff}店不足" : ""
      puts "  #{pref.name.ljust(5)}: ptown=#{ptown_count.to_s.rjust(4)} DB=#{db_count.to_s.rjust(4)} SMMあり=#{smm_count.to_s.rjust(4)} 同期済=#{synced_count.to_s.rjust(4)}#{mark}"

      issues << { pref: pref.name, slug: pref.slug, diff: diff } if diff > 0

      sleep PtownScraper::REQUEST_INTERVAL
    end

    puts "\n=== 合計 ==="
    puts "ptown店舗: #{total_ptown}"
    puts "DB店舗: #{total_db}"
    puts "SMMあり: #{total_smm}"
    puts "同期済み: #{total_synced}"
    puts "不足: #{total_ptown - total_db}"

    if issues.any?
      puts "\n=== 店舗不足の県 (import_shops再実行が必要) ==="
      issues.sort_by { |i| -i[:diff] }.each { |i| puts "  #{i[:pref]}: #{i[:diff]}店不足 → rake ptown:import_shops[#{i[:slug]}]" }
    end
  end

  desc "重複機種のマージ（core_name一致でShopMachineModel移行）"
  task merge_duplicates: :environment do
    $stdout.sync = true
    puts "=== 重複機種マージ ==="

    # core_nameでグループ化
    groups = {}
    MachineModel.active.find_each do |m|
      cn = PtownScraper.core_name(m.name)
      next if cn.blank? || cn.size < 2
      (groups[cn] ||= []) << m
    end

    duplicates = groups.select { |_, machines| machines.size > 1 }
    puts "重複グループ: #{duplicates.size}件"

    # N+1回避: 全重複候補のshop_machine_models countを一括取得
    dup_ids = duplicates.values.flatten.map(&:id)
    smm_counts = ShopMachineModel.where(machine_model_id: dup_ids).group(:machine_model_id).count

    merged = 0
    moved_smms = 0

    duplicates.each do |cn, machines|
      # 優先: ptown_id有り > image_url有り > shop_machine_models数 > id小さい(古い)
      keeper = machines.sort_by { |m|
        [
          m.ptown_id.present? ? 0 : 1,
          m.image_url.present? ? 0 : 1,
          -(smm_counts[m.id] || 0),
          m.id
        ]
      }.first

      machines.each do |dup|
        next if dup.id == keeper.id

        ActiveRecord::Base.transaction do
          # ShopMachineModelを移行
          dup.shop_machine_models.each do |smm|
            # keeper側に同じshopの紐づけが既にあればスキップ
            if keeper.shop_machine_models.exists?(shop_id: smm.shop_id)
              existing = keeper.shop_machine_models.find_by(shop_id: smm.shop_id)
              # 台数が大きい方を残す
              if smm.unit_count.to_i > existing.unit_count.to_i
                existing.update_column(:unit_count, smm.unit_count)
              end
              smm.destroy
            else
              smm.update_column(:machine_model_id, keeper.id)
              moved_smms += 1
            end
          end

          # Vote, PlayRecord等も移行
          Vote.where(machine_model_id: dup.id).update_all(machine_model_id: keeper.id)
          VoteSummary.where(machine_model_id: dup.id).update_all(machine_model_id: keeper.id)
          PlayRecord.where(machine_model_id: dup.id).update_all(machine_model_id: keeper.id)

          # keeperにない属性を補完
          attrs = %i[maker ptown_id image_url type_detail payout_rate_min payout_rate_max
                     introduced_on ceiling_info reset_info].each_with_object({}) do |attr, h|
            h[attr] = dup.send(attr) if dup.send(attr).present? && keeper.send(attr).blank?
          end
          attrs[:is_smart_slot] = true if dup.is_smart_slot? && !keeper.is_smart_slot?
          keeper.update!(attrs) if attrs.any?

          # 重複を非アクティブ化
          dup.update_column(:active, false)
          merged += 1
        end
      end
    end

    puts "マージ完了: #{merged}件の重複を統合"
    puts "移行したShopMachineModel: #{moved_smms}件"
    puts "アクティブ機種: #{MachineModel.active.count}件"
  end

  desc "汚染されたtype_detailをクリーンアップし、画像なし機種を再取得対象に"
  task cleanup: :environment do
    $stdout.sync = true
    puts "=== DMMぱちタウン データクリーンアップ ==="

    # 1. type_detailに「店舗」「導入済み」が含まれるレコードをリセット
    contaminated = MachineModel.where("type_detail LIKE ? OR type_detail LIKE ?", "%店舗%", "%導入済み%")
    count = contaminated.count
    contaminated.update_all(type_detail: nil)
    puts "type_detail汚染修正: #{count}件をNULLリセット"

    # 2. is_smart_slot と名前ベースで明らかにスマスロの機種を補正
    smart_fixed = 0
    MachineModel.where(is_smart_slot: false).where("name LIKE ? OR name LIKE ? OR name LIKE ?", "%スマスロ%", "Ｌ %", "Ｌ%").find_each do |m|
      # Ｌ始まりは6.5号機(スマスロ)の型式記号
      if m.name.match?(/\AＬ/) || m.name.include?("スマスロ")
        m.update_columns(is_smart_slot: true)
        smart_fixed += 1
      end
    end
    puts "is_smart_slot補正: #{smart_fixed}件"

    # 3. active: false だが設置店舗がある機種をactive化
    inactive_with_shops = MachineModel.where(active: false)
                                       .joins(:shop_machine_models)
                                       .distinct
    reactivated = 0
    inactive_with_shops.find_each do |m|
      next if MachineModel.pachinko_name?(m.name)  # パチンコは除外
      m.update_columns(active: true)
      reactivated += 1
    end
    puts "再アクティブ化: #{reactivated}件（設置店舗あり & 非パチンコ）"

    # 4. サマリー
    puts "\n--- クリーンアップ後の状態 ---"
    active = MachineModel.active.count
    no_img = MachineModel.active.where(image_url: [ nil, "" ]).count
    no_ptown = MachineModel.active.where(ptown_id: nil).count
    puts "アクティブ機種: #{active}"
    puts "画像なし: #{no_img} (#{(no_img * 100.0 / active).round(1)}%)"
    puts "ptown_id未マッチ: #{no_ptown} (#{(no_ptown * 100.0 / active).round(1)}%)"
  end

  desc "1店舗のみsync動作確認 (debug, ptown_shop_id指定)"
  task :sync_one_shop, [ :ptown_shop_id ] => :environment do |_t, args|
    $stdout.sync = true
    ptown_id = args[:ptown_shop_id]&.to_i
    abort "Usage: rake ptown:sync_one_shop[ptown_shop_id]" unless ptown_id && ptown_id > 0

    shop = Shop.find_by(ptown_shop_id: ptown_id)
    abort "Shop not found for ptown_shop_id=#{ptown_id}" unless shop
    shop.reload

    puts "=== Before: #{shop.name} (#{shop.prefecture.slug}/#{ptown_id}) ==="
    %i[wifi_available charging_available heated_tobacco_ok slot_smoking_ok low_rate_slot
       data_publishing okislot open_year_round ticket_distribution entry_method
       regular_holiday facility_parsed_at parking_spaces].each do |attr|
      puts "  #{attr}: #{shop.public_send(attr).inspect}"
    end

    url = "#{PtownScraper::BASE_URL}/shops/#{shop.prefecture.slug}/#{shop.ptown_shop_id}"
    doc = PtownScraper.fetch_page(url)
    abort "fetch failed" unless doc

    info = PtownScraper.parse_shop_detail(doc)
    attrs = {}
    info[:facility_attrs].each { |k, v| attrs[k] = v unless v.nil? } if info[:facility_attrs].is_a?(Hash)
    attrs[:regular_holiday] = info[:regular_holiday] if info[:regular_holiday].present?
    attrs[:facility_parsed_at] = info[:facility_parsed_at] if info[:facility_parsed_at]
    attrs[:parking_spaces] = info[:parking_spaces] if info[:parking_spaces] && shop.parking_spaces.blank?

    puts "\n=== Would update with ==="
    attrs.each { |k, v| puts "  #{k}: #{v.inspect}" }

    shop.update_columns(attrs) if attrs.any?
    shop.reload

    puts "\n=== After ==="
    %i[wifi_available charging_available heated_tobacco_ok slot_smoking_ok low_rate_slot
       data_publishing okislot open_year_round ticket_distribution entry_method
       regular_holiday facility_parsed_at].each do |attr|
      puts "  #{attr}: #{shop.public_send(attr).inspect}"
    end
  end

  desc "フィクスチャHTMLでparse_basic_info_tableの動作確認 (debug)"
  task verify_parse_basic_info: :environment do
    %w[shop_with_smoking_areas shop_marhan shop_minimal].each do |name|
      path = Rails.root.join("spec/fixtures/ptown/#{name}.html")
      unless File.exist?(path)
        puts "skip: #{path} not found"
        next
      end
      doc = Nokogiri::HTML(File.read(path))
      result = PtownScraper.parse_basic_info_table(doc)
      puts "===== #{name} ====="
      puts "  facility_parsed_at: #{result[:facility_parsed_at].present? ? 'set' : 'nil'}"
      puts "  parking_spaces: #{result[:parking_spaces].inspect}"
      puts "  regular_holiday: #{result[:regular_holiday].inspect}"
      puts "  facility_attrs:"
      result[:facility_attrs].each { |k, v| puts "    #{k}: #{v.inspect}" }
      puts
    end
  end

  desc "店舗詳細の基本情報テーブル(設備/サービス/特徴/入場ルール/定休日)をCSVにダンプ"
  task :dump_facility_text, [ :per_pref ] => :environment do |_t, args|
    require "csv"
    $stdout.sync = true
    per_pref = (args[:per_pref] || 3).to_i

    out_path = Rails.root.join("tmp/ptown_facility_dump.csv")
    keys_of_interest = %w[設備 サービス 特徴 入場ルール ルール詳細 整理券 定休日]

    total_sampled = 0
    parsed_ok = 0

    CSV.open(out_path, "w") do |csv|
      csv << [ "prefecture", "shop_name", "ptown_shop_id", "url" ] + keys_of_interest

      Prefecture.order(:id).each do |pref|
        shops = pref.shops.where.not(ptown_shop_id: nil).order("RANDOM()").limit(per_pref)
        next if shops.empty?
        puts "--- #{pref.name} (#{shops.size}店) ---"

        shops.each do |shop|
          url = "#{PtownScraper::BASE_URL}/shops/#{pref.slug}/#{shop.ptown_shop_id}"
          doc = PtownScraper.fetch_page(url)
          total_sampled += 1

          unless doc
            csv << [ pref.name, shop.name, shop.ptown_shop_id, url ] + Array.new(keys_of_interest.size)
            next
          end

          table = doc.at_css("table.default-table")
          row = { "prefecture" => pref.name, "shop_name" => shop.name, "ptown_shop_id" => shop.ptown_shop_id, "url" => url }
          if table
            parsed_ok += 1
            table.css("tr.tr").each do |tr|
              th = tr.at_css("th.th")&.text&.strip&.gsub(/\s+/, " ")
              td = tr.at_css("td.td")&.text&.strip&.gsub(/\s+/, " ")
              next if th.blank?
              row[th] = td if keys_of_interest.include?(th)
            end
          end

          csv << [ row["prefecture"], row["shop_name"], row["ptown_shop_id"], row["url"] ] + keys_of_interest.map { |k| row[k] }
          sleep PtownScraper::REQUEST_INTERVAL
        end
      end
    end

    puts ""
    puts "=== サンプリング結果 ==="
    puts "総サンプル: #{total_sampled} 店"
    puts "table.default-table 取得成功: #{parsed_ok} 店 (#{(parsed_ok * 100.0 / total_sampled).round(1)}%)"
    puts "CSV: #{out_path}"
  end
end

# Helper: build mapping of MachineModel -> ptown_id
# Uses DB-stored ptown_id first, falls back to list page scraping for unmatched
def fetch_ptown_id_mapping
  puts "--- ptown_id マッピング構築中... ---"

  # Phase 1: Use already-stored ptown_ids from DB
  matched = MachineModel.active.where.not(ptown_id: nil).map { |m| [ m, m.ptown_id ] }
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

  # Phase 2: slug完全一致 → core_nameあいまい一致 (1パスで処理)
  ptown_by_core = ptown_entries.each_with_object({}) do |entry, h|
    cn = PtownScraper.core_name(entry[:name])
    h[cn] ||= entry
  end

  slug_matched = 0
  fuzzy_matched = 0
  MachineModel.active.where(ptown_id: nil).find_each do |machine|
    # slug完全一致を先に試行
    slug = PtownScraper.normalize_slug(machine.name)
    ptown_id = ptown_by_slug[slug]
    if ptown_id && !existing_ptown_ids.include?(ptown_id)
      machine.update_column(:ptown_id, ptown_id)
      matched << [ machine, ptown_id ]
      existing_ptown_ids << ptown_id
      slug_matched += 1
      next
    end

    # core_nameあいまい一致にフォールバック
    cn = PtownScraper.core_name(machine.name)
    entry = ptown_by_core[cn]
    if entry && !existing_ptown_ids.include?(entry[:ptown_id])
      attrs = { ptown_id: entry[:ptown_id] }
      attrs[:image_url] = entry[:image_url] if entry[:image_url].present? && machine.image_url.blank?
      machine.update_columns(attrs)
      matched << [ machine, entry[:ptown_id] ]
      existing_ptown_ids << entry[:ptown_id]
      fuzzy_matched += 1
    end
  end
  puts "  slug完全一致: +#{slug_matched}件, あいまい一致: +#{fuzzy_matched}件"

  puts "マッチ: #{matched.size}/#{MachineModel.active.count} (#{(matched.size.to_f / MachineModel.active.count * 100).round(1)}%)"
  matched
end
