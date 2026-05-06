require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  describe "GET /dashboard" do
    context "when authenticated" do
      it "renders the dashboard with the user's briefs" do
        brief = create(:course_brief, user: user)
        sign_in_as(user)
        get dashboard_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(brief.topic)
      end

      it "does not render another user's briefs" do
        other_user  = create(:user)
        other_brief = create(:course_brief, user: other_user)
        sign_in_as(user)
        get dashboard_path
        expect(response.body).not_to include(other_brief.topic)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get dashboard_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end
end
