module UiHelper
  # アクセントバーの色トークン (意味を固定して色の乱用を防ぐ)
  SECTION_HEADING_ACCENTS = {
    primary: "bg-primary",
    yellow: "bg-slot-yellow",
    red: "bg-slot-red",
    blue: "bg-slot-blue",
    green: "bg-slot-green",
    confirmed: "bg-confirmed"
  }.freeze

  SECTION_HEADING_SIZES = {
    sm: "text-sm",
    base: "text-base",
    lg: "text-lg"
  }.freeze

  # 手書き風 font-heading を当てたセクション見出し。
  # 「打ち手の仲間が作ったツール感」を出すため、装飾的な見出しに限定して使う。
  # 機種名・数値・表データには絶対に使わない (可読性優先)。
  #
  #   section_heading "店舗情報"
  #   section_heading "収支統計", accent: :yellow, extra: "mb-3"
  #   section_heading "天井・期待値", accent: :primary, size: :base
  def section_heading(text, accent: nil, size: :sm, tag: :h2, extra: nil, **options)
    size_class = SECTION_HEADING_SIZES.fetch(size, SECTION_HEADING_SIZES[:sm])
    classes = [
      "font-heading font-bold tracking-tight text-foreground flex items-center gap-2",
      size_class,
      extra
    ].compact.join(" ")

    bar =
      if accent
        accent_class = SECTION_HEADING_ACCENTS.fetch(accent, SECTION_HEADING_ACCENTS[:primary])
        content_tag(:span, "", class: "w-1 h-4 rounded-full shrink-0 #{accent_class}")
      end

    content_tag(tag, safe_join([ bar, text ].compact), class: classes, **options)
  end
end
