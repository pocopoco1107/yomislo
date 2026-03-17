require "rails_helper"

RSpec.describe PlayRecord, type: :model do
  let(:shop) { create(:shop) }
  let(:machine) { create(:machine_model) }

  describe "validations" do
    it "is valid with required attributes" do
      record = build(:play_record, shop: shop, machine_model: machine)
      expect(record).to be_valid
    end

    it "requires voter_token" do
      record = build(:play_record, voter_token: nil)
      expect(record).not_to be_valid
    end

    it "requires played_on" do
      record = build(:play_record, played_on: nil)
      expect(record).not_to be_valid
    end

    it "requires result_amount" do
      record = build(:play_record, result_amount: nil)
      expect(record).not_to be_valid
    end

    describe "result_amount range" do
      it "accepts -999,999" do
        record = build(:play_record, result_amount: -999_999)
        expect(record).to be_valid
      end

      it "accepts 999,999" do
        record = build(:play_record, result_amount: 999_999)
        expect(record).to be_valid
      end

      it "rejects values below -999,999" do
        record = build(:play_record, result_amount: -1_000_000)
        expect(record).not_to be_valid
      end

      it "rejects values above 999,999" do
        record = build(:play_record, result_amount: 1_000_000)
        expect(record).not_to be_valid
      end
    end

    describe "played_on validations" do
      it "rejects future dates" do
        record = build(:play_record, played_on: Date.current + 1.day)
        expect(record).not_to be_valid
        expect(record.errors[:played_on]).to include("は未来の日付にできません")
      end

      it "rejects dates older than 90 days" do
        record = build(:play_record, played_on: 91.days.ago.to_date)
        expect(record).not_to be_valid
        expect(record.errors[:played_on]).to include("は過去90日以内のみ記録できます")
      end

      it "accepts exactly 90 days ago" do
        record = build(:play_record, played_on: 90.days.ago.to_date)
        expect(record).to be_valid
      end

      it "accepts today" do
        record = build(:play_record, played_on: Date.current)
        expect(record).to be_valid
      end

      it "accepts 89 days ago" do
        record = build(:play_record, played_on: 89.days.ago.to_date)
        expect(record).to be_valid
      end
    end

    describe "tags validation" do
      it "accepts valid tags" do
        record = build(:play_record, tags: [ "天井", "朝一" ])
        expect(record).to be_valid
      end

      it "rejects invalid tags" do
        record = build(:play_record, tags: [ "invalid_tag" ])
        expect(record).not_to be_valid
        expect(record.errors[:tags].first).to include("無効なタグ")
      end

      it "rejects when mix of valid and invalid tags" do
        record = build(:play_record, tags: [ "天井", "不正タグ", "朝一" ])
        expect(record).not_to be_valid
        expect(record.errors[:tags].first).to include("不正タグ")
      end

      it "accepts empty tags" do
        record = build(:play_record, tags: [])
        expect(record).to be_valid
      end

      it "accepts nil tags" do
        record = build(:play_record, tags: nil)
        expect(record).to be_valid
      end
    end

    describe "uniqueness constraint" do
      it "prevents duplicate records for same voter/shop/machine/date" do
        create(:play_record, voter_token: "dup_token", shop: shop,
               machine_model: machine, played_on: Date.current)
        dup = build(:play_record, voter_token: "dup_token", shop: shop,
                    machine_model: machine, played_on: Date.current)
        expect(dup).not_to be_valid
        expect(dup.errors[:voter_token]).to include("同店舗同機種同日の記録は1件までです")
      end

      it "allows same voter with different shop" do
        create(:play_record, voter_token: "same_token", shop: shop,
               machine_model: machine, played_on: Date.current)
        other_shop = create(:shop)
        record = build(:play_record, voter_token: "same_token", shop: other_shop,
                       machine_model: machine, played_on: Date.current)
        expect(record).to be_valid
      end

      it "prevents duplicate when machine_model_id is nil for same voter/shop/date" do
        create(:play_record, voter_token: "nil_machine_token", shop: shop,
               machine_model: nil, played_on: Date.current)
        dup = build(:play_record, voter_token: "nil_machine_token", shop: shop,
                    machine_model: nil, played_on: Date.current)
        expect(dup).not_to be_valid
        expect(dup.errors[:voter_token]).to include("同店舗同機種同日の記録は1件までです")
      end
    end

    describe "memo length" do
      it "accepts memo up to 500 characters" do
        record = build(:play_record, memo: "a" * 500)
        expect(record).to be_valid
      end

      it "rejects memo over 500 characters" do
        record = build(:play_record, memo: "a" * 501)
        expect(record).not_to be_valid
      end
    end
  end

  describe "#win?" do
    it "returns true when result_amount is positive" do
      record = build(:play_record, result_amount: 10_000)
      expect(record.win?).to be true
    end

    it "returns false when result_amount is negative" do
      record = build(:play_record, result_amount: -5_000)
      expect(record.win?).to be false
    end

    it "returns false when result_amount is zero" do
      record = build(:play_record, result_amount: 0)
      expect(record.win?).to be false
    end
  end

  describe "#lose?" do
    it "returns true when result_amount is negative" do
      record = build(:play_record, result_amount: -5_000)
      expect(record.lose?).to be true
    end

    it "returns false when result_amount is positive" do
      record = build(:play_record, result_amount: 10_000)
      expect(record.lose?).to be false
    end

    it "returns false when result_amount is zero" do
      record = build(:play_record, result_amount: 0)
      expect(record.lose?).to be false
    end
  end

  describe "scopes" do
    it ".public_records returns only public records" do
      public_rec = create(:play_record, is_public: true)
      private_rec = create(:play_record, is_public: false)
      expect(PlayRecord.public_records).to include(public_rec)
      expect(PlayRecord.public_records).not_to include(private_rec)
    end

    it ".by_month filters by month" do
      this_month = create(:play_record, played_on: Date.current)
      last_month = create(:play_record, played_on: (Date.current - 1.month).beginning_of_month)
      expect(PlayRecord.by_month(Date.current)).to include(this_month)
      expect(PlayRecord.by_month(Date.current)).not_to include(last_month)
    end
  end
end
