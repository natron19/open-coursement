class DashboardController < ApplicationController
  def show
    @briefs = current_user.course_briefs
                          .includes(:course_outlines)
                          .order(created_at: :desc)
  end
end
