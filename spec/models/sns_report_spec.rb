require "rails_helper"

RSpec.describe SnsReport, type: :model do
  let(:machine) { create(:machine_model) }

  it "is valid with required attributes" do
    report = SnsReport.new(
      machine_model: machine,
      source: "rss",
      raw_text: "北斗の拳で金トロフィー出現"
    )
    expect(report).to be_valid
  end

  it "requires source" do
    report = SnsReport.new(machine_model: machine, raw_text: "text")
    expect(report).not_to be_valid
  end

  it "requires raw_text" do
    report = SnsReport.new(machine_model: machine, source: "rss")
    expect(report).not_to be_valid
  end

  it "validates source inclusion" do
    report = SnsReport.new(machine_model: machine, source: "unknown_source", raw_text: "text")
    expect(report).not_to be_valid
  end

  it "accepts twitter as source" do
    report = SnsReport.new(machine_model: machine, source: "twitter", raw_text: "text")
    expect(report).to be_valid
  end

  it "accepts google_cse as source" do
    report = SnsReport.new(machine_model: machine, source: "google_cse", raw_text: "text")
    expect(report).to be_valid
  end

  it "enforces source_url uniqueness" do
    SnsReport.create!(machine_model: machine, source: "rss", raw_text: "text1", source_url: "https://example.com/1")
    dup = SnsReport.new(machine_model: machine, source: "rss", raw_text: "text2", source_url: "https://example.com/1")
    expect(dup).not_to be_valid
    expect(dup.errors[:source_url]).to be_present
  end

  it "allows multiple blank source_urls" do
    SnsReport.create!(machine_model: machine, source: "rss", raw_text: "text1", source_url: nil)
    report = SnsReport.new(machine_model: machine, source: "rss", raw_text: "text2", source_url: nil)
    expect(report).to be_valid
  end

  describe "scopes" do
    it ".unparsed returns reports with empty structured_data" do
      parsed = SnsReport.create!(machine_model: machine, source: "rss", raw_text: "text", structured_data: { trophies: [] })
      unparsed = SnsReport.create!(machine_model: machine, source: "rss", raw_text: "text2", structured_data: {})
      expect(SnsReport.unparsed).to include(unparsed)
      expect(SnsReport.unparsed).not_to include(parsed)
    end

    it ".by_source filters by source" do
      rss = SnsReport.create!(machine_model: machine, source: "rss", raw_text: "text")
      google = SnsReport.create!(machine_model: machine, source: "google_cse", raw_text: "text")
      expect(SnsReport.by_source("rss")).to include(rss)
      expect(SnsReport.by_source("rss")).not_to include(google)
    end
  end
end
