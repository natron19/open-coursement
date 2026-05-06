require "rails_helper"

RSpec.describe CourseBrief, type: :model do
  describe "validations" do
    it "is valid with all required fields" do
      expect(build(:course_brief)).to be_valid
    end

    it "requires topic" do
      expect(build(:course_brief, topic: nil)).not_to be_valid
    end

    it "requires target_audience" do
      expect(build(:course_brief, target_audience: nil)).not_to be_valid
    end

    it "requires skill_level" do
      expect(build(:course_brief, skill_level: nil)).not_to be_valid
    end

    it "rejects skill_level values outside the allowed enum" do
      expect(build(:course_brief, skill_level: "expert")).not_to be_valid
      expect(build(:course_brief, skill_level: "beginner")).to be_valid
      expect(build(:course_brief, skill_level: "intermediate")).to be_valid
      expect(build(:course_brief, skill_level: "advanced")).to be_valid
    end

    it "rejects topic longer than 200 characters" do
      expect(build(:course_brief, topic: "a" * 201)).not_to be_valid
      expect(build(:course_brief, topic: "a" * 200)).to be_valid
    end

    it "rejects extra_notes longer than 1000 characters" do
      expect(build(:course_brief, extra_notes: "a" * 1001)).not_to be_valid
      expect(build(:course_brief, extra_notes: "a" * 1000)).to be_valid
    end

    it "allows blank extra_notes" do
      expect(build(:course_brief, extra_notes: "")).to be_valid
      expect(build(:course_brief, extra_notes: nil)).to be_valid
    end
  end

  describe "#has_draft?" do
    let(:brief) { create(:course_brief) }

    it "returns false when no outline has is_draft: true" do
      create(:course_outline, course_brief: brief, user: brief.user, is_draft: false)
      expect(brief.has_draft?).to be false
    end

    it "returns true when one outline has is_draft: true" do
      create(:course_outline, :draft, course_brief: brief, user: brief.user)
      expect(brief.has_draft?).to be true
    end
  end

  describe "#draft_outline" do
    let(:brief) { create(:course_brief) }

    it "returns nil when no draft exists" do
      create(:course_outline, course_brief: brief, user: brief.user, is_draft: false)
      expect(brief.draft_outline).to be_nil
    end

    it "returns the draft outline" do
      draft = create(:course_outline, :draft, course_brief: brief, user: brief.user)
      expect(brief.draft_outline).to eq(draft)
    end
  end
end
