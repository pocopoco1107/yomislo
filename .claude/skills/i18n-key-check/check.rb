# encoding: UTF-8
# frozen_string_literal: true

#
# i18n-key-check の本体。
# Usage: ruby check.rb <locale_file> <file1> [file2] ...
# Exit: 0=OK, 1=missing key あり

require 'yaml'

locale_file = ARGV.shift
unless locale_file && File.file?(locale_file)
  warn "locale file not found: #{locale_file.inspect}"
  exit 2
end

def deep_get(hash, keys)
  cur = hash
  keys.each do |k|
    return nil unless cur.is_a?(Hash)
    cur = cur[k] || cur[k.to_sym]
  end
  cur
end

locale_yaml = begin
  YAML.load_file(locale_file, permitted_classes: [ Symbol ], aliases: true)
rescue ArgumentError
  YAML.load_file(locale_file)
end

ja_root = locale_yaml.is_a?(Hash) ? (locale_yaml['ja'] || locale_yaml[:ja]) : nil
unless ja_root
  warn "locale file has no 'ja' top key: #{locale_file}"
  exit 2
end

def lazy_prefix(path)
  case path
  when %r{\Aapp/views/(.+)\z}
    rel = Regexp.last_match(1)
    rel = rel.sub(/\.[^.]+\.erb\z/, '').sub(/\.erb\z/, '')
    dir, base = File.split(rel)
    base = base.sub(/\A_/, '')
    parts = (dir == '.' ? [ base ] : [ dir, base ])
    parts.join('/').tr('/', '.')
  when %r{\Aapp/controllers/(.+)\.rb\z}
    Regexp.last_match(1).sub(/_controller\z/, '').tr('/', '.')
  when %r{\Aapp/helpers/(.+)\.rb\z}
    "helpers." + Regexp.last_match(1).sub(/_helper\z/, '').tr('/', '.')
  when %r{\Aapp/mailers/(.+)\.rb\z}
    Regexp.last_match(1).sub(/_mailer\z/, '').tr('/', '.')
  end
end

t_call_regex = /(?:^|[^A-Za-z0-9_])(?:I18n\.)?t\(\s*(["'])((?:\.[^"']*|[^"'\#]+))\1/

total_fail = 0
total_files = 0
results = []

ARGV.each do |path|
  next unless File.file?(path)
  next unless path =~ %r{\Aapp/(views|controllers|helpers|mailers)/.*\.(erb|rb)\z}

  total_files += 1
  prefix = lazy_prefix(path)
  body = File.read(path, encoding: 'UTF-8')
  findings = []

  body.each_line.with_index(1) do |line, lineno|
    line.scan(t_call_regex) do |_quote, key|
      next if key.include?('#{')
      full =
        if key.start_with?('.')
          next unless prefix
          "#{prefix}#{key}"
        else
          key
        end
      segs = full.split('.')
      if deep_get(ja_root, segs).nil?
        findings << [ lineno, key, full ]
      end
    end
  end

  if findings.empty?
    results << "  OK  #{path}"
  else
    results << "  NG  #{path}"
    findings.each do |lineno, raw, full|
      results << "      [missing-key] L#{lineno}: t(#{raw.inspect}) -> #{full} not in ja.yml"
      total_fail += 1
    end
  end
end

puts "i18n-key-check (#{total_files} files)"
results.each { |r| puts r }
puts ""
puts "inspected=#{total_files} missing=#{total_fail}"
exit(total_fail.positive? ? 1 : 0)
