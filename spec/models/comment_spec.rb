require "rails_helper"

RSpec.describe Comment, type: :model do
  it "is valid with valid attributes" do
    comment = build(:comment)
    expect(comment).to be_valid
  end

  it "requires body" do
    comment = build(:comment, body: nil)
    expect(comment).not_to be_valid
  end

  it "limits body to 500 characters" do
    comment = build(:comment, body: "a" * 501)
    expect(comment).not_to be_valid
  end
end
