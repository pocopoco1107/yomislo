require "rails_helper"

RSpec.describe UiHelper, type: :helper do
  describe "#milestone_display" do
    it "returns emoji/title/desc/share_text for each total_votes threshold" do
      [ 10, 100, 1000 ].each do |threshold|
        info = helper.milestone_display(type: :total_votes, threshold: threshold)
        expect(info).to include(:emoji, :title, :desc, :share_text)
        expect(info[:share_text]).to include("ヨミスロ")
      end
    end

    it "returns emoji/title/desc/share_text for each streak threshold" do
      [ 7, 30 ].each do |threshold|
        info = helper.milestone_display(type: :streak, threshold: threshold)
        expect(info).to include(:emoji, :title, :desc, :share_text)
        expect(info[:share_text]).to include("ヨミスロ")
      end
    end

    it "returns share_text including the setting number for first_high_setting" do
      info = helper.milestone_display(type: :first_high_setting, setting: 5)
      expect(info[:share_text]).to include("設定5")
    end

    it "returns nil for an unknown threshold" do
      expect(helper.milestone_display(type: :total_votes, threshold: 999)).to be_nil
    end
  end

  describe "#milestone_share_url" do
    it "builds an X (Twitter) intent URL with the share text and site URL" do
      url = helper.milestone_share_url("ヨミスロで記録10件達成🎉")

      expect(url).to start_with("https://twitter.com/intent/tweet?")
      expect(url).to include(CGI.escape("ヨミスロで記録10件達成🎉 #ヨミスロ #パチスロ"))
      expect(url).to include("url=#{CGI.escape(helper.root_url)}")
    end
  end
end
