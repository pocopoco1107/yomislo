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

  describe ".register!" do
    let(:base) { Date.new(2026, 6, 1) }

    it "creates the pet on the first register! for a token" do
      expect { Pet.register!(voter_token: "new_token", recorded_on: base) }
        .to change { Pet.count }.by(1)
    end

    it "hatches egg→baby on the first record" do
      res = Pet.register!(voter_token: "t_hatch", recorded_on: base)
      expect(res).to be_evolved
      expect(res.from_stage).to eq("egg")
      expect(res.to_stage).to eq("baby")
      expect(res.pet.exp).to eq(1)
      expect(res.pet.streak_days).to eq(1)
    end

    it "evolves to child by cumulative count (exp >= 7)" do
      res = Pet.register!(voter_token: "t_count", recorded_on: base, count: 7)
      expect(res.pet.exp).to eq(7)
      expect(res.pet.streak_days).to eq(1)
      expect(res.pet.stage).to eq("child")
    end

    it "evolves to child by streak (3 consecutive days) with low exp" do
      Pet.register!(voter_token: "t_streak", recorded_on: base)
      Pet.register!(voter_token: "t_streak", recorded_on: base + 1)
      res = Pet.register!(voter_token: "t_streak", recorded_on: base + 2)
      expect(res.pet.exp).to eq(3)
      expect(res.pet.streak_days).to eq(3)
      expect(res.pet.stage).to eq("child")
    end

    it "skips stages to the highest qualified (egg→adult)" do
      res = Pet.register!(voter_token: "t_skip", recorded_on: base, count: 30)
      expect(res).to be_evolved
      expect(res.from_stage).to eq("egg")
      expect(res.to_stage).to eq("adult")
    end

    it "does not grow streak for same-day records but still adds exp" do
      Pet.register!(voter_token: "t_same", recorded_on: base)
      res = Pet.register!(voter_token: "t_same", recorded_on: base)
      expect(res.pet.exp).to eq(2)
      expect(res.pet.streak_days).to eq(1)
      expect(res).not_to be_evolved
      expect(res.from_stage).to be_nil
    end

    it "resets streak to 1 after a gap of 2+ days" do
      Pet.register!(voter_token: "t_gap", recorded_on: base)
      Pet.register!(voter_token: "t_gap", recorded_on: base + 1)
      res = Pet.register!(voter_token: "t_gap", recorded_on: base + 3)
      expect(res.pet.streak_days).to eq(1)
      expect(res.pet.exp).to eq(3)
    end

    it "ignores streak for back-dated records (recorded_on < last_recorded_on)" do
      Pet.register!(voter_token: "t_back", recorded_on: base + 9)
      res = Pet.register!(voter_token: "t_back", recorded_on: base)
      expect(res.pet.streak_days).to eq(1)
      expect(res.pet.last_recorded_on).to eq(base + 9)
      expect(res.pet.exp).to eq(2)
    end

    it "never downgrades stage when the streak later resets" do
      Pet.register!(voter_token: "t_keep", recorded_on: base, count: 30)
      res = Pet.register!(voter_token: "t_keep", recorded_on: base + 10)
      expect(res.pet.stage).to eq("adult")
      expect(res).not_to be_evolved
    end
  end

  describe "#apply_record" do
    it "is a no-op for count < 1" do
      pet = create(:pet)
      expect(pet.apply_record(recorded_on: Date.current, count: 0)).to be_nil
      expect(pet.exp).to eq(0)
    end

    it "accepts a string date" do
      pet = create(:pet)
      pet.apply_record(recorded_on: "2026-06-01")
      expect(pet.last_recorded_on).to eq(Date.new(2026, 6, 1))
    end
  end
end
