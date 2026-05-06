require "rails_helper"

RSpec.describe CourseOutline, type: :model do
  describe "validations" do
    it "is valid with all required fields" do
      expect(build(:course_outline)).to be_valid
    end

    it "requires title" do
      expect(build(:course_outline, title: nil)).not_to be_valid
    end

    it "requires body" do
      expect(build(:course_outline, body: nil)).not_to be_valid
    end

    it "requires gemini_raw" do
      expect(build(:course_outline, gemini_raw: nil)).not_to be_valid
    end

    it "is invalid without a course_brief" do
      expect(build(:course_outline, course_brief: nil)).not_to be_valid
    end

    it "is invalid without a user" do
      expect(build(:course_outline, user: nil)).not_to be_valid
    end
  end

  describe "sibling draft clearing" do
    let(:brief) { create(:course_brief) }
    let(:user)  { brief.user }

    it "clears is_draft on sibling outlines when setting is_draft: true" do
      first  = create(:course_outline, :draft, course_brief: brief, user: user)
      second = create(:course_outline, course_brief: brief, user: user, is_draft: false)

      second.update!(is_draft: true)

      expect(first.reload.is_draft).to be false
      expect(second.reload.is_draft).to be true
    end

    it "does not affect outlines belonging to a different brief" do
      other_brief   = create(:course_brief, user: user)
      other_outline = create(:course_outline, :draft, course_brief: other_brief, user: user)
      outline       = create(:course_outline, course_brief: brief, user: user, is_draft: false)

      outline.update!(is_draft: true)

      expect(other_outline.reload.is_draft).to be true
    end

    it "does not fire when is_draft stays false" do
      sibling = create(:course_outline, :draft, course_brief: brief, user: user)
      outline = create(:course_outline, course_brief: brief, user: user, is_draft: false)

      outline.update!(title: "Updated title")

      expect(sibling.reload.is_draft).to be true
    end
  end

  describe "#module_count" do
    it "counts ## Module headings in body" do
      body = <<~MD
        # Course Title

        ## Module 1: First
        ## Module 2: Second
        ## Module 3: Third
      MD
      outline = build(:course_outline, body: body)
      expect(outline.module_count).to eq(3)
    end

    it "returns 0 when no modules are present" do
      outline = build(:course_outline, body: "# Title\n\nNo modules here.")
      expect(outline.module_count).to eq(0)
    end
  end
end
