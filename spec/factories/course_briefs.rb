FactoryBot.define do
  factory :course_brief do
    association :user
    topic           { "Python for Data Analysis" }
    target_audience { "Business analysts who know Excel" }
    skill_level     { "beginner" }
    extra_notes     { "" }
  end
end
