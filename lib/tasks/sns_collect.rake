# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "uri"
require "json"

# SNS/RSS data collection for trophy and setting confirmation reports.
# Collects from pachislot blog RSS feeds, Google Custom Search, and optionally structures with SnsParser.

module SnsCollector
  # RSS feed sources for pachislot setting/trophy information
  # Verified 2026-03-12: only these 3 feeds are reachable and return valid RSS.
  # Removed 7 defunct/unreachable feeds: slot-jin, pachinkopachislo,
  # pachislot-kitaichi, pachislot-kanzen, game8, slopachi-sta, nana-tetsu.
  RSS_FEEDS = [
    {
      name: "ちょんぼりすた",
      url: "https://chonborista.com/feed/",
      type: "rss"
    },
    {
      name: "すろぱちくえすと",
      url: "https://slopachi-quest.com/feed/",
      type: "rss"
    },
    {
      name: "パチマガスロマガFREE",
      url: "https://pachimaga.com/free/rss.xml",
      type: "rss"
    }
  ].freeze

  REQUEST_INTERVAL = 2.0

  # Google Custom Search API config
  GOOGLE_CSE_QUERIES = [
    "%{machine} 設定示唆",
    "%{machine} トロフィー 確定",
    "%{machine} トロフィー 確定 設定",
    "%{machine} リセット 朝一 挙動",
    "%{machine} 据え置き 判別",
    "%{machine} 設定6 確定演出 出現"
  ].freeze

  GOOGLE_CSE_ENDPOINT = "https://www.googleapis.com/customsearch/v1"

  class << self
    # ---------------------------------------------------------------
    # RSS Collection
    # ---------------------------------------------------------------
    def collect_from_rss
      $stdout.sync = true
      puts "Collecting from RSS feeds..."
      total_new = 0
      total_skipped = 0
      total_dup = 0

      RSS_FEEDS.each do |feed_config|
        puts "  Fetching #{feed_config[:name]}..."

        begin
          xml = fetch_url(feed_config[:url])
          unless xml
            puts "    SKIP: no response"
            next
          end

          doc = Nokogiri::XML(xml)
          items = doc.css("item")

          puts "    Found #{items.size} articles"

          items.each do |item|
            title = item.at_css("title")&.text&.strip || ""
            link = item.at_css("link")&.text&.strip || ""
            description = item.at_css("description")&.text&.strip || ""
            pub_date = item.at_css("pubDate")&.text&.strip

            # Filter: only setting/trophy related articles
            combined_text = "#{title} #{description}"
            unless setting_related?(combined_text)
              total_skipped += 1
              next
            end

            # Try to match a machine model
            machine = find_matching_machine(title)
            unless machine
              total_skipped += 1
              next
            end

            # Check for duplicates (same source_url)
            if link.present? && SnsReport.exists?(source_url: link)
              total_dup += 1
              next
            end

            # Extract trophy/setting info from title + description
            trophy_type = extract_trophy_type(combined_text)
            suggested = extract_suggested_setting(combined_text)

            report = SnsReport.new(
              machine_model: machine,
              source: "rss",
              source_url: link,
              source_title: title.truncate(255),
              raw_text: description.truncate(2000),
              trophy_type: trophy_type,
              suggested_setting: suggested,
              confidence: trophy_type.present? ? :medium : :low,
              reported_on: pub_date.present? ? Time.parse(pub_date).to_date : Date.current
            )

            if report.save
              # Run parser to populate structured_data
              SnsParser.new(report).parse!
              total_new += 1
            end
          rescue StandardError => e
            puts "    WARNING: Error processing item '#{title}': #{e.message}"
          end

          sleep(REQUEST_INTERVAL)
        rescue StandardError => e
          puts "    ERROR: #{feed_config[:name]}: #{e.message}"
        end
      end

      puts ""
      puts "  RSS Summary:"
      puts "    New reports:  #{total_new}"
      puts "    Duplicates:   #{total_dup}"
      puts "    Skipped:      #{total_skipped}"
      total_new
    end

    # ---------------------------------------------------------------
    # Google Custom Search
    # ---------------------------------------------------------------
    def collect_from_google(machine_names: nil, dry_run: false, limit: nil)
      $stdout.sync = true
      api_key = ENV["GOOGLE_CSE_API_KEY"]
      cx      = ENV["GOOGLE_CSE_CX"]

      unless dry_run
        if api_key.blank? || cx.blank?
          puts "ERROR: GOOGLE_CSE_API_KEY and GOOGLE_CSE_CX environment variables are required."
          puts "  Set them before running: export GOOGLE_CSE_API_KEY=... GOOGLE_CSE_CX=..."
          return 0
        end
      end

      machines = if machine_names.present?
        MachineModel.active.where(name: machine_names)
      else
        MachineModel.active.order(:name)
      end

      machines = machines.limit(limit) if limit

      puts "Google CSE: #{machines.count} machines x #{GOOGLE_CSE_QUERIES.size} queries"
      puts "(dry-run mode)" if dry_run

      total_new = 0
      total_dup = 0
      query_count = 0

      machines.find_each do |machine|
        GOOGLE_CSE_QUERIES.each do |query_template|
          query = query_template % { machine: machine.name }
          query_count += 1

          if dry_run
            puts "  [DRY-RUN] Query #{query_count}: #{query}"
            next
          end

          puts "  Query #{query_count}: #{query}"

          begin
            results = google_search(api_key, cx, query)
            unless results
              puts "    No results"
              next
            end

            items = results["items"] || []
            puts "    Found #{items.size} results"

            items.each do |item|
              url = item["link"]
              title = item["title"]&.truncate(255) || ""
              snippet = item["snippet"]&.truncate(2000) || ""

              # Duplicate check by source_url
              if SnsReport.exists?(source_url: url)
                total_dup += 1
                next
              end

              report = SnsReport.new(
                machine_model: machine,
                source: "google_cse",
                source_url: url,
                source_title: title,
                raw_text: snippet,
                confidence: :unrated,
                reported_on: Date.current
              )

              if report.save
                SnsParser.new(report).parse!
                total_new += 1
              end
            end

            sleep(REQUEST_INTERVAL)
          rescue StandardError => e
            puts "    ERROR: #{e.message}"
          end
        end
      end

      puts ""
      puts "  Google CSE Summary:"
      puts "    Queries sent: #{dry_run ? 0 : query_count}"
      puts "    New reports:  #{total_new}"
      puts "    Duplicates:   #{total_dup}"
      total_new
    end

    # ---------------------------------------------------------------
    # Parse unparsed reports
    # ---------------------------------------------------------------
    def parse_unparsed
      $stdout.sync = true
      unparsed = SnsReport.where(structured_data: {})
      puts "Parsing #{unparsed.count} unparsed reports..."

      count = 0
      unparsed.find_each do |report|
        SnsParser.new(report).parse!
        count += 1
      end
      puts "  Parsed #{count} reports"
      count
    end

    private

    def fetch_url(url)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 15
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "Mozilla/5.0 (compatible; YomiSloBot/1.0)"
      request["Accept"] = "application/rss+xml, application/xml, text/xml"

      response = http.request(request)
      response.code.to_i == 200 ? response.body : nil
    rescue StandardError => e
      puts "    ERROR fetching #{url}: #{e.message}"
      nil
    end

    def google_search(api_key, cx, query)
      uri = URI.parse(GOOGLE_CSE_ENDPOINT)
      uri.query = URI.encode_www_form(key: api_key, cx: cx, q: query, num: 10)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)

      if response.code.to_i == 200
        JSON.parse(response.body)
      else
        puts "    API error #{response.code}: #{response.body.truncate(200)}"
        nil
      end
    rescue StandardError => e
      puts "    ERROR in Google search: #{e.message}"
      nil
    end

    # Check if text is related to setting/trophy information
    def setting_related?(text)
      keywords = %w[設定 トロフィー 確定演出 示唆 エンディング 高設定 設定差 設定判別]
      keywords.any? { |kw| text.include?(kw) }
    end

    # Try to find a matching MachineModel from the title
    def find_matching_machine(title)
      # Try exact matches first with active machines
      MachineModel.active.find_each do |machine|
        return machine if title.include?(machine.name)
      end
      nil
    end

    # Extract trophy type from text
    def extract_trophy_type(text)
      trophy_patterns = {
        "虹トロフィー" => /虹\s*トロフィー/,
        "金トロフィー" => /金\s*トロフィー/,
        "銀トロフィー" => /銀\s*トロフィー/,
        "銅トロフィー" => /銅\s*トロフィー/,
        "キリン柄" => /キリン\s*柄/,
        "レインボー" => /レインボー/,
        "エンディング" => /エンディング/
      }

      trophy_patterns.each do |name, pattern|
        return name if text.match?(pattern)
      end
      nil
    end

    # Extract suggested setting from text
    def extract_suggested_setting(text)
      patterns = {
        "6確" => /設定\s*6\s*確定|設定6確/,
        "5以上" => /設定\s*5\s*以上|5以上確定/,
        "4以上" => /設定\s*4\s*以上|4以上確定|高設定確定/,
        "3以上" => /設定\s*3\s*以上/,
        "2以上" => /設定\s*2\s*以上/,
        "偶数確" => /偶数\s*確定|偶数設定確定/,
        "奇数確" => /奇数\s*確定|奇数設定確定/
      }

      patterns.each do |name, pattern|
        return name if text.match?(pattern)
      end
      nil
    end
  end
end

namespace :sns do
  desc "Collect setting/trophy reports from RSS feeds"
  task collect_rss: :environment do
    puts "=" * 60
    puts "SNS RSS Collection"
    puts "=" * 60

    start_time = Time.current
    SnsCollector.collect_from_rss
    elapsed = (Time.current - start_time).round(1)

    puts ""
    puts "=" * 60
    puts "Collection complete in #{elapsed}s"
    puts "  Total SNS reports in DB: #{SnsReport.count}"
    puts "    pending:  #{SnsReport.pending.count}"
    puts "    approved: #{SnsReport.approved.count}"
    puts "    rejected: #{SnsReport.rejected.count}"
    puts "=" * 60
  end

  desc "Search Google CSE for setting/trophy info [dry_run=1] [machines=name1,name2] [limit=N]"
  task google_search: :environment do
    puts "=" * 60
    puts "Google Custom Search Collection"
    puts "=" * 60

    dry_run = ENV["dry_run"] == "1"
    machine_names = ENV["machines"]&.split(",")&.map(&:strip)
    limit = ENV["limit"]&.to_i

    start_time = Time.current
    SnsCollector.collect_from_google(
      machine_names: machine_names,
      dry_run: dry_run,
      limit: limit
    )
    elapsed = (Time.current - start_time).round(1)

    puts ""
    puts "=" * 60
    puts "Search complete in #{elapsed}s"
    puts "  Total SNS reports in DB: #{SnsReport.count}"
    puts "=" * 60
  end

  desc "Parse all unparsed SnsReports with SnsParser"
  task parse: :environment do
    puts "=" * 60
    puts "SnsParser: Processing unparsed reports"
    puts "=" * 60

    SnsCollector.parse_unparsed

    puts "=" * 60
  end

  desc "Full collection pipeline: RSS + parse"
  task collect_all: :environment do
    Rake::Task["sns:collect_rss"].invoke
    puts ""
    Rake::Task["sns:parse"].invoke
  end
end
