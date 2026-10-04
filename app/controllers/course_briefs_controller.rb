class CourseBriefsController < ApplicationController
  before_action :set_brief, only: [:show, :destroy, :regenerate, :compare]

  rate_limit to: 10, within: 1.minute, only: [:create, :regenerate],
             with: -> { redirect_to dashboard_path, alert: "Please wait before generating again." }

  def new
    @brief = CourseBrief.new
  end

  def create
    @brief = current_user.course_briefs.build(brief_params)
    if @brief.save
      result = GeminiService.generate(
        template: "coursement_outline_v1",
        variables: {
          topic:           @brief.topic,
          target_audience: @brief.target_audience,
          skill_level:     @brief.skill_level,
          extra_notes:     @brief.extra_notes.to_s
        }
      )
      outline = build_outline(result, is_draft: true)
      if outline.save
        redirect_to course_brief_path(@brief), notice: "Outline generated."
      else
        @brief.destroy
        flash.now[:alert] = "Could not save the outline. Please try again."
        render :new, status: :unprocessable_entity
      end
    else
      render :new, status: :unprocessable_entity
    end
  rescue GeminiService::BudgetExceededError
    @brief.destroy
    render "shared/ai_error_page", locals: { error_type: :budget_exceeded }, status: :unprocessable_entity
  rescue GeminiService::GatekeeperError
    @brief.destroy
    render "shared/ai_error_page", locals: { error_type: :gatekeeper_blocked }, status: :unprocessable_entity
  rescue GeminiService::TimeoutError
    @brief.destroy
    render "shared/ai_error_page", locals: { error_type: :timeout }, status: :unprocessable_entity
  rescue GeminiService::GeminiError
    @brief.destroy
    render "shared/ai_error_page", locals: { error_type: :error }, status: :unprocessable_entity
  end

  def show
    @outlines = @brief.course_outlines.order(created_at: :desc)
  end

  def destroy
    @brief.destroy
    redirect_to dashboard_path, notice: "Brief and all outlines deleted."
  end

  def regenerate
    result = GeminiService.generate(
      template: "coursement_outline_v1",
      variables: {
        topic:           @brief.topic,
        target_audience: @brief.target_audience,
        skill_level:     @brief.skill_level,
        extra_notes:     @brief.extra_notes.to_s
      }
    )
    outline = build_outline(result, is_draft: false)
    if outline.save
      redirect_to course_brief_path(@brief), notice: "New outline generated."
    else
      redirect_to course_brief_path(@brief), alert: "Could not save the new outline."
    end
  rescue GeminiService::BudgetExceededError
    redirect_to course_brief_path(@brief), alert: "Daily outline limit reached. Try again tomorrow."
  rescue GeminiService::GatekeeperError
    redirect_to course_brief_path(@brief), alert: "Your input was flagged. Please revise and try again."
  rescue GeminiService::TimeoutError
    redirect_to course_brief_path(@brief), alert: "Gemini timed out. Please try again."
  rescue GeminiService::GeminiError
    redirect_to course_brief_path(@brief), alert: "Gemini returned an error. Please try again."
  end

  def compare
    ids = Array(params[:outline_ids]).first(2)
    if ids.size != 2
      render plain: "Select exactly two outlines to compare.", status: :unprocessable_entity
      return
    end
    @outlines = ids.map { |id| current_user.course_outlines.find(id) }
  rescue ActiveRecord::RecordNotFound
    render file: Rails.public_path.join("404.html"), status: :not_found
  end

  private

  def set_brief
    @brief = current_user.course_briefs.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render file: Rails.public_path.join("404.html"), status: :not_found
  end

  def brief_params
    params.require(:course_brief).permit(:topic, :target_audience, :skill_level, :extra_notes)
  end

  def build_outline(raw_response, is_draft:)
    title = raw_response.lines.find { |l| l.start_with?("# ") }&.sub(/^# /, "")&.strip || @brief.topic
    @brief.course_outlines.build(
      user:       current_user,
      title:      title,
      body:       raw_response,
      gemini_raw: raw_response,
      is_draft:   is_draft
    )
  end
end
