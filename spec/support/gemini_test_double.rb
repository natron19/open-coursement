SAMPLE_OUTLINE = <<~MD
  # Python for Data Analysis

  **Target Audience:** Business analysts who know Excel
  **Skill Level:** Beginner
  **Estimated Duration:** 6 hours over 6 weeks

  ## Course Overview

  Learners will use Python and Pandas to load, clean, and visualize tabular data.

  ## Module 1: Setting Up Your Environment

  **Learning Objective:** By the end of this module, learners will be able to install Python and run their first notebook.

  Lessons:
  1. Installing Python and Jupyter
  2. Your first notebook
  3. Variables and data types

  ## Module 2: Loading Data with Pandas

  **Learning Objective:** By the end of this module, learners will be able to load CSV files into a DataFrame.

  Lessons:
  1. What is a DataFrame?
  2. Reading CSV files
  3. Inspecting shape and columns
MD

module GeminiTestDouble
  def gemini_returns(text = SAMPLE_OUTLINE)
    allow(GeminiService).to receive(:generate).and_return(text)
  end

  def gemini_raises(error_class, message = "Stubbed error")
    allow(GeminiService).to receive(:generate).and_raise(error_class, message)
  end
end

RSpec.configure do |config|
  config.include GeminiTestDouble
end
