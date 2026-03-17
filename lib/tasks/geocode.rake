# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

namespace :geocode do
  desc "Geocode shops using GSI API (primary) + Nominatim (fallback). Usage: rake geocode:shops / rake geocode:shops[kumamoto]"
  task :shops, [ :pref_slug ] => :environment do |_t, args|
    scope = Shop.where(lat: nil).where("address IS NOT NULL AND address != ''")
    scope = filter_by_pref(scope, args[:pref_slug])

    total = scope.count
    if total.zero?
      puts "全店舗ジオコーディング済みです"
      next
    end

    puts "対象: #{total}件"
    success = 0
    failed = 0

    scope.find_each.with_index(1) do |shop, index|
      print "#{index}/#{total} #{shop.name} ... "

      begin
        lat, lng, precision = geocode_with_gsi(shop.address)

        if lat.nil?
          lat, lng = geocode_with_nominatim(shop.address)
          precision = 1 if lat # Nominatim fallback = city level precision
        end

        if lat && lng
          shop.update_columns(lat: lat, lng: lng, geocode_precision: precision || 1)
          success += 1
          puts "OK (#{lat}, #{lng}) precision=#{precision}"
        else
          failed += 1
          puts "NOT FOUND"
        end
      rescue => e
        failed += 1
        puts "ERROR: #{e.message}"
      end

      sleep 1.5
    end

    puts ""
    puts "完了: #{success}件成功, #{failed}件失敗 (計#{total}件)"
  end

  desc "Re-geocode imprecise shops (precision 0-1). Usage: rake geocode:fix_imprecise / rake geocode:fix_imprecise[kumamoto]"
  task :fix_imprecise, [ :pref_slug ] => :environment do |_t, args|
    scope = Shop.where("geocode_precision <= 1").where("address IS NOT NULL AND address != ''")
    scope = filter_by_pref(scope, args[:pref_slug])

    total = scope.count
    if total.zero?
      puts "精度の低い店舗はありません"
      next
    end

    puts "対象: #{total}件 (precision <= 1)"
    improved = 0
    unchanged = 0

    scope.find_each.with_index(1) do |shop, index|
      print "#{index}/#{total} #{shop.name} (現在precision=#{shop.geocode_precision}) ... "

      begin
        lat, lng, precision = geocode_with_gsi(shop.address)

        if lat && precision && precision > shop.geocode_precision
          shop.update_columns(lat: lat, lng: lng, geocode_precision: precision)
          improved += 1
          puts "IMPROVED → precision=#{precision} (#{lat}, #{lng})"
        else
          unchanged += 1
          puts "unchanged"
        end
      rescue => e
        unchanged += 1
        puts "ERROR: #{e.message}"
      end

      sleep 1.5
    end

    puts ""
    puts "完了: #{improved}件改善, #{unchanged}件変更なし (計#{total}件)"
  end

  desc "Detect shops sharing identical coordinates and mark as precision=1. Usage: rake geocode:detect_duplicates / rake geocode:detect_duplicates[kumamoto]"
  task :detect_duplicates, [ :pref_slug ] => :environment do |_t, args|
    scope = Shop.where.not(lat: nil).where.not(lng: nil)
    scope = filter_by_pref(scope, args[:pref_slug])

    # Find duplicate coordinate groups
    dupes = scope.group(:lat, :lng).having("COUNT(*) > 1").pluck(:lat, :lng)

    if dupes.empty?
      puts "同一座標の店舗はありません"
      next
    end

    total_marked = 0
    dupes.each do |lat, lng|
      shops = scope.where(lat: lat, lng: lng)
      names = shops.pluck(:name)
      puts "同一座標 (#{lat}, #{lng}): #{names.join(', ')}"
      marked = shops.where("geocode_precision > 1 OR geocode_precision = 0").update_all(geocode_precision: 1)
      total_marked += marked
    end

    puts ""
    puts "#{dupes.size}グループ, #{total_marked}件をprecision=1にマーク"
  end

  desc "Show geocode precision stats. Usage: rake geocode:stats / rake geocode:stats[kumamoto]"
  task :stats, [ :pref_slug ] => :environment do |_t, args|
    scope = Shop.all
    scope = filter_by_pref(scope, args[:pref_slug])

    total = scope.count
    with_coords = scope.where.not(lat: nil).count
    without_coords = total - with_coords

    precision_counts = scope.where.not(lat: nil).group(:geocode_precision).count.sort_by(&:first)

    puts "=== ジオコーディング精度レポート ==="
    puts "総店舗数: #{total}"
    puts "座標あり: #{with_coords} (#{pct(with_coords, total)})"
    puts "座標なし: #{without_coords} (#{pct(without_coords, total)})"
    puts ""
    puts "--- 精度別内訳 ---"
    labels = { 0 => "未取得", 1 => "市レベル(不正確)", 2 => "町レベル", 3 => "番地レベル(高精度)" }
    precision_counts.each do |precision, count|
      puts "  precision=#{precision} (#{labels[precision] || '不明'}): #{count}件 (#{pct(count, with_coords)})"
    end

    accurate = scope.where("geocode_precision >= 2").count
    puts ""
    puts "高精度(>=2): #{accurate}件 (#{pct(accurate, with_coords)})"
  end
end

def filter_by_pref(scope, pref_slug)
  if pref_slug.present?
    pref = Prefecture.find_by!(slug: pref_slug)
    puts "県: #{pref.name}"
    scope.where(prefecture_id: pref.id)
  else
    scope
  end
end

def pct(count, total)
  return "0%" if total.zero?
  "#{(count.to_f / total * 100).round(1)}%"
end

def geocode_with_gsi(address)
  return nil if address.blank?

  uri = URI("https://msearch.gsi.go.jp/address-search/AddressSearch")
  uri.query = URI.encode_www_form(q: address)

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 10
  http.read_timeout = 10

  request = Net::HTTP::Get.new(uri)
  request["User-Agent"] = "YomiSlo/1.0"

  response = http.request(request)
  return nil unless response.is_a?(Net::HTTPSuccess)

  results = JSON.parse(response.body)
  return nil if results.empty?

  # GSI returns GeoJSON: coordinates = [lng, lat]
  coords = results[0].dig("geometry", "coordinates")
  return nil unless coords&.length == 2

  lng = coords[0].to_f
  lat = coords[1].to_f
  title = results[0].dig("properties", "title") || ""

  precision = determine_gsi_precision(title)

  [ lat, lng, precision ]
end

def determine_gsi_precision(title)
  if title.match?(/丁目|番地|\d+-\d+/)
    3
  elsif title.match?(/町|村|大字/)
    2
  else
    1
  end
end

def geocode_with_nominatim(address)
  return nil if address.blank?

  user_agent = "YomiSlo/1.0 (https://yomislo.example.com)"
  base_url = "https://nominatim.openstreetmap.org/search"

  uri = URI(base_url)
  uri.query = URI.encode_www_form(q: address, format: "json", limit: 1, countrycodes: "jp")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 10
  http.read_timeout = 10

  request = Net::HTTP::Get.new(uri)
  request["User-Agent"] = user_agent
  request["Accept"] = "application/json"

  response = http.request(request)
  return nil unless response.is_a?(Net::HTTPSuccess)

  results = JSON.parse(response.body)
  return nil if results.empty?

  lat = results[0]["lat"].to_f
  lng = results[0]["lon"].to_f
  [ lat, lng ]
end
