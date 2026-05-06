class CourseBrief < ApplicationRecord
  belongs_to :user
  has_many :course_outlines, dependent: :destroy

  SKILL_LEVELS = %w[beginner intermediate advanced].freeze

  validates :topic,           presence: true, length: { maximum: 200 }
  validates :target_audience, presence: true, length: { maximum: 200 }
  validates :skill_level,     presence: true, inclusion: { in: SKILL_LEVELS }
  validates :extra_notes,     length: { maximum: 1000 }, allow_blank: true

  def draft_outline
    course_outlines.find_by(is_draft: true)
  end

  def has_draft?
    course_outlines.exists?(is_draft: true)
  end
end
