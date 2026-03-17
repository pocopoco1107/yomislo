require "rails_helper"

RSpec.describe RecommendationService, type: :service do
  let(:prefecture) { create(:prefecture) }
  let(:shop1) { create(:shop, prefecture: prefecture) }
  let(:shop2) { create(:shop, prefecture: prefecture) }
  let(:machine) { create(:machine_model) }

  describe ".top_nationwide" do
    context "投票データがない場合" do
      it "空配列を返す" do
        results = described_class.top_nationwide(limit: 5)
        expect(results).to eq([])
      end
    end

    context "投票データがある場合" do
      before do
        # shop1: 高設定投票が多い (設定5が5票)
        5.times do |i|
          create(:vote, shop: shop1, machine_model: machine,
                 setting_vote: 5, reset_vote: 1, voter_token: "voter_a_#{i}",
                 voted_on: Date.current)
        end

        # shop2: 低設定投票のみ (設定1が2票)
        2.times do |i|
          create(:vote, shop: shop2, machine_model: machine,
                 setting_vote: 1, reset_vote: 0, voter_token: "voter_b_#{i}",
                 voted_on: Date.current)
        end
      end

      it "スコア順に店舗を返す" do
        results = described_class.top_nationwide(limit: 10)
        expect(results).not_to be_empty
        expect(results.first.shop).to eq(shop1)
      end

      it "Resultオブジェクトにscore, reasonsが含まれる" do
        results = described_class.top_nationwide(limit: 10)
        result = results.first
        expect(result.score).to be_a(Float)
        expect(result.score).to be > 0
        expect(result.reasons).to be_an(Array)
      end

      it "limitで件数を制限できる" do
        results = described_class.top_nationwide(limit: 1)
        expect(results.size).to eq(1)
      end
    end

    context "古いデータ(8日以上前)のみの場合" do
      before do
        # 8日前の投票 → LOOKBACK_DAYS(7日)外
        vote = build(:vote, shop: shop1, machine_model: machine,
                     setting_vote: 6, reset_vote: 1, voter_token: "old_voter",
                     voted_on: Date.current - 8)
        vote.save(validate: false) # voted_on_not_too_old validation skip
        VoteSummary.refresh_for(shop1.id, machine.id, Date.current - 8)
      end

      it "空配列を返す" do
        results = described_class.top_nationwide(limit: 5)
        expect(results).to eq([])
      end
    end
  end

  describe ".top_for_prefecture" do
    let(:other_pref) { create(:prefecture) }
    let(:other_shop) { create(:shop, prefecture: other_pref) }

    before do
      # 対象県の店舗に投票
      3.times do |i|
        create(:vote, shop: shop1, machine_model: machine,
               setting_vote: 5, reset_vote: 1, voter_token: "pref_voter_#{i}",
               voted_on: Date.current)
      end

      # 他県の店舗に投票
      3.times do |i|
        create(:vote, shop: other_shop, machine_model: machine,
               setting_vote: 6, reset_vote: 1, voter_token: "other_voter_#{i}",
               voted_on: Date.current)
      end
    end

    it "指定した都道府県の店舗のみ返す" do
      results = described_class.top_for_prefecture(prefecture, limit: 5)
      expect(results.map { |r| r.shop.prefecture_id }.uniq).to eq([ prefecture.id ])
    end

    it "他県の店舗を含まない" do
      results = described_class.top_for_prefecture(prefecture, limit: 5)
      expect(results.map(&:shop)).not_to include(other_shop)
    end
  end

  describe ".generate_comment" do
    it "高設定理由のコメントを生成する" do
      data = { reasons: [ { type: :high_setting, label: "高設定記録60%", value: 60 } ] }
      comment = described_class.generate_comment(shop1, data)
      expect(comment).to include(shop1.name)
      expect(comment).to include("高設定記録")
    end

    it "記録量理由のコメントを生成する" do
      data = { reasons: [ { type: :vote_volume, label: "記録が多い", value: 20 } ] }
      comment = described_class.generate_comment(shop1, data)
      expect(comment).to include(shop1.name)
      expect(comment).to include("記録が集中")
    end

    it "リセット率理由のコメントを生成する" do
      data = { reasons: [ { type: :reset_rate, label: "リセット率80%", value: 80 } ] }
      comment = described_class.generate_comment(shop1, data)
      expect(comment).to include(shop1.name)
      expect(comment).to include("リセット率")
    end

    it "レビュー評価理由のコメントを生成する" do
      data = { reasons: [ { type: :review_rating, label: "評価4.5", value: 4.5 } ] }
      comment = described_class.generate_comment(shop1, data)
      expect(comment).to include(shop1.name)
      expect(comment).to include("ユーザー評価")
    end

    it "理由が空の場合はnilを返す" do
      comment = described_class.generate_comment(shop1, { reasons: [] })
      expect(comment).to be_nil
    end
  end

  describe "スコア算出ロジック" do
    it "高設定投票が多い店舗ほどスコアが高い" do
      machine2 = create(:machine_model)

      # shop1: 全て設定5
      5.times do |i|
        create(:vote, shop: shop1, machine_model: machine,
               setting_vote: 5, reset_vote: 1, voter_token: "high_#{i}",
               voted_on: Date.current)
      end

      # shop2: 全て設定1
      5.times do |i|
        create(:vote, shop: shop2, machine_model: machine2,
               setting_vote: 1, reset_vote: 0, voter_token: "low_#{i}",
               voted_on: Date.current)
      end

      results = described_class.top_nationwide(limit: 10)
      expect(results.size).to eq(2)
      expect(results.first.shop).to eq(shop1)
      expect(results.first.score).to be > results.last.score
    end

    it "リセット率が高い店舗にリセット理由が付く" do
      5.times do |i|
        create(:vote, shop: shop1, machine_model: machine,
               setting_vote: 3, reset_vote: 1, voter_token: "reset_#{i}",
               voted_on: Date.current)
      end

      results = described_class.top_nationwide(limit: 10)
      result = results.find { |r| r.shop == shop1 }
      reset_reason = result.reasons.find { |r| r[:type] == :reset_rate }
      expect(reset_reason).not_to be_nil
      expect(reset_reason[:label]).to include("リセット率")
    end
  end
end
