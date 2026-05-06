class CourseOutline < ApplicationRecord
  belongs_to :course_brief
  belongs_to :user

  validates :title,      presence: true
  validates :body,       presence: true
  validates :gemini_raw, presence: true

  before_save :clear_sibling_drafts, if: -> { is_draft_changed? && is_draft? }

  def module_count
    body.scan(/^## Module/).count
  end

  private

  def clear_sibling_drafts
    course_brief.course_outlines
                .where.not(id: id)
                .where(is_draft: true)
                .update_all(is_draft: false)
  end
end
