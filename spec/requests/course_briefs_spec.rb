require "rails_helper"

RSpec.describe "CourseBriefs", type: :request do
  let(:user) { create(:user) }
  let(:brief_params) do
    { course_brief: { topic: "Python Basics", target_audience: "Beginners", skill_level: "beginner", extra_notes: "" } }
  end

  describe "GET /course_briefs/new" do
    context "when authenticated" do
      it "renders the form" do
        sign_in_as(user)
        get new_course_brief_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get new_course_brief_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "POST /course_briefs" do
    context "with a successful Gemini response" do
      it "creates a brief and a draft outline, then redirects to show" do
        sign_in_as(user)
        gemini_returns(SAMPLE_OUTLINE)

        expect {
          post course_briefs_path, params: brief_params
        }.to change(CourseBrief, :count).by(1)
          .and change(CourseOutline, :count).by(1)

        new_brief   = CourseBrief.order(created_at: :desc).first
        new_outline = new_brief.course_outlines.first
        expect(new_outline.is_draft).to be true
        expect(new_outline.title).to eq("Python for Data Analysis")
        expect(response).to redirect_to(course_brief_path(new_brief))
      end
    end

    context "when Gemini raises GeminiError" do
      it "does not persist the brief or outline" do
        sign_in_as(user)
        gemini_raises(GeminiService::GeminiError)

        expect {
          post course_briefs_path, params: brief_params
        }.not_to change(CourseBrief, :count)

        expect(CourseOutline.count).to eq(0)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /course_briefs/:id/regenerate" do
    let(:brief)   { create(:course_brief, user: user) }
    let!(:outline) { create(:course_outline, :draft, course_brief: brief, user: user) }

    it "creates a second outline with is_draft false and redirects to brief" do
      sign_in_as(user)
      gemini_returns(SAMPLE_OUTLINE)

      expect {
        post regenerate_course_brief_path(brief)
      }.to change(CourseOutline, :count).by(1)

      expect(brief.course_outlines.where(is_draft: false).count).to eq(1)
      expect(response).to redirect_to(course_brief_path(brief))
    end
  end

  describe "GET /course_briefs/:id/compare" do
    let(:brief)    { create(:course_brief, user: user) }
    let(:outline1) { create(:course_outline, course_brief: brief, user: user) }
    let(:outline2) { create(:course_outline, course_brief: brief, user: user) }

    it "renders the compare page with two valid outline IDs" do
      sign_in_as(user)
      get compare_course_brief_path(brief), params: { outline_ids: [outline1.id, outline2.id] }
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 when the outlines belong to another user" do
      other_user    = create(:user)
      other_brief   = create(:course_brief, user: other_user)
      other_outline1 = create(:course_outline, course_brief: other_brief, user: other_user)
      other_outline2 = create(:course_outline, course_brief: other_brief, user: other_user)

      sign_in_as(user)
      get compare_course_brief_path(brief), params: { outline_ids: [other_outline1.id, other_outline2.id] }
      expect(response).to have_http_status(:not_found)
    end
  end
end
