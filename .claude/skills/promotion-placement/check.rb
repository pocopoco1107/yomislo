# encoding: utf-8
# frozen_string_literal: true

# /promotion-placement — render_promotion 呼び出し側の規約チェック
# - 既知スロットキーのみ
# - 1ページあたり最大2枠
# - Turbo Frame 内禁止
# - shared/_promotion_*.html.erb の rel/target/PR 完全性

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require "pathname"

ALLOWED_SLOTS = {
  "home_hero" => :banner,
  "home_zone_split" => :card,
  "shop_detail_top" => :banner,
  "shop_detail_bottom" => :card,
  "machine_detail" => :banner,
  "voter_status" => :card,
  "rankings_top" => :banner
}.freeze

PROJECT_ROOT = Pathname.new(File.expand_path("../../../..", __FILE__))

issues = []
warnings = []
notes = []

# === 1. 呼び出し箇所のスキャン ===
view_files = Dir.glob(PROJECT_ROOT.join("app/views/**/*.erb"))
calls_by_file = Hash.new { |h, k| h[k] = [] }

view_files.each do |path|
  content = File.read(path, encoding: "UTF-8")
  content.each_line.with_index(1) do |line, lineno|
    next unless line.include?("render_promotion")
    # render_promotion :slot_key, variant: :variant
    m = line.match(/render_promotion\s+:(?<slot>\w+)(?:\s*,\s*variant:\s*:(?<variant>\w+))?/)
    next unless m
    calls_by_file[path] << { line: lineno, slot: m[:slot], variant: m[:variant], raw: line.strip }
  end
end

# === 2. 既知スロットキーチェック ===
calls_by_file.each do |file, calls|
  calls.each do |c|
    expected = ALLOWED_SLOTS[c[:slot]]
    if expected.nil?
      issues << "[unknown-slot] #{relative(file)}:#{c[:line]} 未定義スロット :#{c[:slot]}"
    elsif c[:variant] && c[:variant].to_sym != expected
      warnings << "[wrong-variant] #{relative(file)}:#{c[:line]} :#{c[:slot]} は variant: :#{expected} 推奨（現状 :#{c[:variant]}）"
    end
  end
end

# === 3. 1ページ最大2枠チェック ===
calls_by_file.each do |file, calls|
  if calls.size > 2
    issues << "[too-many] #{relative(file)} に #{calls.size} 件の render_promotion（最大2枠）"
  end
end

# === 4. Turbo Frame 内禁止チェック ===
# 簡易ステートマシン: turbo_frame_tag ブロックの開閉を行番号で追跡
calls_by_file.each do |file, calls|
  content = File.read(file)
  lines = content.lines
  in_frame_stack = []
  frame_ranges = []

  lines.each_with_index do |line, idx|
    lineno = idx + 1
    if line =~ /<%=?\s*turbo_frame_tag\b.*do\s*%>/
      in_frame_stack << lineno
    elsif line =~ /<turbo-frame\b/ && line !~ /<\/turbo-frame>/
      in_frame_stack << lineno
    elsif line =~ /<%\s*end\s*%>/ && in_frame_stack.any?
      start = in_frame_stack.pop
      frame_ranges << (start..lineno)
    elsif line =~ /<\/turbo-frame>/ && in_frame_stack.any?
      start = in_frame_stack.pop
      frame_ranges << (start..lineno)
    end
  end

  calls.each do |c|
    if frame_ranges.any? { |r| r.include?(c[:line]) }
      issues << "[in-frame] #{relative(file)}:#{c[:line]} render_promotion が Turbo Frame 内にある"
    end
  end
end

# === 5. shared パーシャルの rel/target/PRラベル ===
%w[_promotion_banner.html.erb _promotion_card.html.erb].each do |partial_name|
  path = PROJECT_ROOT.join("app/views/shared/#{partial_name}")
  unless path.exist?
    issues << "[missing-partial] #{partial_name} が存在しない"
    next
  end
  body = File.read(path, encoding: "UTF-8")
  issues << "[missing-rel] #{partial_name}: rel=\"sponsored noopener\" がない" unless body.include?("sponsored")
  issues << "[missing-target] #{partial_name}: target=\"_blank\" がない" unless body.include?('target="_blank"')
  warnings << "[missing-pr-label] #{partial_name}: 「PR」ラベルらしき表記がない" unless body =~ /\bPR\b/
end

# === 6. ENV ガードの存在 ===
helper_path = PROJECT_ROOT.join("app/helpers/promotions_helper.rb")
if helper_path.exist?
  body = File.read(helper_path, encoding: "UTF-8")
  unless body.include?("PROMOTIONS_ENABLED")
    issues << "[no-env-guard] promotions_helper.rb に PROMOTIONS_ENABLED の判定がない"
  end
else
  issues << "[missing-helper] app/helpers/promotions_helper.rb が存在しない"
end

# === 7. 全スロットの実装カバレッジ ===
implemented = calls_by_file.values.flatten.map { |c| c[:slot] }.uniq
missing_slots = ALLOWED_SLOTS.keys - implemented
notes << "未実装スロット (#{missing_slots.size}): #{missing_slots.join(', ')}" unless missing_slots.empty?

# === レポート出力 ===
def relative(path)
  path.to_s.sub(PROJECT_ROOT.to_s + "/", "")
end

puts "=== promotion-placement ==="
puts ""
puts "実装済みスロット: #{calls_by_file.values.flatten.size} 箇所 / 既知 #{ALLOWED_SLOTS.size} スロット"
puts ""

if issues.empty? && warnings.empty?
  puts "✅ 違反なし"
else
  unless issues.empty?
    puts "❌ FAIL #{issues.size} 件:"
    issues.each { |i| puts "  - #{i}" }
  end
  unless warnings.empty?
    puts "⚠️  WARN #{warnings.size} 件:"
    warnings.each { |w| puts "  - #{w}" }
  end
end

unless notes.empty?
  puts ""
  puts "ℹ️  Note:"
  notes.each { |n| puts "  - #{n}" }
end

exit(issues.empty? ? 0 : 1)
