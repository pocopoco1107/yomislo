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
end
