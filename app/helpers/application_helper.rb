module ApplicationHelper
  # Render favorite ★ mark (client-side via Stimulus)
  # Inserts a small span that auto-shows ★ if the shop is in localStorage favorites
  def favorite_mark(shop)
    tag.span(class: "text-yellow-500 text-xs leading-none", data: {
      controller: "favorite-mark",
      favorite_mark_slug_value: shop.slug
    })
  end

  # Render star characters for a given rating (1-5, supports decimals)
  def render_stars(rating)
    return "" unless rating
    full = rating.to_i
    ("★" * full + "☆" * (5 - full)).html_safe
  end

  # Tailwind CSS class merge helper — concatenates classes, removes nil/blank
  # Usage: cn("px-4 py-2", condition && "bg-primary", nil, "text-sm")
  #   => "px-4 py-2 bg-primary text-sm"
  def cn(*classes)
    classes.flatten.compact_blank.join(" ")
  end

  # --------------------------------------------------
  # SVG icon helpers — inline SVG for header/nav/flash
  # All icons use currentColor and accept optional CSS classes
  # --------------------------------------------------

  def icon_menu(css = "w-5 h-5")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M4 6h16M4 12h16M4 18h16", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  def icon_x(css = "w-5 h-5")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M18 6L6 18M6 6l12 12", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  def icon_sun(css = "w-4 h-4")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  def icon_moon(css = "w-4 h-4")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  def icon_monitor(css = "w-4 h-4")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  def icon_home(css = "w-5 h-5")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-4 0a1 1 0 01-1-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 01-1 1h-2z", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  def icon_search(css = "w-5 h-5")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  def icon_user(css = "w-5 h-5")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  def icon_check_circle(css = "w-5 h-5")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  def icon_exclamation_circle(css = "w-5 h-5")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  def icon_message(css = "w-5 h-5")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  def icon_plus_circle(css = "w-5 h-5")
    tag.svg(class: css, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "stroke-width": "2") do
      tag.path(d: "M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z", "stroke-linecap": "round", "stroke-linejoin": "round")
    end
  end

  # --------------------------------------------------
  # Date formatting helpers with weekday and holiday
  # --------------------------------------------------

  DAY_LABELS = %w[日 月 火 水 木 金 土].freeze

  def format_date_with_weekday(date, format: :full)
    wday_str = DAY_LABELS[date.wday]
    case format
    when :full
      "#{date.strftime('%Y年%-m月%-d日')}(#{wday_str})"
    when :short
      "#{date.strftime('%-m/%-d')}(#{wday_str})"
    end
  end

  def holiday_badge(date)
    holiday = HolidayJp.between(date, date).first
    return nil unless holiday

    tag.span(
      class: "inline-flex items-center gap-1 text-xs px-1.5 py-0.5 rounded-md bg-destructive/10 text-destructive font-medium",
      title: holiday.name
    ) do
      holiday.name
    end
  end

  def holiday?(date)
    HolidayJp.between(date, date).any?
  end

  # Aggregate daily trend data into weekly buckets for long-period charts.
  # Returns array of hashes with :label, :date, :votes, :reset_rate, :setting_avg
  def aggregate_weekly(days_data)
    return days_data if days_data.size <= 14

    weeks = days_data.each_slice(7).map do |week|
      total_votes = week.sum { |d| d[:votes] }

      # Weighted reset rate
      reset_rates = week.select { |d| d[:reset_rate] }
      avg_reset = if reset_rates.any?
                    (reset_rates.sum { |d| d[:reset_rate] } / reset_rates.size).round(1)
      end

      # Weighted setting average
      settings = week.select { |d| d[:setting_avg] }
      avg_setting = if settings.any?
                      (settings.sum { |d| d[:setting_avg] } / settings.size).round(1)
      end

      first_date = week.first[:date]
      last_date = week.last[:date]
      label = "#{first_date.strftime('%-m/%-d')}~#{last_date.strftime('%-m/%-d')}"

      {
        date: first_date,
        label: label,
        votes: total_votes,
        reset_rate: avg_reset,
        setting_avg: avg_setting
      }
    end

    weeks
  end
end
