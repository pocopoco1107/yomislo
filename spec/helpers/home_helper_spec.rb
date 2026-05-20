require "rails_helper"

RSpec.describe HomeHelper, type: :helper do
  include ActiveSupport::Testing::TimeHelpers

  describe "#hero_tagline_segment" do
    it "maps morning hours (5-9) to :morning_open" do
      (5..9).each { |h| expect(helper.hero_tagline_segment(h)).to eq(:morning_open) }
    end

    it "maps daytime hours (10-16) to :daytime" do
      (10..16).each { |h| expect(helper.hero_tagline_segment(h)).to eq(:daytime) }
    end

    it "maps evening hours (17-22) to :evening_close" do
      (17..22).each { |h| expect(helper.hero_tagline_segment(h)).to eq(:evening_close) }
    end

    it "maps late-night hours (23, 0-4) to :late_night" do
      [23, 0, 1, 2, 3, 4].each { |h| expect(helper.hero_tagline_segment(h)).to eq(:late_night) }
    end
  end

  describe "#hero_tagline_html" do
    it "renders the morning tagline at 5:00" do
      travel_to(Time.zone.local(2026, 5, 20, 5, 0, 0)) do
        html = helper.hero_tagline_html
        expect(html).to eq(%(おはよう！<span class="text-primary">朝イチの狙い目</span>をチェックしよう！))
        expect(html).to be_html_safe
      end
    end

    it "renders the daytime tagline at 10:00" do
      travel_to(Time.zone.local(2026, 5, 20, 10, 0, 0)) do
        expect(helper.hero_tagline_html).to eq(%(調子はどう？<span class="text-primary">台の機嫌</span>を記録しよう))
      end
    end

    it "renders the evening tagline at 17:00" do
      travel_to(Time.zone.local(2026, 5, 20, 17, 0, 0)) do
        expect(helper.hero_tagline_html).to eq(%(おつかれさま！<span class="text-primary">勝負の1台</span>を記録しよう))
      end
    end

    it "renders the late-night tagline at 23:00" do
      travel_to(Time.zone.local(2026, 5, 20, 23, 0, 0)) do
        expect(helper.hero_tagline_html).to eq(%(今日の結果はどうだった？<span class="text-primary">収支</span>をつけておこう))
      end
    end

    it "treats 4:59 as late night and 5:00 as morning" do
      travel_to(Time.zone.local(2026, 5, 20, 4, 59, 59)) do
        expect(helper.hero_tagline_html).to include("収支")
      end
      travel_to(Time.zone.local(2026, 5, 20, 5, 0, 0)) do
        expect(helper.hero_tagline_html).to include("朝イチの狙い目")
      end
    end

    it "treats 9:59 as morning and 10:00 as daytime" do
      travel_to(Time.zone.local(2026, 5, 20, 9, 59, 59)) do
        expect(helper.hero_tagline_html).to include("朝イチの狙い目")
      end
      travel_to(Time.zone.local(2026, 5, 20, 10, 0, 0)) do
        expect(helper.hero_tagline_html).to include("台の機嫌")
      end
    end

    it "treats 16:59 as daytime and 17:00 as evening" do
      travel_to(Time.zone.local(2026, 5, 20, 16, 59, 59)) do
        expect(helper.hero_tagline_html).to include("台の機嫌")
      end
      travel_to(Time.zone.local(2026, 5, 20, 17, 0, 0)) do
        expect(helper.hero_tagline_html).to include("勝負の1台")
      end
    end

    it "treats 22:59 as evening and 23:00 as late night" do
      travel_to(Time.zone.local(2026, 5, 20, 22, 59, 59)) do
        expect(helper.hero_tagline_html).to include("勝負の1台")
      end
      travel_to(Time.zone.local(2026, 5, 20, 23, 0, 0)) do
        expect(helper.hero_tagline_html).to include("収支")
      end
    end

    it "stays in late_night across midnight (0:00)" do
      travel_to(Time.zone.local(2026, 5, 20, 0, 0, 0)) do
        expect(helper.hero_tagline_html).to include("収支")
      end
    end
  end
end
