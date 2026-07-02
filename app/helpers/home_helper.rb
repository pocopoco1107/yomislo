module HomeHelper
  HERO_TAGLINES = {
    morning_open:  [ "今日のリセットを ",  "読み解け！",          "" ],
    daytime:       [ "みんなの記録で ",    "設定を 暴け！",       "" ],
    evening_close: [ "今日の勝負の1台を ", "記録しよう",          "" ],
    late_night:    [ "今日の結果を ",      "振り返ろう",           "" ]
  }.freeze

  def hero_tagline_html(now = Time.zone.now)
    prefix, emphasis, suffix = HERO_TAGLINES.fetch(hero_tagline_segment(now.hour))
    safe_join([ prefix, content_tag(:span, emphasis, class: "text-primary"), suffix ])
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
