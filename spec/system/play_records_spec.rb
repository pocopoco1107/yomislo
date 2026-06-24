require "rails_helper"

RSpec.describe "Play Records calendar page", type: :system do
  let!(:prefecture) { create(:prefecture, name: "東京都", slug: "tokyo") }
  let!(:shop) { create(:shop, name: "テスト店舗B", slug: "test-shop-b", prefecture: prefecture) }
  let!(:machine) { create(:machine_model, name: "テスト機種B", slug: "test-machine-b") }
  let(:voter_token) { "system_test_token_123" }

  before do
    # Set up voter_token cookie by creating a vote first (which auto-assigns cookie)
    page.driver.browser.set_cookie("voter_token=#{voter_token}")
  end

  describe "calendar page display" do
    it "displays the calendar page with title and summary cards" do
      visit play_records_path

      expect(page).to have_content("収支カレンダー")
      expect(page).to have_content("今月の収支")
      expect(page).to have_content("勝率")
      expect(page).to have_content("稼働日数")
      expect(page).to have_content("累計収支")
    end

    it "displays day-of-week headers in the calendar" do
      visit play_records_path

      %w[日 月 火 水 木 金 土].each do |day_name|
        expect(page).to have_content(day_name)
      end
    end

    it "shows the record form" do
      visit play_records_path

      expect(page).to have_content("収支を記録")
      expect(page).to have_button("記録する")
    end
  end

  describe "month navigation" do
    it "has a previous month link" do
      visit play_records_path

      prev_month = (Date.current.beginning_of_month - 1.month).strftime("%Y-%m")
      expect(page).to have_link("前月", href: play_records_path(month: prev_month))
    end

    it "displays the current month label" do
      visit play_records_path

      expected_label = Date.current.strftime("%Y年%-m月")
      expect(page).to have_content(expected_label)
    end

    it "navigates to previous month when clicking the link" do
      visit play_records_path

      click_link "前月"

      prev_month = Date.current.beginning_of_month - 1.month
      expect(page).to have_content(prev_month.strftime("%Y年%-m月"))
    end

    it "shows next month link when viewing a past month" do
      past_month = (Date.current - 2.months).strftime("%Y-%m")
      visit play_records_path(month: past_month)

      expect(page).to have_link("次月")
    end

    it "disables next month link when viewing the current month" do
      visit play_records_path

      # Next month link should not be present as a link (it's a disabled span)
      next_month = (Date.current.beginning_of_month + 1.month).strftime("%Y-%m")
      expect(page).not_to have_link("次月", href: play_records_path(month: next_month))
    end
  end

  describe "with existing records" do
    before do
      PlayRecord.create!(
        voter_token: voter_token,
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 15_000,
        memo: "大勝ちメモ"
      )
    end

    it "displays record details in the monthly list" do
      visit play_records_path

      expect(page).to have_content("テスト店舗B")
      expect(page).to have_content("テスト機種B")
      expect(page).to have_content("15,000")
    end

    it "shows the empty state message when no records exist for a past month" do
      past_month = (Date.current - 3.months).strftime("%Y-%m")
      visit play_records_path(month: past_month)

      expect(page).to have_content("まだ収支記録がありません")
    end
  end
end
