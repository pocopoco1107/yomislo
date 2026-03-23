# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "uri"

# P-WORLD supplement module for filling machine data gaps in shops
# where DMMぱちタウン does not list installed machines.
#
# Only creates ShopMachineModel links — never creates new Shop or MachineModel records.

module PworldSupplement
  BASE_URL = "https://www.p-world.co.jp"
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  REQUEST_INTERVAL = 3.0
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
            location = response["location"]
            uri = location.start_with?("http") ? URI.parse(location) : URI.parse("#{BASE_URL}#{location}")
            next
          when Net::HTTPSuccess
            # P-WORLD uses EUC-JP encoding — convert to UTF-8 with replacement
            body = response.body.encode("UTF-8", "EUC-JP", invalid: :replace, undef: :replace, replace: "?")
            return Nokogiri::HTML(body)
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

    # Search P-WORLD for shops by name (UTF-8 encoded query)
    def search_shops(name)
      encoded = URI.encode_www_form_component(name)
      url = "#{BASE_URL}/_machine/alkensaku.cgi?k=#{encoded}&is_new_ver=1&page=0"
      doc = fetch_page(url)
      return [] unless doc

      doc.css(".hallDetail").map { |hall|
        link = hall.at_css("a.detail-hallLink")
        next unless link

        addr_el = hall.at_css(".detail-address")
        address = addr_el&.children&.first&.text&.strip

        {
          name: link.text.strip,
          href: link["href"],
          address: address
        }
      }.compact
    end

    # Parse shop detail page for phone, address, and slot machine list
    def parse_shop_detail(doc)
      phone = nil
      address = nil

      doc.css("td").each do |td|
        label = td.text.strip.gsub(/\s+/, "")
        next_td = td.parent&.css("td")&.[](1)
        next unless next_td

        case label
        when "電話"
          phone = next_td.text.strip
        when "住所"
          address = next_td.text.strip
        end
      end

      # Extract slot machines from li._pw-machine-item-slot
      machines = doc.css("li._pw-machine-item-slot").filter_map { |li|
        raw_name = li["data-machine-name"]
        next if raw_name.nil? || raw_name.strip.empty?
        { raw_names: raw_name.split("/").map(&:strip).reject(&:empty?) }
      }.uniq { |m| m[:raw_names].first }

      { phone: phone, address: address, machines: machines }
    end

    # Normalize address for comparison
    def normalize_address(addr)
      return "" if addr.nil?
      addr
        .unicode_normalize(:nfkc)
        .gsub(/[[:space:]]+/, "")
        .gsub(/[ー－‐―−–—]/, "-")
        .gsub(/丁目|番地|番|号/, "-")
        .gsub(/-+/, "-")
        .gsub(/-\z/, "")
    end

    # Normalize phone for comparison (digits only)
    def normalize_phone(phone)
      return "" if phone.nil?
      phone.unicode_normalize(:nfkc).gsub(/[^\d]/, "")
    end

    # Extract prefecture from address string
    def extract_prefecture(address)
      return nil if address.nil?
      m = address.match(/\A(.{2,3}[都道府県])/)
      m&.[](1)
    end

    # Match a P-WORLD search result to a DB shop
    def match_shop(pworld_result, db_shop)
      # Level 1: phone match
      if db_shop.phone_number.present? && pworld_result[:detail_phone].present?
        if normalize_phone(db_shop.phone_number) == normalize_phone(pworld_result[:detail_phone])
          return { confidence: :high, method: :phone }
        end
      end

      # Level 2: exact normalized address match
      db_addr = normalize_address(db_shop.address)
      pw_addr = normalize_address(pworld_result[:detail_address] || pworld_result[:address])
      if db_addr.present? && pw_addr.present? && db_addr == pw_addr
        return { confidence: :high, method: :address_exact }
      end

      # Level 3: address prefix match (ignore building name differences)
      if db_addr.present? && pw_addr.present?
        # Compare first 15 chars (typically up to street number)
        prefix_len = [ db_addr.length, pw_addr.length, 15 ].min
        if prefix_len >= 8 && db_addr[0...prefix_len] == pw_addr[0...prefix_len]
          return { confidence: :medium, method: :address_prefix }
        end
      end

      nil
    end
  end
end

namespace :pworld_supplement do
  desc "P-WORLDから設置機種0件店舗の機種データを補完（都道府県指定可、DRY_RUN=1で確認）"
  task :sync, [ :pref_slug ] => :environment do |_t, args|
    $stdout.sync = true
    pref_slug = args[:pref_slug]
    dry_run = ENV["DRY_RUN"] == "1"

    puts "=== P-WORLD 設置機種補完 #{dry_run ? "(DRY RUN)" : ""} ==="

    # Build core_name lookup for existing machines
    core_name_lookup = {}
    MachineModel.where(active: true).where.not(ptown_id: nil).find_each do |m|
      cn = PtownScraper.core_name(m.name)
      core_name_lookup[cn] = m if cn.present?
    end
    puts "機種ルックアップ: #{core_name_lookup.size}件"

    # Get target shops (0 machine links, with ptown_shop_id)
    prefectures = if pref_slug.present?
                    Prefecture.where(slug: pref_slug)
                  else
                    Prefecture.order(:id)
                  end

    target_shop_ids = Shop.where.not(ptown_shop_id: nil)
      .where.not(last_synced_at: nil)
      .left_joins(:shop_machine_models)
      .group("shops.id")
      .having("count(shop_machine_models.id) = 0")
      .pluck(:id)

    target_shops = Shop.where(id: target_shop_ids)
      .where(prefecture: prefectures)
      .includes(:prefecture)
      .order(:prefecture_id, :name)

    total = target_shops.count
    puts "対象店舗: #{total}件\n\n"

    # Skip shops that already have pworld-sourced links
    already_done_ids = ShopMachineModel.where(data_source: "pworld").distinct.pluck(:shop_id).to_set

    total_matched = 0
    total_not_found = 0
    total_machines_added = 0
    total_machines_skipped = 0

    target_shops.find_each.with_index do |shop, i|
      if already_done_ids.include?(shop.id)
        print "\r  #{i + 1}/#{total} #{shop.name}: スキップ (補完済み)"
        next
      end

      # Search P-WORLD by shop name
      results = PworldSupplement.search_shops(shop.name)
      sleep PworldSupplement::REQUEST_INTERVAL

      if results.empty?
        total_not_found += 1
        print "\r  #{i + 1}/#{total} #{shop.name}: P-WORLD検索 0件"
        next
      end

      # Filter by prefecture
      pref_name = shop.prefecture.name
      candidates = results.select { |r|
        PworldSupplement.extract_prefecture(r[:address]) == pref_name
      }

      if candidates.empty?
        total_not_found += 1
        print "\r  #{i + 1}/#{total} #{shop.name}: 県内候補なし"
        next
      end

      # Try to match — fetch detail page for each candidate
      matched = nil
      match_info = nil

      candidates.each do |candidate|
        detail_url = "#{PworldSupplement::BASE_URL}#{candidate[:href]}"
        doc = PworldSupplement.fetch_page(detail_url)
        sleep PworldSupplement::REQUEST_INTERVAL
        next unless doc

        detail = PworldSupplement.parse_shop_detail(doc)
        candidate[:detail_phone] = detail[:phone]
        candidate[:detail_address] = detail[:address]
        candidate[:machines] = detail[:machines]

        result = PworldSupplement.match_shop(candidate, shop)
        if result
          matched = candidate
          match_info = result
          break
        end
      end

      unless matched
        total_not_found += 1
        print "\r  #{i + 1}/#{total} #{shop.name}: マッチなし (候補#{candidates.size}件)"
        next
      end

      total_matched += 1

      # Match machines to existing DB records
      shop_added = 0
      shop_skipped = 0

      matched[:machines].each do |m_data|
        # Try each candidate name until one matches
        machine = nil
        m_data[:raw_names].each do |raw_name|
          cn = PtownScraper.core_name(raw_name.unicode_normalize(:nfkc))
          machine = core_name_lookup[cn]
          break if machine
        end

        unless machine
          shop_skipped += 1
          next
        end

        unless dry_run
          smm = ShopMachineModel.find_or_initialize_by(shop: shop, machine_model: machine)
          if smm.new_record?
            smm.data_source = "pworld"
            smm.save
            shop_added += 1 if smm.persisted?
          end
        else
          shop_added += 1
        end
      end

      total_machines_added += shop_added
      total_machines_skipped += shop_skipped

      puts "\r  #{i + 1}/#{total} #{shop.name}: #{match_info[:method]}(#{match_info[:confidence]}) → 機種追加#{shop_added} スキップ#{shop_skipped}"
    end

    puts "\n\n=== 結果 #{dry_run ? "(DRY RUN)" : ""} ==="
    puts "マッチ成功: #{total_matched}"
    puts "マッチなし: #{total_not_found}"
    puts "機種追加: #{total_machines_added}"
    puts "機種スキップ(未登録): #{total_machines_skipped}"

    if !dry_run
      pworld_count = ShopMachineModel.where(data_source: "pworld").count
      shops_with_pworld = ShopMachineModel.where(data_source: "pworld").distinct.pluck(:shop_id).size
      puts "P-WORLD由来リンク合計: #{pworld_count}件 (#{shops_with_pworld}店舗)"
    end
  end

  desc "P-WORLD補完の進捗レポート"
  task status: :environment do
    total_no_machines = Shop.where.not(ptown_shop_id: nil)
      .where.not(last_synced_at: nil)
      .left_joins(:shop_machine_models)
      .group("shops.id")
      .having("count(shop_machine_models.id) = 0")
      .length

    pworld_links = ShopMachineModel.where(data_source: "pworld").count
    pworld_shops = ShopMachineModel.where(data_source: "pworld").distinct.pluck(:shop_id).size
    ptown_links = ShopMachineModel.where(data_source: "ptown").count

    puts "=== P-WORLD補完 進捗 ==="
    puts "DMM由来リンク: #{ptown_links}件"
    puts "P-WORLD由来リンク: #{pworld_links}件 (#{pworld_shops}店舗)"
    puts "残り未補完店舗: #{total_no_machines}件"
  end
end
