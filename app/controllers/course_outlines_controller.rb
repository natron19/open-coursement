class CourseOutlinesController < ApplicationController
  before_action :set_outline

  def set_draft
    @outline.update!(is_draft: true)
    redirect_to course_brief_path(@outline.course_brief), notice: "Working draft updated."
  end

  def destroy
    brief = @outline.course_brief
    if brief.course_outlines.count <= 1
      render plain: "Cannot delete the only outline. Delete the entire brief instead.",
             status: :unprocessable_entity
      return
    end
    @outline.destroy
    redirect_to course_brief_path(brief), notice: "Outline deleted."
  end

  private

  def set_outline
    @outline = current_user.course_outlines.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render file: Rails.public_path.join("404.html"), status: :not_found
  end
end
