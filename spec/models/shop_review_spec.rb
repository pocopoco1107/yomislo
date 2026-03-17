require "rails_helper"

RSpec.describe ShopReview, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      review = build(:shop_review)
      expect(review).to be_valid
    end

    it "requires voter_token" do
      review = build(:shop_review, voter_token: nil)
      expect(review).not_to be_valid
      expect(review.errors[:voter_token]).to be_present
    end

    it "requires rating" do
      review = build(:shop_review, rating: nil)
      expect(review).not_to be_valid
    end

    it "requires rating between 1 and 5" do
      expect(build(:shop_review, rating: 0)).not_to be_valid
      expect(build(:shop_review, rating: 6)).not_to be_valid
      expect(build(:shop_review, rating: 1)).to be_valid
      expect(build(:shop_review, rating: 5)).to be_valid
    end

    it "requires body" do
      review = build(:shop_review, body: "")
      expect(review).not_to be_valid
    end

    it "limits body to 500 characters" do
      review = build(:shop_review, body: "a" * 501)
      expect(review).not_to be_valid
    end

    it "limits title to 50 characters" do
      review = build(:shop_review, title: "a" * 51)
      expect(review).not_to be_valid
    end

    it "limits reviewer_name to 20 characters" do
      review = build(:shop_review, reviewer_name: "a" * 21)
      expect(review).not_to be_valid
    end

    it "enforces one review per voter_token per shop" do
      review1 = create(:shop_review)
      review2 = build(:shop_review, shop: review1.shop, voter_token: review1.voter_token)
      expect(review2).not_to be_valid
    end

    it "allows same voter_token for different shops" do
      review1 = create(:shop_review)
      review2 = build(:shop_review, voter_token: review1.voter_token)
      expect(review2).to be_valid
    end
  end

  describe "enums" do
    it "defines category enum" do
      expect(ShopReview.categories).to include(
        "atmosphere" => 0,
        "service" => 1,
        "equipment" => 2,
        "payout" => 3,
        "access" => 4
      )
    end
  end

  describe "#display_name" do
    it "returns reviewer_name when present" do
      review = build(:shop_review, reviewer_name: "太郎")
      expect(review.display_name).to eq("太郎")
    end

    it "returns default when reviewer_name is blank" do
      review = build(:shop_review, reviewer_name: "")
      expect(review.display_name).to eq("名無し")
    end
  end

  describe "#category_label" do
    it "returns Japanese label for category" do
      review = build(:shop_review, category: :service)
      expect(review.category_label).to eq("接客")
    end
  end

  describe ".average_rating_for" do
    it "returns average rating for a shop" do
      shop = create(:shop)
      create(:shop_review, shop: shop, rating: 4, voter_token: "token_a")
      create(:shop_review, shop: shop, rating: 2, voter_token: "token_b")
      expect(ShopReview.average_rating_for(shop.id)).to eq(3.0)
    end

    it "returns nil when no reviews exist" do
      shop = create(:shop)
      expect(ShopReview.average_rating_for(shop.id)).to be_nil
    end
  end

  describe "scopes" do
    it "orders by recent" do
      shop = create(:shop)
      old_review = create(:shop_review, shop: shop, voter_token: "old_tok", created_at: 1.day.ago)
      new_review = create(:shop_review, shop: shop, voter_token: "new_tok", created_at: Time.current)
      expect(ShopReview.recent).to eq([ new_review, old_review ])
    end
  end
end
