FactoryBot.define do
  factory :course_outline do
    association :course_brief
    association :user
    title      { "Python for Data Analysis" }
    body do
      <<~MD
        # Python for Data Analysis

        **Target Audience:** Business analysts who know Excel
        **Skill Level:** Beginner

        ## Course Overview

        Learners will be able to load, clean, and visualize real-world datasets using Python and Pandas.

        ## Module 1: Getting Started with Python

        **Learning Objective:** By the end of this module, learners will be able to set up a Python environment.

        Lessons:
        1. Installing Python and Jupyter
        2. Your first notebook
        3. Running your first script
      MD
    end
    gemini_raw { body }
    is_draft   { false }

    trait :draft do
      is_draft { true }
    end
  end
end
