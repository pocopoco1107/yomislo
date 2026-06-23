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

  describe ".for" do
    it "creates an egg when no pet exists for the token" do
      expect { Pet.for("new_visitor") }.to change { Pet.count }.by(1)
      expect(Pet.find_by(voter_token: "new_visitor")).to be_egg
    end

    it "returns the existing pet without creating a new one" do
      existing = create(:pet, voter_token: "existing_visitor", stage: :child)
      expect { @pet = Pet.for("existing_visitor") }.not_to change { Pet.count }
      expect(@pet.id).to eq(existing.id)
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

  describe "#mood" do
    let(:today) { Date.new(2026, 6, 10) }

    it "is lonely when never recorded" do
      expect(build(:pet, last_recorded_on: nil).mood(today)).to eq(:lonely)
    end

    it "is genki within 3 days" do
      expect(build(:pet, last_recorded_on: today - 3).mood(today)).to eq(:genki)
    end

    it "is normal between 4 and 7 days" do
      expect(build(:pet, last_recorded_on: today - 5).mood(today)).to eq(:normal)
    end

    it "is lonely at 8+ days" do
      expect(build(:pet, last_recorded_on: today - 8).mood(today)).to eq(:lonely)
    end
  end

  describe "#next_evolution" do
    it "reports remaining count and days to the next stage" do
      pet = build(:pet, stage: :baby, exp: 1, streak_days: 1)
      evo = pet.next_evolution
      expect(evo[:stage_label]).to eq("成長期")
      expect(evo[:exp_remaining]).to eq(6)
      expect(evo[:days_remaining]).to eq(2)
    end

    it "omits days for the egg→baby step (no streak threshold)" do
      evo = build(:pet, stage: :egg).next_evolution
      expect(evo[:exp_remaining]).to eq(1)
      expect(evo[:days_remaining]).to be_nil
    end

    it "returns nil at the final stage" do
      expect(build(:pet, stage: :adult).next_evolution).to be_nil
    end
  end

  describe "labels and image" do
    it "returns the Japanese stage label" do
      expect(build(:pet, stage: :child).stage_label).to eq("成長期")
    end

    it "points at the stage image under companions/" do
      expect(build(:pet, stage: :adult).image_name).to eq("companions/adult.png")
    end

    it "builds an accessible alt text" do
      pet = build(:pet, stage: :baby, last_recorded_on: Date.current)
      expect(pet.alt_text).to eq("あなたのペット（幼年期・ごきげん）")
    end
  end
end
