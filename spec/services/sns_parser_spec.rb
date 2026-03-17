require "rails_helper"

RSpec.describe SnsParser do
  let(:machine) { create(:machine_model) }

  def build_report(title: "", text: "")
    SnsReport.create!(
      machine_model: machine,
      source: "rss",
      source_title: title,
      raw_text: text
    )
  end

  describe "#parse" do
    it "detects trophy types from text" do
      report = build_report(text: "金トロフィー出現で設定6確定")
      result = described_class.new(report).parse

      expect(result[:trophies]).to include("金トロフィー")
    end

    it "detects multiple trophies" do
      report = build_report(text: "虹トロフィー 金トロフィー エンディング到達")
      result = described_class.new(report).parse

      expect(result[:trophies]).to include("虹トロフィー", "金トロフィー", "エンディング")
    end

    it "detects setting confirmations" do
      report = build_report(text: "設定6確定演出が出た")
      result = described_class.new(report).parse

      expect(result[:settings]).to include("6確定")
    end

    it "detects high confidence from text with 確定" do
      report = build_report(text: "設定6確定")
      result = described_class.new(report).parse

      expect(result[:confidence]).to eq("high")
    end

    it "detects medium confidence from 示唆" do
      report = build_report(text: "高設定示唆演出")
      result = described_class.new(report).parse

      expect(result[:confidence]).to eq("medium")
    end

    it "detects low confidence from ambiguous text" do
      report = build_report(text: "もしかして高い設定かも")
      result = described_class.new(report).parse

      expect(result[:confidence]).to eq("low")
    end

    it "extracts keywords" do
      report = build_report(text: "朝一ガックンで設定判別")
      result = described_class.new(report).parse

      expect(result[:keywords]).to include("朝一", "ガックン", "設定判別")
    end

    it "combines source_title and raw_text" do
      report = build_report(title: "金トロフィー", text: "設定6確定")
      result = described_class.new(report).parse

      expect(result[:trophies]).to include("金トロフィー")
      expect(result[:settings]).to include("6確定")
    end
  end

  describe "#parse!" do
    it "saves structured_data to the report" do
      report = build_report(text: "金トロフィー出現で設定6確定")
      described_class.new(report).parse!

      report.reload
      expect(report.structured_data).to be_present
      expect(report.structured_data["trophies"]).to include("金トロフィー")
    end

    it "updates trophy_type when blank" do
      report = build_report(text: "虹トロフィー出現")
      described_class.new(report).parse!

      report.reload
      expect(report.trophy_type).to eq("虹トロフィー")
    end

    it "does not overwrite existing trophy_type" do
      report = build_report(text: "虹トロフィー出現")
      report.update!(trophy_type: "金トロフィー")

      described_class.new(report).parse!
      report.reload
      expect(report.trophy_type).to eq("金トロフィー")
    end

    it "updates suggested_setting when blank" do
      report = build_report(text: "設定6確定演出")
      described_class.new(report).parse!

      report.reload
      expect(report.suggested_setting).to eq("6確定")
    end

    it "updates confidence from unrated" do
      report = build_report(text: "設定6確定")
      expect(report.confidence).to eq("unrated")

      described_class.new(report).parse!
      report.reload
      expect(report.confidence).to eq("high")
    end

    it "does not downgrade existing confidence" do
      report = build_report(text: "もしかして高い設定かも")
      report.update!(confidence: :high)

      described_class.new(report).parse!
      report.reload
      expect(report.confidence).to eq("high")
    end
  end

  describe "strategy pattern" do
    it "accepts a custom strategy" do
      custom_strategy = double("strategy", call: { trophies: [ "カスタム" ], settings: [], confidence: "high", keywords: [] })
      report = build_report(text: "anything")
      result = described_class.new(report, strategy: custom_strategy).parse

      expect(result[:trophies]).to eq([ "カスタム" ])
    end
  end
end
