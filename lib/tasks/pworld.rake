# frozen_string_literal: true

require "digest"
require "net/http"
require "nokogiri"
require "uri"

# P-WORLD scraping tasks for importing shop and machine data.
# P-WORLD URL patterns:
#   Shop search:  https://www.p-world.co.jp/_machine/alkensaku.cgi?k={prefecture_name}&is_new_ver=1&page={page}
#   Machine list:  https://www.p-world.co.jp/_machine/t_machine.cgi?mode=slot_type&key={type}&start={offset}
#   New machines: https://www.p-world.co.jp/database/machine/introduce_calendar.cgi

module PworldScraper
  BASE_URL = "https://www.p-world.co.jp"
  USER_AGENT = "Mozilla/5.0 (compatible; YomiSloBot/1.0; +https://yomislo.example.com)"
  REQUEST_INTERVAL = 2.5 # seconds between requests
  MAX_RETRIES = 3

  # Prefecture name => slug mapping used by P-WORLD search.
  # The search uses the Japanese prefecture name to find shops in that prefecture.
  PREFECTURE_SEARCH_NAMES = {
    "hokkaido"   => "北海道",
    "aomori"     => "青森県",
    "iwate"      => "岩手県",
    "miyagi"     => "宮城県",
    "akita"      => "秋田県",
    "yamagata"   => "山形県",
    "fukushima"  => "福島県",
    "ibaraki"    => "茨城県",
    "tochigi"    => "栃木県",
    "gunma"      => "群馬県",
    "saitama"    => "埼玉県",
    "chiba"      => "千葉県",
    "tokyo"      => "東京都",
    "kanagawa"   => "神奈川県",
    "niigata"    => "新潟県",
    "toyama"     => "富山県",
    "ishikawa"   => "石川県",
    "fukui"      => "福井県",
    "yamanashi"  => "山梨県",
    "nagano"     => "長野県",
    "gifu"       => "岐阜県",
    "shizuoka"   => "静岡県",
    "aichi"      => "愛知県",
    "mie"        => "三重県",
    "shiga"      => "滋賀県",
    "kyoto"      => "京都府",
    "osaka"      => "大阪府",
    "hyogo"      => "兵庫県",
    "nara"       => "奈良県",
    "wakayama"   => "和歌山県",
    "tottori"    => "鳥取県",
    "shimane"    => "島根県",
    "okayama"    => "岡山県",
    "hiroshima"  => "広島県",
    "yamaguchi"  => "山口県",
    "tokushima"  => "徳島県",
    "kagawa"     => "香川県",
    "ehime"      => "愛媛県",
    "kochi"      => "高知県",
    "fukuoka"    => "福岡県",
    "saga"       => "佐賀県",
    "nagasaki"   => "長崎県",
    "kumamoto"   => "熊本県",
    "oita"       => "大分県",
    "miyazaki"   => "宮崎県",
    "kagoshima"  => "鹿児島県",
    "okinawa"    => "沖縄県"
  }.freeze

  # Slot type keys used in P-WORLD machine search
  SLOT_TYPE_KEYS = %w[AT NORMAL RT aRT over_6.5number].freeze

  # Module-level cache for digit image map (same images across all shops)
  @digit_image_cache = {}

  class << self
    # Normalize a machine name into a URL-safe slug.
    def normalize_slug(name)
      name
        .gsub(/\s+/, "-")
        .gsub(/[^\p{L}\p{N}\-]/, "")
        .downcase
        .truncate(100, omission: "")
    end

    # Fetch a URL with retry logic and rate limiting.
    # Returns Nokogiri::HTML document or nil on failure.
    def fetch_page(url, encoding: nil)
      uri = URI.parse(url)
      retries = 0

      begin
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = 15
        http.read_timeout = 30

        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = USER_AGENT
        request["Accept"] = "text/html"
        request["Accept-Language"] = "ja,en;q=0.5"

        response = http.request(request)

        case response.code.to_i
        when 200
          body = response.body
          # Handle EUC-JP encoded pages (older P-WORLD pages)
          if encoding
            body = body.force_encoding(encoding).encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
          elsif body.force_encoding("UTF-8").valid_encoding?
            # Already UTF-8, do nothing
          else
            # Try EUC-JP as fallback (many P-WORLD pages use it)
            body = body.force_encoding("EUC-JP").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
          end
          Nokogiri::HTML(body)
        when 301, 302
          # Follow redirect
          new_url = response["Location"]
          new_url = "#{uri.scheme}://#{uri.host}#{new_url}" if new_url.start_with?("/")
          fetch_page(new_url, encoding: encoding)
        else
          puts "  WARNING: HTTP #{response.code} for #{url}"
          nil
        end
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, SocketError => e
        retries += 1
        if retries <= MAX_RETRIES
          puts "  RETRY #{retries}/#{MAX_RETRIES}: #{e.class} - #{e.message}"
          sleep(REQUEST_INTERVAL * retries)
          retry
        else
          puts "  ERROR: Failed after #{MAX_RETRIES} retries: #{e.message}"
          nil
        end
      rescue StandardError => e
        puts "  ERROR: #{e.class} - #{e.message}"
        nil
      end
    end

    # Generate a URL-safe slug from a shop's P-WORLD href path.
    # e.g., "/tokyo/maruhan-shinjuku.htm" => "maruhan-shinjuku"
    def extract_shop_slug_from_href(href)
      return nil if href.blank?

      # Extract the filename part: "/tokyo/maruhan-shinjuku.htm" => "maruhan-shinjuku"
      filename = href.split("/").last&.gsub(/\.htm$/, "")
      filename.presence
    end

    # Parse slot rate info from P-WORLD "detail-kashidama" element.
    # Returns { slot_rates: [...], exchange_rate: symbol }
    # Examples:
    #   "1000円/46枚" → 20スロ等価  "1000円/200枚" → 5スロ
    #   "1000円/178枚" → 5.6枚交換   "1000円/92枚" → 10スロ
    #   "1000円/160枚" → 非等価
    def parse_slot_rates(kashidama_el)
      return { slot_rates: [], exchange_rate: :unknown_rate } unless kashidama_el

      slot_spans = kashidama_el.css("span.iconSlot").map { |s| s.text.strip }
      rates = []
      exchange = :unknown_rate

      slot_spans.each do |span|
        if span =~ /(\d+)円\/(\d+)枚/
          yen = $1.to_i
          coins = $2.to_i
          rate_per_coin = yen.to_f / coins

          case coins
          when 46..50
            rates << "20スロ"
            exchange = :equal_rate # 等価 (1000/46 ≒ 21.7円, ほぼ等価)
          when 89..96
            rates << "10スロ"
          when 170..185
            rates << "5スロ"
            exchange = :rate_56 if exchange == :unknown_rate # 5.6枚交換相当
          when 196..210
            rates << "5スロ"
            exchange = :rate_50 if exchange == :unknown_rate # 5.0枚交換
          when 150..169
            rates << "5スロ"
            exchange = :non_equal if exchange == :unknown_rate
          when 370..420
            rates << "2スロ"
          when 900..1100
            rates << "1スロ"
          else
            # Unknown rate, try to classify by per-coin value
            if rate_per_coin >= 18
              rates << "20スロ"
            elsif rate_per_coin >= 8
              rates << "10スロ"
            elsif rate_per_coin >= 4
              rates << "5スロ"
            elsif rate_per_coin >= 1.5
              rates << "2スロ"
            else
              rates << "1スロ"
            end
            exchange = :non_equal if exchange == :unknown_rate
          end
        end
      end

      { slot_rates: rates.uniq, exchange_rate: exchange }
    end

    # Parse service/facility icons from hallDetail.
    # Returns array of facility names.
    ICON_MAP = {
      "wifi" => "Wi-Fi",
      "sp_charge" => "充電器",
      "inner_smoking_room" => "屋内喫煙室",
      "outdoor_smoking_space" => "屋外喫煙",
      "heating_smoking_area" => "加熱式たばこ",
      "prevent_infection" => "感染症対策",
      "self_declare" => "自己申告",
      "disaster_stock" => "災害対応",
      "dedama_icon" => "出玉公開"
    }.freeze

    def parse_facilities(hall)
      hall.css("td.service img").filter_map { |img|
        key = img["src"]&.split("/")&.last&.split(".")&.first
        ICON_MAP[key]
      }.uniq
    end

    # Import shops for a single prefecture.
    # Returns the count of imported/updated shops.
    def import_shops_for_prefecture(prefecture)
      slug = prefecture.slug
      pref_name = PREFECTURE_SEARCH_NAMES[slug]

      unless pref_name
        puts "  WARNING: No P-WORLD search name mapping for slug '#{slug}', skipping."
        return 0
      end

      puts "Importing #{pref_name} (#{slug})..."

      # URL-encode the prefecture name for the search query
      encoded_name = URI.encode_www_form_component(pref_name)

      page = 0
      total_imported = 0
      total_updated = 0
      total_on_pworld = nil

      loop do
        url = "#{BASE_URL}/_machine/alkensaku.cgi?k=#{encoded_name}&is_new_ver=1&page=#{page}"
        doc = fetch_page(url, encoding: "EUC-JP")

        unless doc
          puts "  Failed to fetch page #{page}, stopping pagination."
          break
        end

        # On first page, extract the total count
        if page == 0
          count_text = doc.at_css("meta[name='description']")&.attr("content") || ""
          if count_text =~ /該当(\d+)店舗/
            total_on_pworld = $1.to_i
            puts "  P-WORLD reports #{total_on_pworld} shops for #{pref_name}"
          end
        end

        # Parse shop entries from hallDetail divs
        hall_details = doc.css("div.hallDetail")

        if hall_details.empty?
          puts "  No more shops found on page #{page}."
          break
        end

        hall_details.each do |hall|
          begin
            # Extract shop name and link
            link_el = hall.at_css("a.detail-hallLink")
            next unless link_el

            shop_name = link_el.text.strip
            shop_href = link_el["href"]
            shop_slug = extract_shop_slug_from_href(shop_href)

            next if shop_slug.blank? || shop_name.blank?

            # Extract address
            address_div = hall.at_css("div.detail-address")
            address = nil
            if address_div
              # Get text content, excluding child elements like the "周辺" button
              address_text = address_div.children.select { |c| c.text? }.map(&:text).join.strip
              address = address_text.presence
            end

            # Extract slot rate and exchange rate info
            kashidama = hall.at_css("p.detail-kashidama")
            rate_info = parse_slot_rates(kashidama)

            # Extract facilities
            facilities = parse_facilities(hall)

            # Build P-WORLD URL
            pworld_url = shop_href&.start_with?("http") ? shop_href : "#{BASE_URL}#{shop_href}" if shop_href.present?

            # Create or update the shop
            shop = Shop.find_or_initialize_by(slug: shop_slug)
            shop.name = shop_name
            shop.prefecture = prefecture
            shop.address = address if address.present?
            shop.slot_rates = rate_info[:slot_rates] if rate_info[:slot_rates].any?
            shop.exchange_rate = rate_info[:exchange_rate] if rate_info[:exchange_rate] != :unknown_rate
            shop.notes = facilities.join("、") if facilities.any?
            shop.pworld_url = pworld_url if pworld_url.present?

            if shop.new_record?
              shop.save!
              total_imported += 1
            elsif shop.changed?
              shop.save!
              total_updated += 1
            end
          rescue ActiveRecord::RecordInvalid => e
            puts "  WARNING: Could not save shop '#{shop_name}': #{e.message}"
          rescue StandardError => e
            puts "  WARNING: Error processing shop entry: #{e.message}"
          end
        end

        page += 1
        # Safety check: P-WORLD shows 50 per page
        break if hall_details.size < 50

        sleep(REQUEST_INTERVAL)
      end

      shop_count = prefecture.shops.count
      puts "  Done: #{pref_name} - #{total_imported} new, #{total_updated} updated (#{shop_count} total in DB)"
      total_imported
    end

    # Import machine models from P-WORLD slot type listing pages.
    def import_slot_machines
      puts "Importing slot machine models from P-WORLD..."

      total_imported = 0

      SLOT_TYPE_KEYS.each do |type_key|
        puts "  Fetching type: #{type_key}..."
        offset = 0

        loop do
          url = "#{BASE_URL}/_machine/t_machine.cgi?mode=slot_type&key=#{URI.encode_www_form_component(type_key)}&start=#{offset}"
          doc = fetch_page(url, encoding: "EUC-JP")

          unless doc
            puts "    Failed to fetch page at offset #{offset}, stopping."
            break
          end

          # Find machine rows: each has td.title, td.type, td.maker
          titles = doc.css("td.title")

          if titles.empty?
            break
          end

          titles.each do |title_td|
            begin
              row = title_td.parent
              next unless row

              # Machine name from the link inside td.title
              name_link = title_td.at_css("a[href*='/machine/database/']")
              next unless name_link

              machine_name = name_link.text.strip
              next if machine_name.blank?

              # Machine type from td.type
              type_td = row.at_css("td.type")
              type_text = type_td&.text&.strip || ""

              # Maker from td.maker
              maker_td = row.at_css("td.maker")
              maker_name = maker_td&.text&.strip

              # Generate slug from machine name
              slug = normalize_slug(machine_name)

              # Avoid empty slugs
              next if slug.blank?

              # 機種マスタはDMMぱちタウンが正。P-WORLDではマッチのみ（新規作成しない）
              model = MachineModel.find_by(slug: slug)
              next unless model
              if maker_name.present? && model.maker.blank?
                model.update!(maker: maker_name)
              end
            rescue StandardError => e
              puts "    WARNING: Error processing machine entry: #{e.message}"
            end
          end

          offset += titles.size
          # P-WORLD typically shows 20 machines per page
          break if titles.size < 20

          sleep(REQUEST_INTERVAL)
        end

        sleep(REQUEST_INTERVAL)
      end

      puts "  Done: #{total_imported} new machine models imported (#{MachineModel.count} total in DB)"
      total_imported
    end

    # Scrape the over_6.5number (smart slot) listing from P-WORLD and flag matching machines.
    # Also flags machines with Ｌ prefix or スマスロ keyword.
    # Returns the number of machines flagged.
    def flag_smart_slots
      puts "Flagging smart slot machines from P-WORLD over_6.5number listing..."

      pworld_smart_names = Set.new
      offset = 0

      loop do
        url = "#{BASE_URL}/_machine/t_machine.cgi?mode=slot_type&key=#{URI.encode_www_form_component('over_6.5number')}&start=#{offset}"
        doc = fetch_page(url, encoding: "EUC-JP")

        unless doc
          puts "  Failed to fetch page at offset #{offset}, stopping."
          break
        end

        titles = doc.css("td.title")
        break if titles.empty?

        titles.each do |title_td|
          name_link = title_td.at_css("a[href*='/machine/database/']")
          next unless name_link

          machine_name = name_link.text.strip
          next if machine_name.blank?

          pworld_smart_names << machine_name
        end

        offset += titles.size
        break if titles.size < 20

        sleep(REQUEST_INTERVAL)
      end

      puts "  Found #{pworld_smart_names.size} smart slot names from P-WORLD"

      # Build a slug lookup for matching
      pworld_smart_slugs = pworld_smart_names.map do |name|
        normalize_slug(name)
      end.to_set

      # Flag by P-WORLD slug match
      flagged_by_pworld = 0
      MachineModel.where(is_smart_slot: false).find_each do |m|
        if pworld_smart_slugs.include?(m.slug)
          m.update_column(:is_smart_slot, true)
          flagged_by_pworld += 1
        end
      end
      puts "  Flagged by P-WORLD match: #{flagged_by_pworld}"

      # Flag by name patterns (Ｌ prefix, L prefix, スマスロ keyword)
      flagged_by_name = 0
      MachineModel.where(is_smart_slot: false).find_each do |m|
        if m.name.match?(/\AＬ/) || m.name.match?(/\AL[^a-z]/) || m.name.match?(/スマスロ/)
          m.update_column(:is_smart_slot, true)
          flagged_by_name += 1
        end
      end
      puts "  Flagged by name pattern: #{flagged_by_name}"

      total = MachineModel.where(is_smart_slot: true).count
      puts "  Total smart slot machines: #{total}"
      total
    end

    # Refresh installed machines for a shop (sync: add new, remove stale).
    # Returns { added: N, removed: N }
    # Extract slot machine links from a P-WORLD shop page.
    # Uses data-machine-type="S" sections to reliably distinguish
    # slot machines from pachinko (instead of regex-based filtering).
    def extract_slot_links(doc)
      slot_tables = []
      doc.css("input[data-machine-type='S']").each do |input|
        table = input.ancestors("table").first
        slot_tables << table if table
      end

      if slot_tables.any?
        slot_tables.flat_map { |t| t.css("a[href*='/machine/database/']") }.uniq
      else
        # Fallback: older pages without data-machine-type — use regex filter
        doc.css("a[href*='/machine/database/']").reject do |link|
          MachineModel.pachinko_name?(link.text.strip)
        end
      end
    end

    # Legacy wrappers — delegate to sync_shop_from_pworld
    def refresh_machines_for_shop(shop, cleanup_stale: true)
      r = sync_shop_from_pworld(shop, cleanup_stale: cleanup_stale, update_details: false)
      return { added: 0, removed: 0 } unless r
      { added: r[:machines_added], removed: r[:machines_removed] }
    end

    def import_machines_for_shop(shop)
      r = sync_shop_from_pworld(shop, cleanup_stale: false, update_details: false)
      r ? r[:machines_added] : 0
    end

    def scrape_unit_counts_for_shop(shop)
      r = sync_shop_from_pworld(shop, cleanup_stale: false, update_details: false)
      return nil unless r
      { updated: r[:units_updated], skipped: 0, machines: {} }
    end

    def scrape_shop_details(shop)
      sync_shop_from_pworld(shop, cleanup_stale: false, update_details: true)
    end

    # MD5 hash => digit mapping for P-WORLD number images.
    # The unit counts are rendered as obfuscated GIF images (one per digit).
    # Each digit always produces the same binary content regardless of filename,
    # so we can identify digits by their MD5 hash.
    DIGIT_IMAGE_HASHES = {
      "eea0a8b72a8e48fec333a70d6177fb5f" => "1",
      "8ddd74ece3496cef7ed88f50d1e61fe5" => "0",
      "ffb7b86da3dd3bad52f932d6df62ffed" => "8",
      "f36c62154cc67748ac8add0873ccfe74" => "3",
      "a4a1f76e363b06da2e7ca37f9270e453" => "6",
      "58dc98a1774c8614c399dd1f4e3b97cd" => "2",
      "d96268465d993d7c6de7ebd0d2dc5560" => "7",
      "287c597b517cb3bf4413fc643188a045" => "5",
      "67bb79d533a000dec3fd2707c93f24c7" => "9",
      "2a3601fe5109943f2e14f20b11fa828b" => "4"
    }.freeze

    # MD5 of the "台" suffix image (always appears last, not a digit)
    UNIT_SUFFIX_HASH = "872bb600682e141397e3813492f9c10a"

    # Download a single image and return its binary content.
    # Uses the same retry/timeout logic as fetch_page.
    def fetch_image(url)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 15

      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "image/gif, image/*"

      response = http.request(request)
      response.code.to_i == 200 ? response.body : nil
    rescue StandardError
      nil
    end

    # Decode digit images from a shop page into a hash { image_src => digit_string }.
    # Downloads each unique number image and maps it via MD5 hash.
    # Caches results across shops since P-WORLD uses the same images everywhere.
    # Returns nil if no number images found.
    def build_digit_map(doc)
      img_srcs = Set.new
      doc.css('li[data-machine-type="S"] span img[src*="/number/"]').each do |img|
        img_srcs << img["src"]
      end

      return nil if img_srcs.empty?

      digit_map = {}
      img_srcs.each do |src|
        # Use module-level cache to avoid re-downloading the same images
        if PworldScraper.instance_variable_get(:@digit_image_cache).key?(src)
          digit_map[src] = PworldScraper.instance_variable_get(:@digit_image_cache)[src]
          next
        end

        image_url = "#{BASE_URL}#{src}"
        image_data = fetch_image(image_url)
        next unless image_data

        md5 = Digest::MD5.hexdigest(image_data)

        value = if md5 == UNIT_SUFFIX_HASH
                  :suffix
        elsif DIGIT_IMAGE_HASHES.key?(md5)
                  DIGIT_IMAGE_HASHES[md5]
        else
                  puts "    WARNING: Unknown number image hash #{md5} for #{src}"
                  nil
        end

        digit_map[src] = value
        PworldScraper.instance_variable_get(:@digit_image_cache)[src] = value
      end

      digit_map
    end

    # ── 統合同期メソッド ─────────────────────────────────
    # 1回のHTTPリクエストで店舗ページから全データを取得:
    #   - 設置機種リスト (add/remove)
    #   - 機種別設置台数 (数字画像デコード)
    #   - 店舗詳細 (営業時間/電話/駐車場/レート/設備等)
    #
    # options:
    #   cleanup_stale: true  — 古い機種リンクを削除 (日次更新用)
    #   update_details: true — 店舗詳細を更新 (月次用、日次はfalse)
    def sync_shop_from_pworld(shop, cleanup_stale: true, update_details: false)
      pref_slug = shop.prefecture.slug
      shop_slug = shop.slug
      url = "#{BASE_URL}/#{pref_slug}/#{shop_slug}.htm"

      doc = fetch_page(url, encoding: "EUC-JP")
      return nil unless doc

      result = { machines_added: 0, machines_removed: 0, units_updated: 0, details_updated: false }

      # ── 1. 設置機種リストの同期 ──
      # Collect slugs from page first, then batch-load from DB
      page_machines = []
      extract_slot_links(doc).each do |link|
        machine_name = link.text.strip
        next if machine_name.blank?
        slug = normalize_slug(machine_name)
        next if slug.blank?
        page_machines << { name: machine_name, slug: slug }
      end

      current_slugs = page_machines.map { |m| m[:slug] }.to_set

      # Batch-load existing machines and associations (avoid N+1)
      existing_machines = MachineModel.where(slug: current_slugs.to_a).index_by(&:slug)
      existing_smms = shop.shop_machine_models.includes(:machine_model).index_by { |smm| smm.machine_model.slug }

      page_machines.each do |pm|
        slug = pm[:slug]
        machine = existing_machines[slug]

        # 機種マスタはDMMぱちタウンが正。P-WORLDでは新規作成せずマッチのみ
        next if machine.nil?

        machine.update!(active: true) unless machine.active?

        unless existing_smms.key?(slug)
          ShopMachineModel.create!(shop: shop, machine_model: machine)
          result[:machines_added] += 1
        end
      rescue ActiveRecord::RecordInvalid
        # Skip duplicates
      end

      if cleanup_stale
        stale_ids = existing_smms.reject { |slug, _| current_slugs.include?(slug) }.values.map(&:id)
        if stale_ids.any?
          result[:machines_removed] = stale_ids.size
          ShopMachineModel.where(id: stale_ids).delete_all
        end
      end

      # ── 2. 設置台数の更新 ──
      slot_items = doc.css('li[data-machine-type="S"]')
      if slot_items.any?
        digit_map = build_digit_map(doc)
        if digit_map
          unit_updates = {}

          slot_items.each do |li|
            name_el = li.at_css("._pw-machine-item-machineName a")
            next unless name_el

            machine_name = name_el.text.strip
            next if machine_name.blank?
            next if MachineModel.pachinko_name?(machine_name)

            imgs = li.css('span img[src*="/number/"]')
            digits = []
            imgs.each do |img|
              src = img["src"]
              mapped = digit_map[src]
              next if mapped == :suffix || mapped.nil?
              digits << mapped
            end
            next if digits.empty?

            unit_count = digits.join.to_i
            next if unit_count == 0

            slug = normalize_slug(machine_name)
            next if slug.blank?

            # Reuse batch-loaded data from section 1
            smm = existing_smms[slug]
            if smm
              unit_updates[smm.id] = unit_count
            end
          end

          # Batch update unit counts
          unit_updates.each do |smm_id, count|
            ShopMachineModel.where(id: smm_id).update_all(unit_count: count)
          end
          result[:units_updated] = unit_updates.size
        end
      end

      # ── 3. 店舗詳細の更新 (月次のみ) ──
      if update_details
        page_text = doc.text
        updated = false

        # 台数
        if page_text =~ /パチンコ[　\s]*(\d+)台/
          pachinko_count = $1.to_i
        end
        if page_text =~ /スロット[　\s]*(\d+)台/
          slot_machines = $1.to_i
          if shop.slot_machines != slot_machines
            shop.slot_machines = slot_machines
            updated = true
          end
          total = (pachinko_count || 0) + slot_machines
          if shop.total_machines != total
            shop.total_machines = total
            updated = true
          end
        end

        # レート
        slot_rate_matches = page_text.scan(/\[(\d+)円\/(\d+)枚\]/)
        if slot_rate_matches.any?
          rates = []
          exchange = nil
          slot_rate_matches.each do |yen_s, coins_s|
            coins = coins_s.to_i
            rate_per_coin = yen_s.to_i.to_f / coins
            case coins
            when 46..50  then rates << "20スロ"; exchange ||= :equal_rate
            when 89..96  then rates << "10スロ"
            when 170..185 then rates << "5スロ"; exchange ||= :rate_56
            when 196..210 then rates << "5スロ"; exchange ||= :rate_50
            when 150..169 then rates << "5スロ"; exchange ||= :non_equal
            when 370..420 then rates << "2スロ"
            when 900..1100 then rates << "1スロ"
            else
              if rate_per_coin >= 18 then rates << "20スロ"
              elsif rate_per_coin >= 8 then rates << "10スロ"
              elsif rate_per_coin >= 4 then rates << "5スロ"
              elsif rate_per_coin >= 1.5 then rates << "2スロ"
              else rates << "1スロ"
              end
              exchange ||= :non_equal
            end
          end
          if rates.any? && (shop.slot_rates.blank? || shop.slot_rates.empty?)
            shop.slot_rates = rates.uniq
            updated = true
          end
          if exchange && shop.exchange_rate == "unknown_rate"
            shop.exchange_rate = exchange
            updated = true
          end
        end

        # テーブル情報
        doc.css('td[bgcolor="#6699FF"]').each do |label_td|
          label = label_td.text.gsub(/[\s　]+/, "").strip
          value_td = label_td.next_element
          next unless value_td
          value = value_td.text.gsub(/[　\s]+/, " ").strip

          case label
          when "営業時間"
            if value.present? && shop.business_hours != value
              shop.business_hours = value; updated = true
            end
          when "電話"
            if value.present? && shop.phone_number != value
              shop.phone_number = value; updated = true
            end
          when "駐車場"
            if (m = value.match(/(\d[\d,]+)\s*台/))
              spaces = m[1].delete(",").to_i
              if shop.parking_spaces != spaces
                shop.parking_spaces = spaces; updated = true
              end
            end
          when "朝の入場"
            if value.present? && shop.morning_entry != value
              shop.morning_entry = value; updated = true
            end
          when "交通"
            if value.present? && value != "【店舗地図】" && shop.access_info != value
              shop.access_info = value; updated = true
            end
          when "特徴"
            if value.present? && shop.features != value
              shop.features = value; updated = true
            end
          end
        end

        # 設備
        facilities = []
        facilities << "Wi-Fi" if page_text.include?("Wi-Fi")
        facilities << "充電器" if page_text.include?("充電器") || page_text.include?("携帯充電")
        facilities << "屋内喫煙室" if page_text.include?("屋内喫煙室")
        if page_text.include?("加熱式たばこプレイエリア")
          facilities << "加熱式たばこ遊技OK"
        elsif page_text.include?("加熱式たばこ")
          facilities << "加熱式たばこ喫煙室"
        end
        facilities << "出玉公開" if page_text.include?("出玉公開") || page_text.include?("出玉情報")
        if facilities.any?
          notes = facilities.join("、")
          if shop.notes != notes
            shop.notes = notes; updated = true
          end
        end

        shop.pworld_url = url if shop.pworld_url != url

        shop.save! if updated
        result[:details_updated] = updated
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      puts "  WARNING: sync_shop_from_pworld failed for '#{shop.name}': #{e.message}"
      nil
    end

    # Import new/upcoming machines from the schedule page.
    def import_new_machines_from_schedule
      puts "Importing new machine models from P-WORLD schedule..."

      url = "#{BASE_URL}/database/machine/introduce_calendar.cgi"
      doc = fetch_page(url)

      unless doc
        puts "  ERROR: Failed to fetch schedule page."
        return 0
      end

      total_imported = 0

      # Each machine is in a machineList-item
      doc.css("li.machineList-item").each do |item|
        begin
          # Machine name
          title_el = item.at_css("p.machineList-item-title a")
          next unless title_el

          machine_name = title_el.text.strip
          next if machine_name.blank?

          # Machine type (パチンコ or パチスロ)
          type_el = item.at_css("p.machineList-item-type")
          type_text = type_el&.text&.strip || ""

          # Maker
          maker_el = item.at_css("p.machineList-item-maker a")
          maker_name = maker_el&.text&.strip

          # Spec info from memo
          memo_el = item.at_css("p.machineList-item-memo")
          memo_text = memo_el&.text&.strip || ""

          # Generate slug
          slug = normalize_slug(machine_name)

          next if slug.blank?

          # 機種マスタはDMMぱちタウンが正。P-WORLDではマッチのみ（新規作成しない）
          model = MachineModel.find_by(slug: slug)
          next unless model
          if maker_name.present? && model.maker.blank?
            model.update!(maker: maker_name)
          end
        rescue StandardError => e
          puts "  WARNING: Error processing machine: #{e.message}"
        end
      end

      puts "  Done: #{total_imported} new machine models imported from schedule"
      total_imported
    end

    # NOTE: pworld_machine_id / fetch_machine_ids / scrape_machine_detail removed.
    # Machine detail data (type_detail, generation, ceiling/reset) is now sourced from DMMぱちタウン (ptown.rake).
  end
end

namespace :pworld do
  desc "Import shops from P-WORLD (all 47 prefectures)"
  task import_shops: :environment do
    puts "=" * 60
    puts "P-WORLD Shop Import - All Prefectures"
    puts "=" * 60

    start_time = Time.current
    total_new = 0
    errors = []

    Prefecture.order(:id).each do |prefecture|
      begin
        count = PworldScraper.import_shops_for_prefecture(prefecture)
        total_new += count
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { prefecture: prefecture.name, error: e.message }
        puts "  ERROR for #{prefecture.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "Import complete in #{elapsed}s"
    puts "  Total new shops: #{total_new}"
    puts "  Total shops in DB: #{Shop.count}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:prefecture]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Import shops from P-WORLD (single prefecture by slug, e.g. rake pworld:import_prefecture[tokyo])"
  task :import_prefecture, [ :slug ] => :environment do |_t, args|
    slug = args[:slug]

    unless slug.present?
      puts "ERROR: Please provide a prefecture slug."
      puts "Usage: rake pworld:import_prefecture[tokyo]"
      exit 1
    end

    prefecture = Prefecture.find_by(slug: slug)

    unless prefecture
      puts "ERROR: Prefecture with slug '#{slug}' not found."
      puts "Available: #{Prefecture.pluck(:slug).join(', ')}"
      exit 1
    end

    puts "=" * 60
    puts "P-WORLD Shop Import - #{prefecture.name}"
    puts "=" * 60

    start_time = Time.current
    count = PworldScraper.import_shops_for_prefecture(prefecture)
    elapsed = (Time.current - start_time).round(1)

    puts ""
    puts "=" * 60
    puts "Import complete in #{elapsed}s"
    puts "  New shops imported: #{count}"
    puts "  Total shops for #{prefecture.name}: #{prefecture.shops.count}"
    puts "=" * 60
  end

  desc "Import installed machines for all shops (links machines to shops via ShopMachineModel)"
  task import_shop_machines: :environment do
    puts "=" * 60
    puts "P-WORLD Shop Machine Import"
    puts "=" * 60

    start_time = Time.current
    total_linked = 0
    total_shops = Shop.count
    errors = []

    Shop.includes(:prefecture).find_each.with_index do |shop, index|
      begin
        count = PworldScraper.import_machines_for_shop(shop)
        total_linked += count
        puts "  [#{index + 1}/#{total_shops}] #{shop.name}: #{count} new machines linked" if count > 0
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "Shop machine import complete in #{elapsed}s"
    puts "  Total new links: #{total_linked}"
    puts "  Total shop-machine links in DB: #{ShopMachineModel.count}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Import installed machines for shops in a prefecture (by slug, e.g. rake pworld:import_shop_machines_by_pref[fukuoka])"
  task :import_shop_machines_by_pref, [ :slug ] => :environment do |_t, args|
    slug = args[:slug]

    unless slug.present?
      puts "Usage: rake pworld:import_shop_machines_by_pref[fukuoka]"
      exit 1
    end

    prefecture = Prefecture.find_by(slug: slug)
    unless prefecture
      puts "ERROR: Prefecture '#{slug}' not found."
      exit 1
    end

    shops = prefecture.shops.order(:id)
    total_shops = shops.count

    puts "=" * 60
    puts "P-WORLD Shop Machine Import - #{prefecture.name} (#{total_shops} shops)"
    puts "=" * 60

    start_time = Time.current
    total_linked = 0
    errors = []

    shops.each_with_index do |shop, index|
      begin
        count = PworldScraper.import_machines_for_shop(shop)
        total_linked += count
        puts "  [#{index + 1}/#{total_shops}] #{shop.name}: #{count} new machines linked" if count > 0
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "#{prefecture.name} import complete in #{elapsed}s"
    puts "  Total new links: #{total_linked}"
    puts "  Total shop-machine links for #{prefecture.name}: #{ShopMachineModel.joins(:shop).where(shops: { prefecture_id: prefecture.id }).count}"
    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end
    puts "=" * 60
  end

  desc "Import installed machines for a single shop (by slug)"
  task :import_shop_machines_for, [ :slug ] => :environment do |_t, args|
    slug = args[:slug]

    unless slug.present?
      puts "Usage: rake pworld:import_shop_machines_for[shop-slug]"
      exit 1
    end

    shop = Shop.includes(:prefecture).find_by(slug: slug)
    unless shop
      puts "ERROR: Shop '#{slug}' not found."
      exit 1
    end

    count = PworldScraper.import_machines_for_shop(shop)
    puts "#{shop.name}: #{count} new machines linked (#{shop.machine_models.count} total)"
  end

  desc "Weekly refresh: sync shop-machine links for all shops (add new, remove stale)"
  task refresh_shop_machines: :environment do
    puts "=" * 60
    puts "P-WORLD Weekly Refresh - Shop Machine Links"
    puts "=" * 60

    start_time = Time.current
    total_added = 0
    total_removed = 0
    total_shops = Shop.count
    errors = []

    Shop.includes(:prefecture).find_each.with_index do |shop, index|
      begin
        result = PworldScraper.refresh_machines_for_shop(shop)
        total_added += result[:added]
        total_removed += result[:removed]
        if result[:added] > 0 || result[:removed] > 0
          puts "  [#{index + 1}/#{total_shops}] #{shop.name}: +#{result[:added]} -#{result[:removed]}"
        end
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "Refresh complete in #{elapsed}s"
    puts "  Added: #{total_added}, Removed: #{total_removed}"
    puts "  Total shop-machine links: #{ShopMachineModel.count}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Weekly refresh: sync shop-machine links for a prefecture (e.g. rake pworld:refresh_by_pref[tokyo])"
  task :refresh_by_pref, [ :slug ] => :environment do |_t, args|
    slug = args[:slug]

    unless slug.present?
      puts "Usage: rake pworld:refresh_by_pref[tokyo]"
      exit 1
    end

    prefecture = Prefecture.find_by(slug: slug)
    unless prefecture
      puts "ERROR: Prefecture '#{slug}' not found."
      exit 1
    end

    shops = prefecture.shops.includes(:prefecture).order(:id)
    total_shops = shops.count

    puts "=" * 60
    puts "P-WORLD Weekly Refresh - #{prefecture.name} (#{total_shops} shops)"
    puts "=" * 60

    start_time = Time.current
    total_added = 0
    total_removed = 0
    errors = []

    shops.each_with_index do |shop, index|
      begin
        result = PworldScraper.refresh_machines_for_shop(shop)
        total_added += result[:added]
        total_removed += result[:removed]
        if result[:added] > 0 || result[:removed] > 0
          puts "  [#{index + 1}/#{total_shops}] #{shop.name}: +#{result[:added]} -#{result[:removed]}"
        end
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "#{prefecture.name} refresh complete in #{elapsed}s"
    puts "  Added: #{total_added}, Removed: #{total_removed}"
    puts "  Total links for #{prefecture.name}: #{ShopMachineModel.joins(:shop).where(shops: { prefecture_id: prefecture.id }).count}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Deactivate machines with no shop links (cleanup after refresh)"
  task cleanup_orphan_machines: :environment do
    orphans = MachineModel.active
      .left_joins(:shop_machine_models)
      .group("machine_models.id")
      .having("COUNT(shop_machine_models.id) = 0")

    count = orphans.count.size
    if count > 0
      orphan_ids = orphans.pluck(:id)
      MachineModel.where(id: orphan_ids).update_all(active: false)
      puts "Deactivated #{count} orphan machines (no shop links)"
    else
      puts "No orphan machines found"
    end
  end

  desc "Scrape shop details (machine counts, business hours, pworld_url) for all shops"
  task scrape_shop_details: :environment do
    $stdout.sync = true
    puts "=" * 60
    puts "P-WORLD Shop Details Scrape - All Shops"
    puts "=" * 60

    start_time = Time.current
    total_shops = Shop.count
    total_updated = 0
    total_skipped = 0
    errors = []

    Shop.includes(:prefecture).find_each.with_index do |shop, index|
      begin
        data = PworldScraper.scrape_shop_details(shop)
        if data
          has_data = data.keys.any? { |k| k != :pworld_url && data[k].present? }
          if has_data
            total_updated += 1
            parts = []
            parts << "slot:#{data[:slot_machines]}" if data[:slot_machines]
            parts << data[:business_hours] if data[:business_hours]
            parts << "P:#{data[:parking_spaces]}台" if data[:parking_spaces]
            parts << "朝:#{data[:morning_entry].to_s[0..20]}" if data[:morning_entry]
            puts "  [#{index + 1}/#{total_shops}] #{shop.name}: #{parts.join(' | ')}"
          else
            total_skipped += 1
            puts "  [#{index + 1}/#{total_shops}] #{shop.name}: (no data)"
          end
        else
          total_skipped += 1
          puts "  [#{index + 1}/#{total_shops}] #{shop.name}: (fetch failed)"
        end
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    puts ""
    puts "=" * 60
    puts "Shop details scrape complete in #{elapsed}s"
    puts "  Updated: #{total_updated}, Skipped: #{total_skipped}"
    puts "  Shops with slot_machines: #{Shop.where.not(slot_machines: nil).count}"
    puts "  Shops with business_hours: #{Shop.where.not(business_hours: [ nil, '' ]).count}"
    puts "  Shops with parking_spaces: #{Shop.where.not(parking_spaces: nil).count}"
    puts "  Shops with morning_entry: #{Shop.where.not(morning_entry: [ nil, '' ]).count}"
    puts "  Shops with phone_number: #{Shop.where.not(phone_number: [ nil, '' ]).count}"
    puts "  Shops with pworld_url: #{Shop.where.not(pworld_url: [ nil, '' ]).count}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Scrape shop details for a prefecture (e.g. rake pworld:scrape_shop_details_by_pref[tokyo])"
  task :scrape_shop_details_by_pref, [ :slug ] => :environment do |_t, args|
    slug = args[:slug]

    unless slug.present?
      puts "Usage: rake pworld:scrape_shop_details_by_pref[tokyo]"
      exit 1
    end

    prefecture = Prefecture.find_by(slug: slug)
    unless prefecture
      puts "ERROR: Prefecture '#{slug}' not found."
      puts "Available: #{Prefecture.pluck(:slug).join(', ')}"
      exit 1
    end

    shops = prefecture.shops.order(:id)
    total_shops = shops.count

    puts "=" * 60
    puts "P-WORLD Shop Details Scrape - #{prefecture.name} (#{total_shops} shops)"
    puts "=" * 60

    start_time = Time.current
    total_updated = 0
    total_skipped = 0
    errors = []

    shops.each_with_index do |shop, index|
      begin
        data = PworldScraper.scrape_shop_details(shop)
        if data
          has_data = data[:slot_machines] || data[:business_hours]
          if has_data
            total_updated += 1
            slots = data[:slot_machines] ? "slot:#{data[:slot_machines]}" : "-"
            total = data[:total_machines] ? "total:#{data[:total_machines]}" : "-"
            hours = data[:business_hours] || "-"
            puts "  [#{index + 1}/#{total_shops}] #{shop.name}: #{slots} #{total} #{hours}"
          else
            total_skipped += 1
          end
        else
          total_skipped += 1
        end
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    pref_shops = prefecture.shops
    puts ""
    puts "=" * 60
    puts "#{prefecture.name} shop details scrape complete in #{elapsed}s"
    puts "  Updated: #{total_updated}, Skipped: #{total_skipped}"
    puts "  Shops with slot_machines: #{pref_shops.where.not(slot_machines: nil).count}/#{total_shops}"
    puts "  Shops with business_hours: #{pref_shops.where.not(business_hours: [ nil, '' ]).count}/#{total_shops}"
    puts "  Shops with pworld_url: #{pref_shops.where.not(pworld_url: [ nil, '' ]).count}/#{total_shops}"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Import slot machine models from P-WORLD type listings"
  task import_machines: :environment do
    puts "=" * 60
    puts "P-WORLD Machine Model Import"
    puts "=" * 60

    start_time = Time.current

    # Import from slot type listings
    PworldScraper.import_slot_machines

    # Also import from the new machine schedule
    sleep(PworldScraper::REQUEST_INTERVAL)
    PworldScraper.import_new_machines_from_schedule

    elapsed = (Time.current - start_time).round(1)

    puts ""
    puts "=" * 60
    puts "Machine import complete in #{elapsed}s"
    puts "  Total machine models in DB: #{MachineModel.count}"
    puts "=" * 60
  end

  desc "Flag smart slot machines using P-WORLD over_6.5number listing + name patterns"
  task flag_smart_slots: :environment do
    $stdout.sync = true
    puts "=" * 60
    puts "P-WORLD Smart Slot Flagging"
    puts "=" * 60

    before_count = MachineModel.where(is_smart_slot: true).count
    puts "Before: #{before_count} smart slots flagged"
    puts ""

    PworldScraper.flag_smart_slots

    after_count = MachineModel.where(is_smart_slot: true).count
    puts ""
    puts "After: #{after_count} smart slots flagged (+#{after_count - before_count} new)"

    # Show display_type distribution
    puts ""
    puts "=== Display type distribution (active only) ==="
    MachineModel.active.find_each.group_by(&:display_type).sort_by { |k, _| MachineModel::DISPLAY_TYPES[k][:sort] }.each do |type, machines|
      puts "  #{MachineModel::DISPLAY_TYPES[type][:label]}: #{machines.size}"
    end
    puts "  合計: #{MachineModel.active.count}"
    puts "=" * 60
  end

  # NOTE: fetch_machine_ids / scrape_machine_details tasks removed.
  # Machine detail data is now sourced from DMMぱちタウン (ptown:import_details).

  # ── 定期更新バッチ ─────────────────────────────────────
  desc "Weekly update: refresh machine links for all shops (run every Sunday)"
  task weekly_refresh: :environment do
    $stdout.sync = true
    require_relative "../batch_logger"

    BatchLogger.with_logging("weekly_refresh") do |blog|
      machines_before = MachineModel.active.count
      links_before = ShopMachineModel.count

      # 1. 新台チェック
      blog.info "[Step 1/3] Checking for new machines..."
      begin
        PworldScraper.import_new_machines_from_schedule
      rescue => e
        blog.error "New machine import failed: #{e.message}"
      end
      new_machines = MachineModel.active.count - machines_before
      blog.info "  New machines added: #{new_machines}"

      # 2. 全店舗の設置機種リスト更新 (各県順番に)
      blog.info "[Step 2/3] Refreshing shop-machine links..."
      total_added = 0
      total_removed = 0
      shop_errors = 0
      Prefecture.order(:id).each do |pref|
        shops = pref.shops.where.not(pworld_url: [ nil, "" ])
        next if shops.empty?

        blog.info "  #{pref.name} (#{shops.count}店)..."
        shops.find_each do |shop|
          begin
            result = PworldScraper.refresh_machines_for_shop(shop)
            if result
              total_added += result[:added]
              total_removed += result[:removed]
            end
          rescue => e
            shop_errors += 1
            blog.error "Shop #{shop.name} (#{shop.id}) failed: #{e.message}" if shop_errors <= 20
          end
          sleep(PworldScraper::REQUEST_INTERVAL)
        end
      end
      blog.info "  Links added: #{total_added}, removed: #{total_removed}"

      # 3. 孤立機種のクリーンアップ
      blog.info "[Step 3/3] Cleaning up orphan machines..."
      orphans = MachineModel.active
        .left_joins(:shop_machine_models)
        .where(shop_machine_models: { id: nil })
      orphan_count = orphans.count
      if orphan_count > 0
        orphans.update_all(active: false)
        blog.info "  Deactivated #{orphan_count} orphan machines"
      else
        blog.info "  No orphans found"
      end

      blog.summary(
        new_machines: new_machines,
        links_added: total_added,
        links_removed: total_removed,
        orphans_deactivated: orphan_count,
        shop_errors: shop_errors,
        active_machines: MachineModel.active.count,
        total_links: ShopMachineModel.count
      )
    end
  end

  desc "Update unit counts for all shops (scrapes P-WORLD number images)"
  task update_unit_counts: :environment do
    $stdout.sync = true

    puts "=" * 60
    puts "P-WORLD Unit Count Update - All Shops"
    puts "=" * 60

    start_time = Time.current
    total_updated = 0
    total_skipped = 0
    total_shops = Shop.where.not(pworld_url: [ nil, "" ]).count
    errors = []
    processed = 0

    Shop.includes(:prefecture).where.not(pworld_url: [ nil, "" ]).find_each do |shop|
      processed += 1
      begin
        result = PworldScraper.scrape_unit_counts_for_shop(shop)
        if result
          total_updated += result[:updated]
          total_skipped += result[:skipped]
          if result[:updated] > 0
            puts "  [#{processed}/#{total_shops}] #{shop.name}: #{result[:updated]} machines updated"
          end
        else
          puts "  [#{processed}/#{total_shops}] #{shop.name}: SKIP (page not found)"
        end
        # Rate limit: page fetch (2.5s) + digit image downloads (~10 images * minimal time)
        # The page fetch already sleeps via fetch_page, but add interval for safety
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    with_count = ShopMachineModel.where.not(unit_count: [ nil, 0 ]).count
    total_links = ShopMachineModel.count

    puts ""
    puts "=" * 60
    puts "Unit count update complete in #{elapsed}s"
    puts "  Updated: #{total_updated} machines across #{processed} shops"
    puts "  Skipped (no ShopMachineModel): #{total_skipped}"
    puts "  Coverage: #{with_count}/#{total_links} (#{(with_count * 100.0 / total_links).round(1)}%)"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.first(20).each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
      puts "    ... and #{errors.size - 20} more" if errors.size > 20
    end

    puts "=" * 60
  end

  desc "Update unit counts for a prefecture (e.g. rake pworld:update_unit_counts_by_pref[tokyo])"
  task :update_unit_counts_by_pref, [ :slug ] => :environment do |_t, args|
    $stdout.sync = true
    slug = args[:slug]

    unless slug.present?
      puts "Usage: rake pworld:update_unit_counts_by_pref[tokyo]"
      exit 1
    end

    prefecture = Prefecture.find_by(slug: slug)
    unless prefecture
      puts "ERROR: Prefecture '#{slug}' not found."
      exit 1
    end

    shops = prefecture.shops.where.not(pworld_url: [ nil, "" ]).order(:id)
    total_shops = shops.count

    puts "=" * 60
    puts "P-WORLD Unit Count Update - #{prefecture.name} (#{total_shops} shops)"
    puts "=" * 60

    start_time = Time.current
    total_updated = 0
    total_skipped = 0
    errors = []

    shops.each_with_index do |shop, index|
      begin
        result = PworldScraper.scrape_unit_counts_for_shop(shop)
        if result
          total_updated += result[:updated]
          total_skipped += result[:skipped]
          if result[:updated] > 0
            puts "  [#{index + 1}/#{total_shops}] #{shop.name}: #{result[:updated]} machines updated"
          end
        else
          puts "  [#{index + 1}/#{total_shops}] #{shop.name}: SKIP (page not found)"
        end
        sleep(PworldScraper::REQUEST_INTERVAL)
      rescue StandardError => e
        errors << { shop: shop.name, error: e.message }
        puts "  ERROR for #{shop.name}: #{e.message}"
      end
    end

    elapsed = (Time.current - start_time).round(1)
    pref_links = ShopMachineModel.joins(:shop).where(shops: { prefecture_id: prefecture.id })
    with_count = pref_links.where.not(unit_count: [ nil, 0 ]).count
    total_links = pref_links.count

    puts ""
    puts "=" * 60
    puts "#{prefecture.name} unit count update complete in #{elapsed}s"
    puts "  Updated: #{total_updated} machines across #{total_shops} shops"
    puts "  Skipped (no ShopMachineModel): #{total_skipped}"
    puts "  Coverage: #{with_count}/#{total_links} (#{total_links > 0 ? (with_count * 100.0 / total_links).round(1) : 0}%)"

    if errors.any?
      puts "  Errors (#{errors.size}):"
      errors.first(20).each { |e| puts "    - #{e[:shop]}: #{e[:error]}" }
    end

    puts "=" * 60
  end

  desc "Monthly update: refresh shop details from P-WORLD (営業時間, 駐車場, 設備等)"
  task monthly_refresh: :environment do
    $stdout.sync = true
    require_relative "../batch_logger"

    BatchLogger.with_logging("monthly_refresh") do |blog|
      shops_before = Shop.where.not(business_hours: [ nil, "" ]).count

      blog.info "Refreshing shop details for all shops..."
      Rake::Task["pworld:scrape_shop_details"].invoke

      shops_after = Shop.where.not(business_hours: [ nil, "" ]).count
      total_shops = Shop.count
      rate_coverage = Shop.where.not(slot_rates: [ nil, [], [ "" ] ]).count
      parking_coverage = Shop.where.not(parking_spaces: [ nil, "" ]).count

      blog.summary(
        total_shops: total_shops,
        shops_with_hours_before: shops_before,
        shops_with_hours_after: shops_after,
        rate_coverage: "#{(rate_coverage * 100.0 / total_shops).round(1)}% (#{rate_coverage}/#{total_shops})",
        parking_coverage: "#{(parking_coverage * 100.0 / total_shops).round(1)}% (#{parking_coverage}/#{total_shops})"
      )
    end
  end
end
