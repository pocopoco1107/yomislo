require "rails_helper"

# PtownScraper モジュールは lib/tasks/ptown.rake で定義されている
Rails.application.load_tasks unless defined?(PtownScraper)

RSpec.describe PtownScraper do
  describe ".parse_basic_info_table" do
    def parse(fixture_name)
      path = Rails.root.join("spec/fixtures/ptown/#{fixture_name}")
      raise "fixture not found: #{path}" unless File.exist?(path)
      doc = Nokogiri::HTML.parse(File.read(path), nil, "UTF-8")
      described_class.parse_basic_info_table(doc)
    end

    context "with a shop that has rich facilities (smoking + slot + sokuslo)" do
      let(:result) { parse("shop_with_smoking_areas.html") }

      it "marks facility_parsed_at" do
        expect(result[:facility_parsed_at]).to be_present
      end

      it "detects all smoking-related flags" do
        expect(result[:facility_attrs][:heated_tobacco_ok]).to eq(true)
        expect(result[:facility_attrs][:slot_smoking_ok]).to eq(true)
      end

      it "detects service flags" do
        expect(result[:facility_attrs][:wifi_available]).to eq(true)
        expect(result[:facility_attrs][:charging_available]).to eq(true)
      end

      it "detects feature flags" do
        expect(result[:facility_attrs][:low_rate_slot]).to eq(true)
        expect(result[:facility_attrs][:data_publishing]).to eq(true)
        expect(result[:facility_attrs][:okislot]).to eq(true)
      end

      it "parses entry_method and ticket_distribution" do
        expect(result[:facility_attrs][:entry_method]).to eq("queue")
        expect(result[:facility_attrs][:ticket_distribution]).to eq(true)
      end

      it "extracts parking_spaces from the table" do
        expect(result[:parking_spaces]).to eq(280)
      end
    end

    context "with a major chain shop (Maruhan)" do
      let(:result) { parse("shop_marhan.html") }

      it "marks open_year_round true" do
        expect(result[:facility_attrs][:open_year_round]).to eq(true)
      end

      it "captures regular_holiday raw text" do
        expect(result[:regular_holiday]).to include("年中無休")
      end

      it "detects entry_method as lottery" do
        expect(result[:facility_attrs][:entry_method]).to eq("lottery")
      end

      it "leaves unset facilities as nil (not false)" do
        # マルハンには加熱式・スロ喫煙可・Wi-Fi・データ公開の表記がない
        expect(result[:facility_attrs][:heated_tobacco_ok]).to be_nil
        expect(result[:facility_attrs][:slot_smoking_ok]).to be_nil
        expect(result[:facility_attrs][:wifi_available]).to be_nil
        expect(result[:facility_attrs][:data_publishing]).to be_nil
      end
    end

    context "with a minimal shop (few facilities listed)" do
      let(:result) { parse("shop_minimal.html") }

      it "marks facility_parsed_at when at least one relevant section exists" do
        expect(result[:facility_parsed_at]).to be_present
      end

      it "returns nil for all facility flags except entry_method" do
        attrs = result[:facility_attrs]
        %i[heated_tobacco_ok slot_smoking_ok low_rate_slot wifi_available
           charging_available data_publishing okislot open_year_round].each do |key|
          expect(attrs[key]).to be_nil, "#{key} was #{attrs[key].inspect}, expected nil"
        end
      end
    end

    context "when the table is missing entirely" do
      it "returns empty result with no side effects" do
        doc = Nokogiri::HTML.parse("<html><body><p>no table here</p></body></html>")
        result = described_class.parse_basic_info_table(doc)
        expect(result[:facility_parsed_at]).to be_nil
        expect(result[:facility_attrs]).to eq({})
        expect(result[:parking_spaces]).to be_nil
        expect(result[:regular_holiday]).to be_nil
      end
    end
  end

  describe ".keyword_present?" do
    it "returns true when a keyword is present without negation" do
      expect(described_class.keyword_present?("Wi-Fi利用可 携帯電話充電可能", [ "Wi-Fi" ])).to eq(true)
    end

    it "returns false when a negation appears near the keyword" do
      expect(described_class.keyword_present?("Wi-Fi なし", [ "Wi-Fi" ])).to eq(false)
      expect(described_class.keyword_present?("充電 不可", [ "充電" ])).to eq(false)
    end

    it "returns nil when no keyword matches" do
      expect(described_class.keyword_present?("駐車場あり 駐輪場あり", [ "Wi-Fi" ])).to be_nil
    end

    it "is robust to blank text" do
      expect(described_class.keyword_present?("", [ "Wi-Fi" ])).to be_nil
      expect(described_class.keyword_present?(nil, [ "Wi-Fi" ])).to be_nil
    end

    it "tries multiple positives and returns true on the first match" do
      expect(described_class.keyword_present?("20円スロット喫煙可", [ "20円スロット喫煙可", "5円スロット喫煙可" ])).to eq(true)
      expect(described_class.keyword_present?("5円スロット喫煙可", [ "20円スロット喫煙可", "5円スロット喫煙可" ])).to eq(true)
    end
  end
end
