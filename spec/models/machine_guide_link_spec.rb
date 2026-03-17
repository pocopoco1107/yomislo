require "rails_helper"

RSpec.describe MachineGuideLink, type: :model do
  let(:machine) { create(:machine_model) }

  describe "validations" do
    it "is valid with required attributes" do
      link = build(:machine_guide_link, machine_model: machine)
      expect(link).to be_valid
    end

    it "requires url" do
      link = build(:machine_guide_link, machine_model: machine, url: nil)
      expect(link).not_to be_valid
    end

    it "requires source" do
      link = build(:machine_guide_link, machine_model: machine, source: nil)
      expect(link).not_to be_valid
    end

    it "rejects invalid URL format" do
      link = build(:machine_guide_link, machine_model: machine, url: "not-a-url")
      expect(link).not_to be_valid
    end

    it "enforces uniqueness of url per machine_model" do
      create(:machine_guide_link, machine_model: machine, url: "https://example.com/page")
      dup = build(:machine_guide_link, machine_model: machine, url: "https://example.com/page")
      expect(dup).not_to be_valid
    end

    it "allows same url for different machines" do
      other_machine = create(:machine_model)
      create(:machine_guide_link, machine_model: machine, url: "https://example.com/page")
      link = build(:machine_guide_link, machine_model: other_machine, url: "https://example.com/page")
      expect(link).to be_valid
    end
  end

  describe "enums" do
    it "has link_type enum" do
      link = build(:machine_guide_link, link_type: :ceiling)
      expect(link).to be_ceiling
    end

    it "has status enum" do
      link = build(:machine_guide_link, status: :approved)
      expect(link).to be_approved
    end
  end

  describe "#link_type_label" do
    it "returns Japanese label for analysis" do
      link = build(:machine_guide_link, link_type: :analysis)
      expect(link.link_type_label).to eq("解析")
    end

    it "returns Japanese label for ceiling" do
      link = build(:machine_guide_link, link_type: :ceiling)
      expect(link.link_type_label).to eq("天井・期待値")
    end

    it "returns Japanese label for trophy" do
      link = build(:machine_guide_link, link_type: :trophy)
      expect(link.link_type_label).to eq("トロフィー・設定判別")
    end
  end

  describe "scopes" do
    it ".approved returns only approved links" do
      approved = create(:machine_guide_link, machine_model: machine, status: :approved)
      _pending = create(:machine_guide_link, machine_model: machine, status: :pending)
      expect(MachineGuideLink.approved).to eq([ approved ])
    end
  end

  describe "association" do
    it "belongs to machine_model" do
      link = create(:machine_guide_link, machine_model: machine)
      expect(link.machine_model).to eq(machine)
    end

    it "is destroyed when machine_model is destroyed" do
      link = create(:machine_guide_link, machine_model: machine)
      machine.destroy
      expect(MachineGuideLink.exists?(link.id)).to be false
    end
  end
end
