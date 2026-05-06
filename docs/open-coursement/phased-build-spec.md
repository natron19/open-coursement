# Coursement Demo — Phased Build Specification

Built on: Open Demo Starter v2.0  
Source spec: `docs/open-coursement/coursement-demo-spec.md`

This document breaks the demo spec into discrete, sequenced implementation phases. Each phase ends with a manual smoke test and a note on which RSpec specs are added. All phases assume the boilerplate is already running (`bin/setup` completed).

Reference guides to consult before implementing each phase:
- `docs/ai-templates.md` — Phase 6
- `docs/ai-guardrails.md` — Phase 6
- `docs/testing.md` — Phase 9
- `docs/turbo-stimulus-patterns.md` — Phases 5, 6

---

## Phase 0: App Configuration & Branding

**Goal:** Make the app identify as Coursement Demo before a single domain model exists.

### Implementation Steps

1. **`.env.example`** — add or update:
   ```
   APP_NAME=Coursement Demo
   APP_TAGLINE=Describe a course topic. Get a complete module-by-module outline in seconds.
   APP_DESCRIPTION=Coursement Demo uses Google Gemini to generate a complete module-by-module course outline from a topic, target audience, and skill level. Eliminate the blank-page problem and start building your course from a structured first draft in seconds.
   GEMINI_API_KEY=your_key_here
   AI_CALLS_PER_USER_PER_DAY=50
   AI_GLOBAL_TIMEOUT_SECONDS=15
   ```

2. **`app/assets/stylesheets/application.css`** — set the accent color variables:
   ```css
   :root {
     --accent: #06b6d4;
     --accent-hover: #0891b2;
   }
   ```
   Also add custom classes:
   ```css
   .badge-draft { background-color: var(--accent); color: #fff; }
   .outline-body { line-height: 1.7; max-width: 72ch; }
   .border-draft { border-left: 3px solid var(--accent) !important; }
   pre.gemini-raw { font-size: 0.8rem; white-space: pre-wrap; word-break: break-word; }
   ```

3. **Navbar** (`app/views/layouts/application.html.erb`) — add two links inside the existing nav (after the brand link, before auth links):
   - "My Courses" → `dashboard_path`
   - "New Outline" → `new_course_brief_path`

   These routes don't exist yet; wrap them in a `if user_signed_in?` guard so the page still renders before auth is wired.

### Manual Smoke Test
- Start the app (`bin/dev` in a separate terminal)
- Visit `/` — confirm page title includes "Coursement Demo" from `ENV.fetch("APP_NAME")`
- Confirm navbar background uses the dark Bootstrap theme (already default)
- Confirm there are no JavaScript errors in the console

---

## Phase 1: Data Models & Migrations

**Goal:** Create `CourseBrief` and `CourseOutline` with all fields, associations, validations, and instance methods. Run migrations. Verify models in the Rails console.

### CourseBrief Migration

```ruby
# db/migrate/TIMESTAMP_create_course_briefs.rb
create_table :course_briefs, id: :uuid do |t|
  t.references :user, null: false, foreign_key: true, type: :uuid
  t.string  :topic,           null: false, limit: 200
  t.string  :target_audience, null: false, limit: 200
  t.string  :skill_level,     null: false
  t.text    :extra_notes
  t.timestamps null: false
end
```

### CourseOutline Migration

```ruby
# db/migrate/TIMESTAMP_create_course_outlines.rb
create_table :course_outlines, id: :uuid do |t|
  t.references :course_brief, null: false, foreign_key: true, type: :uuid
  t.references :user,         null: false, foreign_key: true, type: :uuid
  t.string  :title,      null: false
  t.text    :body,       null: false
  t.boolean :is_draft,   null: false, default: false
  t.text    :gemini_raw, null: false
  t.timestamps null: false
end
add_index :course_outlines, :is_draft
```

### `app/models/course_brief.rb`

```ruby
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
```

### `app/models/course_outline.rb`

```ruby
class CourseOutline < ApplicationRecord
  belongs_to :course_brief
  belongs_to :user

  validates :title,      presence: true
  validates :body,       presence: true
  validates :gemini_raw, presence: true
  validates :user_id,    presence: true

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
```

### Factories

**`spec/factories/course_briefs.rb`**
```ruby
FactoryBot.define do
  factory :course_brief do
    association :user
    topic           { "Python for Data Analysis" }
    target_audience { "Business analysts who know Excel" }
    skill_level     { "beginner" }
    extra_notes     { "" }
  end
end
```

**`spec/factories/course_outlines.rb`**
```ruby
FactoryBot.define do
  factory :course_outline do
    association :course_brief
    association :user
    title      { "Python for Data Analysis" }
    body       { "# Python for Data Analysis\n\n## Module 1: Introduction\n\n**Learning Objective:** ...\n\nLessons:\n1. Getting started\n" }
    gemini_raw { body }
    is_draft   { false }

    trait :draft do
      is_draft { true }
    end
  end
end
```

### Manual Smoke Test
- Run `rails db:migrate`
- Open `rails console`
- `CourseBrief.new.valid?` → false (missing fields)
- `CourseBrief::SKILL_LEVELS` → `["beginner", "intermediate", "advanced"]`
- Create a brief and outline, confirm `has_draft?` and `draft_outline` work

### RSpec Added (Phase 1)
- `spec/models/course_brief_spec.rb` — all 5 cases from spec Section 9
- `spec/models/course_outline_spec.rb` — all 5 cases from spec Section 9

---

## Phase 2: Routes

**Goal:** Add all Coursement-specific routes to `config/routes.rb`. No controllers exist yet; routes just need to resolve.

### Routes to Add

Inside `Rails.application.routes.draw do`, add after the dashboard route:

```ruby
resources :course_briefs, only: [:new, :create, :show, :destroy] do
  member do
    post :regenerate
    get  :compare
  end
end

resources :course_outlines, only: [:destroy] do
  member do
    patch :set_draft
  end
end
```

### Named Route Helpers Produced

| Helper | Path |
|--------|------|
| `new_course_brief_path` | GET /course_briefs/new |
| `course_briefs_path` | POST /course_briefs |
| `course_brief_path(id)` | GET /course_briefs/:id |
| `course_brief_path(id), method: :delete` | DELETE /course_briefs/:id |
| `regenerate_course_brief_path(id)` | POST /course_briefs/:id/regenerate |
| `compare_course_brief_path(id)` | GET /course_briefs/:id/compare |
| `set_draft_course_outline_path(id)` | PATCH /course_outlines/:id/set_draft |
| `course_outline_path(id), method: :delete` | DELETE /course_outlines/:id |

### Manual Smoke Test
- Run `rails routes | grep course`
- Confirm all 8 routes appear with correct verbs, paths, and helper names

---

## Phase 3: Controllers

**Goal:** Create all controller files with correct action signatures, scoping, and strong params. No views yet — actions may raise a template-missing error when visited, which is acceptable.

### `app/controllers/course_briefs_controller.rb`

```ruby
class CourseBriefsController < ApplicationController
  before_action :set_brief, only: [:show, :destroy, :regenerate, :compare]

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
    render partial: "shared/ai_error", locals: { error_type: :budget_exceeded }
  rescue GeminiService::GatekeeperError
    @brief.destroy
    render partial: "shared/ai_error", locals: { error_type: :gatekeeper_blocked }
  rescue GeminiService::TimeoutError
    @brief.destroy
    render partial: "shared/ai_error", locals: { error_type: :timeout }
  rescue GeminiService::GeminiError
    @brief.destroy
    render partial: "shared/ai_error", locals: { error_type: :error }
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
      user:      current_user,
      title:     title,
      body:      raw_response,
      gemini_raw: raw_response,
      is_draft:  is_draft
    )
  end
end
```

### `app/controllers/course_outlines_controller.rb`

```ruby
class CourseOutlinesController < ApplicationController
  before_action :set_outline

  def set_draft
    @outline.update!(is_draft: true)
    redirect_to course_brief_path(@outline.course_brief), notice: "Working draft updated."
  end

  def destroy
    brief = @outline.course_brief
    if brief.course_outlines.count <= 1
      render plain: "Cannot delete the only outline. Delete the entire brief instead.", status: :unprocessable_entity
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
```

### `app/controllers/dashboard_controller.rb` (override)

```ruby
class DashboardController < ApplicationController
  def show
    @briefs = current_user.course_briefs
                          .includes(:course_outlines)
                          .order(created_at: :desc)
  end
end
```

### Manual Smoke Test
- Sign in as demo user
- Visit `/course_briefs/new` — should get a template-missing error (controller exists, view doesn't yet)
- Visit `/dashboard` — should get a template-missing error
- Run `rails routes | grep course` to confirm helpers are correct

---

## Phase 4: Landing Page & Dashboard Views

**Goal:** Override the two boilerplate views so the app looks purposeful before any course data exists.

### `app/views/home/index.html.erb` (override)

Landing page for unauthenticated visitors. Contains:
- App tagline from `ENV.fetch("APP_TAGLINE", "")`
- One-paragraph pitch from `ENV.fetch("APP_DESCRIPTION", "")`
- "Generate your first outline" button → `sign_up_path`
- Static sample outline card (hardcoded HTML) styled with `.card` and `.border-draft`

The sample card should show a realistic-looking outline with a module list so visitors immediately understand the output format.

### `app/views/dashboard/show.html.erb` (override)

Card grid layout:
- Header row: "My Courses" h1 on the left, "New Outline" button on the right → `new_course_brief_path`
- If `@briefs.empty?`: centered empty state with "You haven't generated any outlines yet." and a "Generate your first outline" button
- Otherwise: Bootstrap row with one `.col-md-4` per brief
- Each card shows: topic (card title), skill level badge, outline count, created date, "Draft" badge if `brief.has_draft?`
- Card footer: "View Outlines" link → `course_brief_path(brief)`, "Delete" link → `course_brief_path(brief)` with `data-turbo-method: :delete, data-turbo-confirm: "Delete this brief and all outlines?"`

Skill level badge colors:
- beginner → `badge bg-secondary`
- intermediate → `badge bg-info text-dark`
- advanced → `badge` with inline style using `var(--accent)` (or class `badge-draft`)

### Manual Smoke Test
- Visit `/` — landing page renders, no dynamic data errors
- Sign in as demo user, visit `/dashboard`
- Confirm empty state appears (no seeded data yet)
- Click "New Outline" — routes to `/course_briefs/new` (template missing is OK at this phase)

---

## Phase 5: Course Brief Views (Non-AI)

**Goal:** Build all course brief and outline views. GeminiService is not called yet — this phase tests the full UI skeleton with manually created records.

### `app/views/course_briefs/new.html.erb`

Single-column form page. Renders `_form.html.erb`. Page title: "New Course Outline".

### `app/views/course_briefs/_form.html.erb`

Fields (in order):
1. `topic` — `text_field`, label "Course Topic", placeholder "e.g. Python for Data Analysis with Pandas"
2. `target_audience` — `text_field`, label "Target Audience", placeholder "e.g. Business analysts who know Excel"
3. `skill_level` — Bootstrap radio buttons (inline) for beginner / intermediate / advanced using `radio_button` + `label`; wrap each in `form-check form-check-inline`
4. `extra_notes` — `text_area`, label "Additional Notes (optional)", placeholder "e.g. Emphasize real-world datasets", rows: 3

Submit button: "Generate Outline", class `btn btn-primary` (accent applies via CSS override). Below button: `<p class="text-muted small mt-2">Gemini will generate your outline in a few seconds.</p>`

Validation errors: render `shared/_validation_errors` partial or inline error messages at top of form.

### `app/views/course_briefs/show.html.erb`

Two sections:

**Section 1 — Brief details card**
- Card with brief topic as title
- Body shows: Target Audience, Skill Level (badge), Notes (if present)
- Footer: "Regenerate" button → `POST regenerate_course_brief_path(@brief)` via `button_to`, "Delete Brief" button → `button_to course_brief_path(@brief), method: :delete, data: { turbo_confirm: "Delete this brief and all its outlines?" }`

**Section 2 — Outlines list**
- Header: "Outlines (N)" with outline count
- If `@outlines.count >= 2`: "Compare" form UI — checkboxes and a "Compare Selected" button (see below)
- Each outline rendered via `_outline_card.html.erb` partial

**Compare UI** (Stimulus-free, vanilla approach):
- A `form_tag compare_course_brief_path(@brief), method: :get` wrapping the outline list
- Each outline card has a `check_box_tag "outline_ids[]", outline.id`
- Submit button: "Compare Selected"
- The compare controller validates that exactly 2 IDs were sent

### `app/views/course_briefs/_outline_card.html.erb`

Card with `.border-draft` class applied when `outline.is_draft`. Contains:

- Card header: outline title + "Working Draft" badge (`.badge-draft`) if draft
- Subtitle in muted text: "Review this outline before building your course. Module structure and lesson titles are suggestions, not authoritative curricula."
- Meta: module count, created date
- Body: `outline.body` rendered as Markdown HTML (via Redcarpet helper — see Phase 6) wrapped in `div.outline-body`
- Card footer actions:
  - "Set as Draft" → `button_to set_draft_course_outline_path(outline), method: :patch, class: "btn btn-sm btn-outline-primary"` — hidden if already draft
  - "Delete" → `button_to course_outline_path(outline), method: :delete, data: { turbo_confirm: "Delete this outline?" }, class: "btn btn-sm btn-outline-danger"`
- Bootstrap collapse "Show raw response" toggle:
  ```erb
  <a class="btn btn-sm btn-link" data-bs-toggle="collapse" href="#raw-<%= outline.id %>">
    Show raw response
  </a>
  <div class="collapse" id="raw-<%= outline.id %>">
    <pre class="gemini-raw"><%= outline.gemini_raw %></pre>
  </div>
  ```

### `app/views/course_briefs/compare.html.erb`

- Page title: "Compare: <%= @brief.topic %>"
- "Back to brief" link → `course_brief_path(@brief)`
- Two-column Bootstrap row (`col-md-6` each)
- Each column has a header with outline title in accent color, then renders `_outline_card.html.erb`

### Manual Smoke Test
- In `rails console`, create a brief and two outlines manually for the demo user
- Visit `/course_briefs/:id` — verify outline cards render
- Click "Set as Draft" — verify badge appears on that card, disappears from others
- Click "Compare Selected" with two checkboxes — verify compare page renders side-by-side
- Click "Delete" on an outline (with a second outline present) — verify redirect and deletion
- Try to delete the last outline — verify 422 response

---

## Phase 6: AI Integration & Redcarpet

**Goal:** Wire up `GeminiService`, seed the `coursement_outline_v1` template, add Redcarpet for Markdown rendering, and add rate limiting on generation endpoints.

### Redcarpet Gem

Add to `Gemfile`:
```ruby
gem "redcarpet"
```

Add a helper in `app/helpers/application_helper.rb`:
```ruby
def render_markdown(text)
  renderer = Redcarpet::Render::HTML.new(safe_links_only: true, no_styles: true)
  markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true, fenced_code_blocks: true)
  markdown.render(text.to_s).html_safe
end
```

Use in `_outline_card.html.erb`:
```erb
<div class="outline-body">
  <%= render_markdown(outline.body) %>
</div>
```

### AI Template Seed

In `db/seeds.rb`, add after the boilerplate seeds:

```ruby
AiTemplate.find_or_create_by!(name: "coursement_outline_v1") do |t|
  t.description = "Generates a module-by-module course outline from topic, audience, skill level, and optional notes."
  t.system_prompt = <<~PROMPT
    You are an expert curriculum designer and instructional technologist with deep experience
    designing online courses across technical and non-technical subjects.

    Your job is to produce a clear, structured, actionable course outline that a subject-matter
    expert can use as a working blueprint. Every output you produce must follow the exact Markdown
    structure below. Do not include any commentary, greeting, or explanation before or after
    the outline. Return only the Markdown structure.

    ## Required Output Structure

    # [Course Title]

    **Target Audience:** [one sentence summarizing the intended learner]
    **Skill Level:** [Beginner | Intermediate | Advanced]
    **Estimated Duration:** [total estimated course time, e.g., "6 hours over 6 weeks"]

    ## Course Overview

    [Two to four sentences describing what the learner will be able to accomplish after
    completing the course. Focus on measurable outcomes, not content topics.]

    ## Module 1: [Module Title]

    **Learning Objective:** By the end of this module, learners will be able to [action verb phrase].

    Lessons:
    1. [Lesson title]
    2. [Lesson title]
    3. [Lesson title]

    Repeat the Module block for every module. Include between 5 and 8 modules total.
    Each module must have exactly one learning objective starting with "By the end of this
    module, learners will be able to..." followed by an action verb. Each module must have
    between 3 and 5 lesson titles. Lesson titles should be specific and scannable, not
    generic (avoid "Introduction to X" unless it is truly the first module).

    Calibrate depth, pacing, and vocabulary to the stated skill level.
    Beginner: explain concepts from first principles, avoid jargon, shorter modules.
    Intermediate: assume foundational knowledge, use domain terminology, include application exercises.
    Advanced: assume practitioner-level knowledge, focus on nuance, edge cases, and real-world tradeoffs.
  PROMPT
  t.user_prompt_template = <<~PROMPT
    Generate a complete course outline using the structure in your system instructions.

    Topic: {{topic}}
    Target Audience: {{target_audience}}
    Skill Level: {{skill_level}}
    Additional Notes from the Author: {{extra_notes}}

    If "Additional Notes" is blank or says "none," ignore it.
    Return only the Markdown outline. No preamble, no commentary.
  PROMPT
  t.model             = "gemini-2.5-flash"
  t.max_output_tokens = 2500
  t.temperature       = 0.6
  t.notes             = "Lower temperature improves structural consistency. Vague topics produce shallow outlines. Watch for preamble before the # Heading line when parsing the title."
end
```

> **Note from spec:** The original spec listed `gemini-2.0-flash` as the model, but per `docs/ai-templates.md`, that model is deprecated for new API keys. Use `gemini-2.5-flash` instead.

### Rate Limiting

Add to `CourseBriefsController`:
```ruby
rate_limit to: 10, within: 1.minute, only: [:create, :regenerate],
           with: -> { redirect_to dashboard_path, alert: "Please wait before generating again." }
```

### Manual Smoke Test
- Run `bundle install` and `rails db:seed`
- Sign in to admin → `/admin/ai_templates` → confirm `coursement_outline_v1` appears
- Click Edit, use the test panel with sample variables — confirm Gemini returns a valid outline
- Sign in as demo user, visit `/course_briefs/new`, fill in form, click "Generate Outline"
- Confirm outline is saved and shown on brief show page
- Confirm the title is parsed from the first `# Heading` line
- Confirm the "Regenerate" button creates a second outline with `is_draft: false`
- Confirm the raw response toggle shows the full Gemini response

---

## Phase 7: Seed Data

**Goal:** Populate the database with realistic sample data so the app looks complete immediately after `bin/setup`, without requiring a Gemini API key.

### Seed Records

In `db/seeds.rb`, add after the AI template seed. The three briefs each get one hardcoded `CourseOutline`. Brief 1's outline has `is_draft: true`.

Use `find_or_create_by!` on the admin user, then:

```ruby
demo_user = User.find_by!(email: "demo@example.com")

brief1 = CourseBrief.find_or_create_by!(
  user: demo_user,
  topic: "Python for Data Analysis with Pandas"
) do |b|
  b.target_audience = "Business analysts who know Excel but have never written code"
  b.skill_level     = "beginner"
  b.extra_notes     = "Emphasize real-world datasets; avoid computer science theory"
end

unless brief1.course_outlines.exists?
  brief1.course_outlines.create!(
    user:      demo_user,
    is_draft:  true,
    title:     "Python for Data Analysis with Pandas",
    gemini_raw: BRIEF1_OUTLINE_BODY,  # defined as a heredoc constant
    body:       BRIEF1_OUTLINE_BODY
  )
end
```

Repeat for Brief 2 (intermediate SQL) and Brief 3 (advanced Rails).

Each `BODY` constant is a hardcoded Markdown string that follows the exact template output format (# Title, ## Module N, Learning Objective, Lessons list). These should be realistic and scan as plausible outlines for the stated topics.

### Manual Smoke Test
- Run `rails db:seed` (idempotent — re-running should not create duplicates)
- Sign in as `demo@example.com` / `password123`
- Dashboard shows 3 brief cards
- Brief 1 has a "Draft" badge
- Visit Brief 1's show page — outline renders with Markdown, draft badge present, module count correct
- "Show raw response" toggle works

---

## Phase 8: CSS & Visual Polish

**Goal:** Verify all accent-color applications, badge classes, and layout details match the spec. This phase is primarily visual QA — no new files, only tweaks.

### Checklist

- [ ] Primary buttons use `var(--accent)` background — check `.btn-primary` override in CSS
- [ ] "Working Draft" badge uses `.badge-draft` (cyan background)
- [ ] Draft outline card has `.border-draft` left border
- [ ] Skill level badges: beginner → `bg-secondary`, intermediate → `bg-info text-dark`, advanced → `badge-draft`
- [ ] Compare page column headers use `color: var(--accent)` via inline style or utility class
- [ ] `.outline-body` applies `line-height: 1.7; max-width: 72ch` to rendered Markdown
- [ ] `pre.gemini-raw` styles apply in the raw response toggle
- [ ] Navbar "My Courses" and "New Outline" links appear only when signed in
- [ ] Active nav link has Bootstrap active styling (add `current_page?` check)

### Manual Smoke Test
- Full walkthrough: land → sign up → create brief → view outline → regenerate → compare → set draft → delete outline → delete brief → sign out
- Check every page for layout issues at desktop width (1280px) and mobile (375px)

---

## Phase 9: RSpec Test Suite

**Goal:** Write the complete RSpec suite as specified in spec Section 9. All tests must pass with zero real Gemini API calls.

### Files to Create

**`spec/models/course_brief_spec.rb`**
1. Validates presence of `topic`, `target_audience`, `skill_level`
2. Rejects `skill_level` values outside the allowed enum
3. Validates `topic` length (rejects > 200 chars)
4. Validates `extra_notes` length (rejects > 1000 chars; allows blank)
5. `has_draft?` returns false when no outline has `is_draft: true`, true when one does

**`spec/models/course_outline_spec.rb`**
1. Validates presence of `title`, `body`, `gemini_raw`
2. `belongs_to :course_brief` — outline invalid without brief
3. `belongs_to :user` — outline invalid without user
4. Setting `is_draft: true` clears `is_draft` on all siblings for the same brief
5. `module_count` returns the correct count of `## Module` headings in `body`

**`spec/requests/course_briefs_spec.rb`**
1. `GET /course_briefs/new` — renders form for authenticated users; redirects unauthenticated to sign in
2. `POST /course_briefs` success path — creates brief, calls `GeminiService.generate` (stubbed), creates `CourseOutline` with `is_draft: true`, redirects to brief show
3. `POST /course_briefs` Gemini error path — when stub raises `GeminiService::GeminiError`, renders form with error partial, does not persist `CourseOutline`
4. `POST /course_briefs/:id/regenerate` — calls Gemini again, creates second `CourseOutline` with `is_draft: false`
5. `GET /course_briefs/:id/compare` — renders compare view with valid two-outline IDs; returns 404 when outlines belong to another user

**`spec/requests/course_outlines_spec.rb`**
1. `PATCH /course_outlines/:id/set_draft` — sets `is_draft: true`, clears siblings, redirects to parent brief
2. `PATCH /course_outlines/:id/set_draft` for outline belonging to another user — returns 404
3. `DELETE /course_outlines/:id` — deletes outline when brief has > 1 outline; redirects to parent brief
4. `DELETE /course_outlines/:id` when brief has only one outline — returns 422, does not delete

**`spec/requests/dashboard_spec.rb`**
1. `GET /dashboard` authenticated — renders all user's briefs; does not render another user's briefs
2. `GET /dashboard` unauthenticated — redirects to sign in

### Gemini Stubs

All request specs that trigger Gemini calls must use `gemini_returns(...)` or `gemini_raises(...)` from `spec/support/gemini_test_double.rb`. The stub response for success should be a valid Markdown outline string with at least one `# Heading` line so the title parser works:

```ruby
SAMPLE_OUTLINE = <<~MD
  # Python for Data Analysis
  
  **Target Audience:** Business analysts
  **Skill Level:** Beginner
  
  ## Module 1: Getting Started
  
  **Learning Objective:** By the end of this module, learners will be able to set up Python.
  
  Lessons:
  1. Installing Python and Jupyter
  2. Your first notebook
MD
```

### Manual Smoke Test (Final)
- Run `bundle exec rspec` — all tests pass
- Run `bundle exec rspec --format documentation` — review output for any skipped or pending tests
- Confirm zero HTTP calls to Gemini in the test output

---

## Build Order Summary

| Phase | Focus | Key Deliverables |
|-------|-------|-----------------|
| 0 | Configuration | .env.example, accent CSS, navbar |
| 1 | Data models | Migrations, models, factories, model specs |
| 2 | Routes | routes.rb additions |
| 3 | Controllers | All controller files, action signatures |
| 4 | Home & Dashboard | Two view overrides |
| 5 | Brief & Outline views | 5 view files, full CRUD UI |
| 6 | AI integration | Redcarpet, template seed, live Gemini wiring |
| 7 | Seed data | 3 briefs + hardcoded outlines |
| 8 | Visual polish | CSS verification, layout QA |
| 9 | RSpec suite | 14 request cases + 10 model cases |

---

*v1.0 — Coursement Demo phased build spec. Built from coursement-demo-spec.md v1.0.*
