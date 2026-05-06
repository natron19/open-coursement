require "rails_helper"

RSpec.describe "CourseOutlines", type: :request do
  let(:user)  { create(:user) }
  let(:brief) { create(:course_brief, user: user) }

  describe "PATCH /course_outlines/:id/set_draft" do
    it "sets is_draft to true, clears siblings, and redirects to the brief" do
      current_draft = create(:course_outline, :draft, course_brief: brief, user: user)
      outline       = create(:course_outline, course_brief: brief, user: user, is_draft: false)

      sign_in_as(user)
      patch set_draft_course_outline_path(outline)

      expect(outline.reload.is_draft).to be true
      expect(current_draft.reload.is_draft).to be false
      expect(response).to redirect_to(course_brief_path(brief))
    end

    it "returns 404 for an outline belonging to another user" do
      other_user    = create(:user)
      other_brief   = create(:course_brief, user: other_user)
      other_outline = create(:course_outline, course_brief: other_brief, user: other_user)

      sign_in_as(user)
      patch set_draft_course_outline_path(other_outline)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /course_outlines/:id" do
    it "deletes the outline when the brief has more than one, and redirects to the brief" do
      outline1 = create(:course_outline, course_brief: brief, user: user)
      outline2 = create(:course_outline, course_brief: brief, user: user)

      sign_in_as(user)
      expect {
        delete course_outline_path(outline1)
      }.to change(CourseOutline, :count).by(-1)

      expect(response).to redirect_to(course_brief_path(brief))
    end

    it "returns 422 and does not delete the last outline" do
      outline = create(:course_outline, course_brief: brief, user: user)

      sign_in_as(user)
      expect {
        delete course_outline_path(outline)
      }.not_to change(CourseOutline, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
