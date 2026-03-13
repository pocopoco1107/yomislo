require "rails_helper"

RSpec.describe MachineModel, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      machine = build(:machine_model)
      expect(machine).to be_valid
    end

    it "requires name" do
      machine = build(:machine_model, name: nil)
      expect(machine).not_to be_valid
    end

    it "requires unique slug" do
      create(:machine_model, slug: "test-slug")
      machine = build(:machine_model, slug: "test-slug")
      expect(machine).not_to be_valid
    end
  end

  describe ".pachinko_name?" do
    it "detects full-width Ｐ prefix" do
      expect(MachineModel.pachinko_name?("Ｐ大海物語５")).to be true
    end

    it "detects full-width ＣＲ prefix" do
      expect(MachineModel.pachinko_name?("ＣＲ花の慶次")).to be true
    end

    it "detects full-width ｅ prefix" do
      expect(MachineModel.pachinko_name?("ｅ花の慶次")).to be true
    end

    it "detects half-width PA prefix" do
      expect(MachineModel.pachinko_name?("PA海物語")).to be true
    end

    it "detects half-width PF prefix" do
      expect(MachineModel.pachinko_name?("PF戦姫絶唱シンフォギア")).to be true
    end

    it "detects デジハネ keyword" do
      expect(MachineModel.pachinko_name?("デジハネＰ北斗の拳")).to be true
    end

    it "detects 甘デジ keyword" do
      expect(MachineModel.pachinko_name?("P戦国乙女5 甘デジ")).to be true
    end

    it "does not flag slot machines" do
      expect(MachineModel.pachinko_name?("スマスロ北斗の拳")).to be false
      expect(MachineModel.pachinko_name?("Ｌバジリスク絆2")).to be false
      expect(MachineModel.pachinko_name?("マイジャグラーＶ")).to be false
      expect(MachineModel.pachinko_name?("Ｓバジリスク甲賀忍法帖")).to be false
    end
  end

  describe "#auto_deactivate_pachinko" do
    it "sets active to false when saving a pachinko machine" do
      machine = build(:machine_model, name: "Ｐ大海物語５", active: true)
      machine.save!
      expect(machine.active).to be false
    end

    it "keeps active true for slot machines" do
      machine = build(:machine_model, name: "スマスロ北斗の拳", active: true)
      machine.save!
      expect(machine.active).to be true
    end
  end

  describe "#display_type" do
    it "classifies スマスロ as smart_slot" do
      machine = build(:machine_model, name: "スマスロ北斗の拳")
      expect(machine.display_type).to eq(:smart_slot)
    end

    it "classifies Ｌ prefix as smart_slot" do
      machine = build(:machine_model, name: "Ｌバジリスク絆2")
      expect(machine.display_type).to eq(:smart_slot)
    end

    it "classifies ジャグラー as a_type" do
      machine = build(:machine_model, name: "マイジャグラーＶ")
      expect(machine.display_type).to eq(:a_type)
    end

    it "classifies ハナハナ as a_type" do
      machine = build(:machine_model, name: "ハナハナホウオウ 天翔")
      expect(machine.display_type).to eq(:a_type)
    end

    it "classifies Ｓ prefix as medal_at" do
      machine = build(:machine_model, name: "Ｓバジリスク甲賀忍法帖")
      expect(machine.display_type).to eq(:medal_at)
    end

    it "classifies type_detail AT as medal_at" do
      machine = build(:machine_model, name: "からくりサーカス", type_detail: "AT機")
      expect(machine.display_type).to eq(:medal_at)
    end
  end

  describe "#display_type_sort" do
    it "sorts smart_slot before medal_at" do
      smart = build(:machine_model, name: "スマスロ北斗の拳")
      medal = build(:machine_model, name: "Ｓバジリスク甲賀忍法帖")
      expect(smart.display_type_sort).to be < medal.display_type_sort
    end

    it "sorts a_type after medal_at" do
      medal = build(:machine_model, name: "Ｓバジリスク甲賀忍法帖")
      a_type = build(:machine_model, name: "マイジャグラーＶ")
      expect(medal.display_type_sort).to be < a_type.display_type_sort
    end
  end

  describe "#display_type edge cases" do
    it "classifies L prefix (half-width) as smart_slot" do
      machine = build(:machine_model, name: "L北斗の拳")
      expect(machine.display_type).to eq(:smart_slot)
    end

    it "classifies ディスクアップ as a_type" do
      machine = build(:machine_model, name: "ディスクアップ2")
      expect(machine.display_type).to eq(:a_type)
    end

    it "classifies type_detail Aタイプ as a_type regardless of name" do
      machine = build(:machine_model, name: "不明な機種", type_detail: "Aタイプ")
      expect(machine.display_type).to eq(:a_type)
    end

    it "classifies unknown name with no type_detail as other" do
      machine = build(:machine_model, name: "完全オリジナル機種", type_detail: nil)
      expect(machine.display_type).to eq(:other)
    end

    it "classifies is_smart_slot flagged machine as smart_slot regardless of name" do
      machine = build(:machine_model, name: "モンキーターンV", is_smart_slot: true)
      expect(machine.display_type).to eq(:smart_slot)
    end

    it "classifies non-flagged machine with AT type_detail as medal_at" do
      machine = build(:machine_model, name: "モンキーターンV", type_detail: "AT機", is_smart_slot: false)
      expect(machine.display_type).to eq(:medal_at)
    end

    it "returns display_type_label for each type" do
      expect(build(:machine_model, name: "スマスロ北斗の拳").display_type_label).to eq("スマスロ")
      expect(build(:machine_model, name: "Ｓバジリスク甲賀忍法帖").display_type_label).to eq("AT/ART")
      expect(build(:machine_model, name: "マイジャグラーＶ").display_type_label).to eq("Aタイプ")
    end

    it "returns display_type_badge_class for each type" do
      machine = build(:machine_model, name: "スマスロ北斗の拳")
      expect(machine.display_type_badge_class).to include("violet")
    end
  end

  describe ".pachinko_name? edge cases" do
    it "detects ぱちんこ keyword" do
      expect(MachineModel.pachinko_name?("ぱちんこ冬のソナタ")).to be true
    end

    it "detects 羽根モノ keyword" do
      expect(MachineModel.pachinko_name?("羽根モノ新海物語")).to be true
    end

    it "detects CR prefix (half-width)" do
      expect(MachineModel.pachinko_name?("CR花の慶次")).to be true
    end

    it "does not flag machines starting with English words" do
      expect(MachineModel.pachinko_name?("EVANGELION")).to be false
    end

    it "detects スマパチ prefix" do
      expect(MachineModel.pachinko_name?("スマパチ大海物語")).to be true
    end
  end

  describe "#display_type with generation" do
    it "classifies generation 6.5号機 as smart_slot regardless of name" do
      machine = build(:machine_model, name: "モンキーターンV", generation: "6.5号機", is_smart_slot: false)
      expect(machine.display_type).to eq(:smart_slot)
    end

    it "classifies generation 6号機 as medal_at for non-A-type" do
      machine = build(:machine_model, name: "不明な機種", generation: "6号機", is_smart_slot: false)
      expect(machine.display_type).to eq(:medal_at)
    end

    it "still classifies A-type by name even with 6号機 generation" do
      machine = build(:machine_model, name: "マイジャグラーＶ", generation: "6号機", is_smart_slot: false)
      expect(machine.display_type).to eq(:a_type)
    end
  end

  describe "scope .active" do
    it "returns only active machines" do
      active = create(:machine_model, active: true)
      _inactive = create(:machine_model, active: false)

      expect(MachineModel.active).to include(active)
      expect(MachineModel.active).not_to include(_inactive)
    end
  end

  describe "associations" do
    it "has many shops through shop_machine_models" do
      machine = create(:machine_model)
      shop = create(:shop)
      ShopMachineModel.create!(shop: shop, machine_model: machine)

      expect(machine.shops).to include(shop)
    end

    it "has many votes" do
      machine = create(:machine_model)
      vote = create(:vote, machine_model: machine)

      expect(machine.votes).to include(vote)
    end
  end

  describe "#generation_label" do
    it "returns generation when present" do
      machine = build(:machine_model, generation: "6.5号機")
      expect(machine.generation_label).to eq("6.5号機")
    end

    it "returns nil when generation is blank" do
      machine = build(:machine_model, generation: nil)
      expect(machine.generation_label).to be_nil
    end
  end

  describe "#generation_badge_class" do
    it "returns purple for 6.5号機" do
      machine = build(:machine_model, generation: "6.5号機")
      expect(machine.generation_badge_class).to include("purple")
    end

    it "returns indigo for 6号機" do
      machine = build(:machine_model, generation: "6号機")
      expect(machine.generation_badge_class).to include("indigo")
    end

    it "returns teal for 5号機" do
      machine = build(:machine_model, generation: "5号機")
      expect(machine.generation_badge_class).to include("teal")
    end

    it "returns gray fallback for unknown generation" do
      machine = build(:machine_model, generation: "4号機")
      expect(machine.generation_badge_class).to include("gray")
    end
  end

  describe "#payout_rate_display" do
    it "returns range when min and max differ" do
      machine = build(:machine_model, payout_rate_min: 97.9, payout_rate_max: 114.9)
      expect(machine.payout_rate_display).to eq("97.9% ~ 114.9%")
    end

    it "returns single value when min equals max" do
      machine = build(:machine_model, payout_rate_min: 100.0, payout_rate_max: 100.0)
      expect(machine.payout_rate_display).to eq("100.0%")
    end

    it "returns nil when both are blank" do
      machine = build(:machine_model, payout_rate_min: nil, payout_rate_max: nil)
      expect(machine.payout_rate_display).to be_nil
    end

    it "returns single value when only min is present" do
      machine = build(:machine_model, payout_rate_min: 97.9, payout_rate_max: nil)
      expect(machine.payout_rate_display).to eq("97.9%")
    end
  end

  describe "#effective_introduced_on" do
    it "returns introduced_on when present" do
      machine = build(:machine_model, introduced_on: Date.new(2025, 6, 1))
      expect(machine.effective_introduced_on).to eq(Date.new(2025, 6, 1))
    end

    it "returns nil when introduced_on is blank" do
      machine = build(:machine_model, introduced_on: nil)
      expect(machine.effective_introduced_on).to be_nil
    end
  end

  describe "#smart_slot?" do
    it "returns true for smart slot machines" do
      machine = build(:machine_model, name: "スマスロ北斗の拳")
      expect(machine.smart_slot?).to be true
    end

    it "returns false for non-smart slot machines" do
      machine = build(:machine_model, name: "マイジャグラーＶ")
      expect(machine.smart_slot?).to be false
    end
  end
end
