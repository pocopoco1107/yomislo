module UiHelper
  # ドラクエ風 ▶ メニューカーソルの色トークン (意味を固定して色の乱用を防ぐ)
  SECTION_HEADING_CURSORS = {
    primary: "text-primary",
    yellow: "text-slot-yellow",
    red: "text-slot-red",
    blue: "text-slot-blue",
    green: "text-slot-green",
    confirmed: "text-confirmed"
  }.freeze

  SECTION_HEADING_SIZES = {
    sm: "text-sm",
    base: "text-base",
    lg: "text-lg"
  }.freeze

  # ドット絵 font-heading + ドラクエ風 ▶ カーソルを当てたセクション見出し。
  # RPG/ファミコンの世界観を出すため、装飾的な見出しに限定して使う。
  # 機種名・数値・表データには絶対に使わない (可読性優先)。
  #
  #   section_heading "店舗情報"
  #   section_heading "収支統計", accent: :yellow, extra: "mb-3"
  #   section_heading "天井・期待値", accent: :primary, size: :base
  def section_heading(text, accent: nil, size: :sm, tag: :h2, extra: nil, **options)
    size_class = SECTION_HEADING_SIZES.fetch(size, SECTION_HEADING_SIZES[:sm])
    # font-bold は付けない: ウェイト正規化(700)は CSS の .font-heading 側で行う。
    classes = [
      "font-heading tracking-tight text-foreground flex items-center gap-1.5",
      size_class,
      extra
    ].compact.join(" ")

    cursor_color = SECTION_HEADING_CURSORS.fetch(accent || :primary, SECTION_HEADING_CURSORS[:primary])
    cursor = content_tag(:span, "▶", class: "shrink-0 text-[0.7em] #{cursor_color}", "aria-hidden": "true")

    content_tag(tag, safe_join([ cursor, text ]), class: classes, **options)
  end

  # 記録マイルストーン到達時のトースト表示内容。VotesController#detect_milestones が返す
  # ハッシュ ({ type:, threshold: or setting: }) を、emoji/タイトル/説明の3要素に変換する。
  # コピーは打ち手口調で統一 (硬い用語・お祝いテンプレは避ける)。
  def milestone_display(milestone)
    case milestone[:type]
    when :total_votes
      case milestone[:threshold]
      when 10   then { emoji: "🎉", title: "デビュー達成！",   desc: "10件 記録した" }
      when 100  then { emoji: "🎊", title: "100件突破！",       desc: "そろそろ目利きだな" }
      when 1000 then { emoji: "👑", title: "1000件 到達！",     desc: "伝説の記録者" }
      end
    when :streak
      case milestone[:threshold]
      when 7  then { emoji: "🔥", title: "7日連続！",           desc: "ストリーク発動中" }
      when 30 then { emoji: "⚡", title: "30日連続！",           desc: "鋼のリズム" }
      end
    when :first_high_setting
      { emoji: "💥", title: "高設定を 掴んだ！", desc: "設定#{milestone[:setting]}を 初記録" }
    end
  end

  DOT_BAR_COLORS = {
    primary: { fill: "bg-primary",     empty: "bg-secondary" },
    green:   { fill: "bg-slot-green",  empty: "bg-secondary" },
    yellow:  { fill: "bg-slot-yellow", empty: "bg-secondary" },
    red:     { fill: "bg-slot-red",    empty: "bg-secondary" },
    blue:    { fill: "bg-slot-blue",   empty: "bg-secondary" },
    confirmed: { fill: "bg-confirmed", empty: "bg-secondary" }
  }.freeze

  DOT_BAR_HEIGHTS = { xs: "h-2", sm: "h-2.5", base: "h-3", lg: "h-3.5" }.freeze

  def dot_bar(current, total, color: :primary, segments: 8, height: :sm, label: nil, value: nil, label_color: nil)
    total = total.to_f
    ratio = total.positive? ? (current.to_f / total).clamp(0.0, 1.0) : 0.0
    filled = (ratio * segments).round.clamp(0, segments)

    palette = DOT_BAR_COLORS.fetch(color, DOT_BAR_COLORS[:primary])
    height_cls = DOT_BAR_HEIGHTS.fetch(height, DOT_BAR_HEIGHTS[:sm])
    label_color_cls = label_color || "text-#{color == :primary ? 'primary' : "slot-#{color}"}"

    bar = content_tag(:div, class: "flex flex-1 gap-px") do
      safe_join(Array.new(segments) { |i|
        content_tag(:div, "", class: "flex-1 #{height_cls} #{i < filled ? palette[:fill] : palette[:empty]}")
      })
    end

    label_node = label.present? ? content_tag(:span, label, class: "font-heading text-[10px] #{label_color_cls} shrink-0 w-12") : nil
    value_node = value.present? ? content_tag(:span, value, class: "font-heading text-[11px] text-foreground shrink-0 w-10 text-right tabular-nums") : nil

    content_tag(:div, class: "flex items-center gap-2",
                role: "progressbar",
                "aria-valuenow": current.to_i,
                "aria-valuemin": 0,
                "aria-valuemax": total.to_i,
                "aria-label": (label.presence || "進捗")) do
      safe_join([ label_node, bar, value_node ].compact)
    end
  end
end
