# frozen_string_literal: true

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
  USER_AGENT = "Mozilla/5.0 (compatible; SloSitteBot/1.0; +https://slositte.example.com)"
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

  class << self
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

            # Create or update the shop
            shop = Shop.find_or_initialize_by(slug: shop_slug)
            shop.name = shop_name
            shop.prefecture = prefecture
            shop.address = address if address.present?

            if shop.new_record?
              shop.save!
              total_imported += 1
            else
              shop.save! if shop.changed?
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
      puts "  Done: #{pref_name} - #{total_imported} new shops imported (#{shop_count} total in DB)"
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
              slug = machine_name
                .gsub(/\s+/, "-")
                .gsub(/[^\p{L}\p{N}\-]/, "")
                .downcase
                .truncate(100, omission: "")

              # Avoid empty slugs
              next if slug.blank?

              # Map P-WORLD type to our spec_type
              spec_type = case type_text
                          when "NORMAL" then :type_a
                          when "AT" then :type_at
                          when "ART", "aRT" then :type_art
                          when "RT" then :type_a_plus_at
                          else :type_at
                          end

              model = MachineModel.find_or_initialize_by(slug: slug)
              if model.new_record?
                model.name = machine_name
                model.maker = maker_name
                model.machine_type = :slot
                model.spec_type = spec_type
                model.save!
                total_imported += 1
              end
            rescue ActiveRecord::RecordInvalid => e
              puts "    WARNING: Could not save machine '#{machine_name}': #{e.message}"
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
          slug = machine_name
            .gsub(/\s+/, "-")
            .gsub(/[^\p{L}\p{N}\-]/, "")
            .downcase
            .truncate(100, omission: "")

          next if slug.blank?

          # Determine machine_type
          machine_type = if type_text.include?("パチスロ") || type_text.include?("スロット")
                           :slot
                         else
                           :pachislot
                         end

          model = MachineModel.find_or_initialize_by(slug: slug)
          if model.new_record?
            model.name = machine_name
            model.maker = maker_name
            model.machine_type = machine_type
            model.spec_type = :type_at # Default; schedule page doesn't always specify
            model.save!
            total_imported += 1
          end
        rescue ActiveRecord::RecordInvalid => e
          puts "  WARNING: Could not save machine '#{machine_name}': #{e.message}"
        rescue StandardError => e
          puts "  WARNING: Error processing machine: #{e.message}"
        end
      end

      puts "  Done: #{total_imported} new machine models imported from schedule"
      total_imported
    end
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
  task :import_prefecture, [:slug] => :environment do |_t, args|
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
end
