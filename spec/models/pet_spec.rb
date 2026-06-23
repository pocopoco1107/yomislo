require "rails_helper"

RSpec.describe Pet, type: :model do
  describe "validations" do
    it "is valid with a voter_token" do
      expect(build(:pet)).to be_valid
    end

    it "requires voter_token" do
      expect(build(:pet, voter_token: nil)).not_to be_valid
    end

    it "enforces voter_token uniqueness" do
      create(:pet, voter_token: "dup_token")
      expect(build(:pet, voter_token: "dup_token")).not_to be_valid
    end

    it "rejects negative exp / streak_days / branch_axis" do
      expect(build(:pet, exp: -1)).not_to be_valid
      expect(build(:pet, streak_days: -1)).not_to be_valid
      expect(build(:pet, branch_axis: -1)).not_to be_valid
    end
  end

  describe "defaults" do
    it "starts as an egg with zeroed counters" do
      pet = Pet.create!(voter_token: "fresh_token")
      expect(pet.stage).to eq("egg")
      expect(pet.exp).to eq(0)
      expect(pet.streak_days).to eq(0)
      expect(pet.branch_axis).to eq(0)
      expect(pet.last_recorded_on).to be_nil
    end
  end

  describe "stage enum" do
    it "maps stage keys to the integers stored in the DB" do
      expect(Pet.stages).to eq("egg" => 0, "baby" => 1, "child" => 2, "adult" => 3)
    end

    it "exposes predicate and bang helpers" do
      pet = create(:pet)
      pet.baby!
      expect(pet).to be_baby
      expect(pet.reload.stage).to eq("baby")
    end
  end
end
