module HomeHelper
  HERO_TAGLINES = {
    morning_open:  ["おはよう！",               "朝イチの狙い目", "をチェックしよう！"],
    daytime:       ["調子はどう？",             "台の機嫌",       "を記録しよう"],
    evening_close: ["おつかれさま！",           "勝負の1台",      "を記録しよう"],
    late_night:    ["今日の結果はどうだった？", "収支",           "をつけておこう"]
  }.freeze

  def hero_tagline_html(now = Time.zone.now)
    prefix, emphasis, suffix = HERO_TAGLINES.fetch(hero_tagline_segment(now.hour))
    safe_join([prefix, content_tag(:span, emphasis, class: "text-primary"), suffix])
  end

  def hero_tagline_segment(hour)
    case hour
    when 5..9   then :morning_open
    when 10..16 then :daytime
    when 17..22 then :evening_close
    else             :late_night
    end
  end
end
