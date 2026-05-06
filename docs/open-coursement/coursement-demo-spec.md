# Coursement Demo - App Spec

**Document Version:** 1.0
**Built on:** Open Demo Starter v2.0
**License:** MIT

---

## 1. App Overview

Coursement Demo is a single-purpose Rails 8 app that solves the hardest first step in online course creation: the outline. A user describes their course topic, names their target audience, and picks a skill level. Gemini returns a complete module-by-module outline in seconds, including learning objectives and lesson titles for each module. The user can generate multiple outlines for the same brief, view any two side by side, and mark one as their working draft.

The "first draft" problem is real: most instructors spend hours wrestling with structure before they write a single lesson. This app eliminates that friction entirely and demonstrates the core outline engine at the heart of Coursement, a larger AI-powered course-building platform the author is building as a multi-tenant SaaS product.

The production version of Coursement is multi-tenant: teams of instructors collaborate on courses inside shared workspaces. This demo strips that to its simplest form - one signed-in user, one clean feature, no organizational overhead. It is open source under the MIT license, runs entirely on localhost, and is designed to be cloned and understood in under 30 minutes.

---

## 2. Customizations Applied to the Boilerplate

The following items diverge from the default Open Demo Starter boilerplate:

- `APP_NAME` set to `Coursement Demo` in `.env.example`
- `APP_TAGLINE` set to `Describe a course topic. Get a complete module-by-module outline in seconds.`
- `APP_DESCRIPTION` set to a one-paragraph pitch about eliminating the blank-page problem for course creators
- Accent color `#06b6d4` (cyan) set in `app/assets/stylesheets/_accent.scss`
- Navbar adds two links: "My Courses" (routes to dashboard) and "New Outline" (routes to `course_briefs#new`)
- `home/index.html.erb` replaced with a landing page showing a sample outline card, a short tagline, and a "Generate your first outline" call-to-action button
- `dashboard/show.html.erb` replaced with a brief card grid listing all of the current user's `CourseBrief` records, each showing topic, skill level, outline count, and a draft badge if a draft outline exists
- UX pattern: form-then-result with side-by-side comparison of saved outlines
- AI templates seeded: `coursement_outline_v1` (full content in Section 7)

---

## 3. Data Model

### CourseBrief

The user's input record. Stores the parameters used to generate one or more outlines.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | Foreign key; required |
| `topic` | string | Required; max 200 chars **(template variable)** |
| `target_audience` | string | Required; max 200 chars **(template variable)** |
| `skill_level` | string | Required; enum: `beginner`, `intermediate`, `advanced` **(template variable)** |
| `extra_notes` | text | Optional; max 1000 chars **(template variable)** |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Associations:
- `belongs_to :user`
- `has_many :course_outlines, dependent: :destroy`

Validations:
- `topic`: presence, length (max 200)
- `target_audience`: presence, length (max 200)
- `skill_level`: presence, inclusion in `%w[beginner intermediate advanced]`
- `extra_notes`: length (max 1000), allow blank

Instance methods:
- `draft_outline`: returns the single `CourseOutline` where `is_draft: true`, or nil
- `has_draft?`: returns true if a draft outline exists

### CourseOutline

One AI-generated outline for a given brief. Multiple outlines can exist for the same brief.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `course_brief_id` | uuid | Foreign key; required |
| `user_id` | uuid | Foreign key; required (denormalized for efficient scoping to current_user) |
| `title` | string | Required; parsed from the first `# Heading` in the Gemini response |
| `body` | text | Required; the full Markdown outline returned by Gemini |
| `is_draft` | boolean | Default false; only one outline per brief may have this true at a time |
| `gemini_raw` | text | Required; raw Gemini response **(Gemini output, used for Show raw response toggle)** |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Associations:
- `belongs_to :course_brief`
- `belongs_to :user`

Validations:
- `title`: presence
- `body`: presence
- `gemini_raw`: presence
- `user_id`: presence

Callbacks:
- `before_create`: if `is_draft` is being set to true, clears `is_draft` on all sibling outlines for the same `course_brief_id`

Instance method:
- `module_count`: counts the number of `## Module` headings in `body`

---

## 4. Routes

| HTTP Verb | Path | Controller#Action | Purpose |
|---|---|---|---|
| GET | /dashboard | dashboard#show | Card grid of all CourseBriefs for current user |
| GET | /course_briefs/new | course_briefs#new | Blank new brief form |
| POST | /course_briefs | course_briefs#create | Creates brief, calls Gemini, saves first outline, redirects to brief show |
| GET | /course_briefs/:id | course_briefs#show | Shows brief details and all saved outlines for it |
| DELETE | /course_briefs/:id | course_briefs#destroy | Deletes brief and all associated outlines |
| POST | /course_briefs/:id/regenerate | course_briefs#regenerate | Generates an additional outline for an existing brief |
| GET | /course_briefs/:id/compare | course_briefs#compare | Side-by-side view of two outlines; accepts `?outline_ids[]=uuid&outline_ids[]=uuid` |
| PATCH | /course_outlines/:id/set_draft | course_outlines#set_draft | Marks this outline as working draft, clears the flag on siblings |
| DELETE | /course_outlines/:id | course_outlines#destroy | Deletes a single outline (not its parent brief) |

All routes require authentication. All responses are HTML. No JSON API routes.

---

## 5. Controllers and Actions

### `CourseBriefsController`

Inherits from `ApplicationController`. Scopes all queries to `current_user`. Uses strong parameters for `CourseBrief` attributes.

**`new`**
Renders a blank `CourseBrief` form. No database queries.

**`create`**
Validates and saves a new `CourseBrief` using strong params. On save success, calls `GeminiService.generate(template: "coursement_outline_v1", variables: { topic: @brief.topic, target_audience: @brief.target_audience, skill_level: @brief.skill_level, extra_notes: @brief.extra_notes.to_s })`. Parses the response to extract the title (first `# Heading` line) and body. Creates and saves a `CourseOutline` with `is_draft: true` (the first outline is always the starting draft). Redirects to `course_briefs#show`. On `GeminiService::GeminiError`, renders the new form with the boilerplate error partial and a retry button; the `CourseBrief` record is destroyed if the outline could not be saved.

**`show`**
Loads `@brief = current_user.course_briefs.find(params[:id])` with its outlines ordered by `created_at desc`. Renders the brief details, all outline cards, and the compare-selection UI.

**`destroy`**
Deletes `@brief` (cascades to outlines via `dependent: :destroy`). Redirects to dashboard with a flash notice.

**`regenerate`**
Loads the existing `@brief` from `current_user.course_briefs`. Calls `GeminiService.generate` with the same template and variables as `create`. Parses and saves a new `CourseOutline` (not a draft by default; the user promotes to draft explicitly). Redirects to `course_briefs#show`. On `GeminiService::GeminiError`, redirects to `course_briefs#show` with the error partial rendered via a flash-style Turbo Stream.

**`compare`**
Accepts `params[:outline_ids]` (an array of exactly two UUIDs). Loads each outline with `current_user.course_outlines.find(id)` to enforce ownership. Renders a two-column view. Returns a 422 with an inline error if fewer or more than two IDs are provided or if any outline does not belong to the current user.

### `CourseOutlinesController`

Inherits from `ApplicationController`. Scopes all queries to `current_user`. No Gemini calls in this controller.

**`set_draft`**
Loads `@outline = current_user.course_outlines.find(params[:id])`. Calls `@outline.update!(is_draft: true)` (the before_create callback pattern is replicated as a before-save callback to handle updates). Redirects to `course_briefs#show` for the parent brief with a success flash.

**`destroy`**
Loads `@outline = current_user.course_outlines.find(params[:id])`. Checks that the brief has more than one outline before allowing delete (prevents the user from deleting the last outline of a brief; the brief destroy action handles full deletion). Redirects to `course_briefs#show` with appropriate flash.

### `DashboardController` (override of boilerplate)

**`show`**
Loads `@briefs = current_user.course_briefs.includes(:course_outlines).order(created_at: :desc)`. Renders the card grid.

---

## 6. Views

### `home/index.html.erb` (override)

Landing page for unauthenticated visitors. Shows the app tagline, a one-paragraph pitch, and a "Generate your first outline" button (links to `sign_up_path`). Includes a static sample outline card (hardcoded HTML) showing what a generated outline looks like, styled with the cyan accent color. No dynamic data.

### `dashboard/show.html.erb` (override)

Card grid of `CourseBrief` records. Each card shows: topic, skill level badge, outline count, created date, a "Draft" badge if `brief.has_draft?`, and two action links: "View Outlines" and "Delete." A prominent "New Outline" button appears at the top right. If the user has no briefs, renders an empty state with a centered call-to-action.

### `course_briefs/new.html.erb`

Single-page form for a new `CourseBrief`. Fields: Topic (text input), Target Audience (text input), Skill Level (Bootstrap radio buttons for beginner/intermediate/advanced), and Additional Notes (textarea, optional). Submit button labeled "Generate Outline" styled with `--accent`. A small note below the button reads: "Gemini will generate your outline in a few seconds."

### `course_briefs/_form.html.erb`

Shared form partial used by `new.html.erb`. Renders validation errors at the top via a standard Rails error messages partial.

### `course_briefs/show.html.erb`

Two-section layout. Top section shows the brief's details (topic, audience, skill level, notes) in a read-only card with a "Regenerate" button and a "Delete Brief" button. Bottom section lists all outlines for this brief. Each outline is rendered as a card using `_outline_card.html.erb`. If the brief has two or more outlines, a "Compare" button appears above the list; selecting two checkboxes and clicking Compare links to `course_briefs#compare` with the selected outline IDs as query params.

### `course_briefs/_outline_card.html.erb`

Partial for one outline. Displays: title, module count, created date, and a "Working Draft" badge if `is_draft`. Contains two action buttons: "Set as Draft" (submits to `course_outlines#set_draft` via a `button_to` with `method: :patch`) and "Delete" (submits to `course_outlines#destroy` via `button_to` with `method: :delete` and `data-turbo-confirm`). Renders the outline body (Markdown rendered as HTML via the `redcarpet` gem). Includes a Bootstrap collapse "Show raw response" toggle that reveals `outline.gemini_raw` in a `<pre>` block.

### `course_briefs/compare.html.erb`

Side-by-side comparison. Two equal-width Bootstrap columns (each `col-md-6`), one per outline. Each column renders the full outline card via `_outline_card.html.erb`. A "Back to brief" link appears above the columns. The page title names the brief's topic. Turbo behavior: none; this is a standard full-page render.

### `shared/_gemini_error.html.erb` (boilerplate partial, used as-is)

Already provided by the boilerplate. Rendered in `create` and `regenerate` on `GeminiService::GeminiError`.

---

## 7. AI Templates and Gemini Integration

### Template: `coursement_outline_v1`

**Template `name`:** `coursement_outline_v1`

**`description`:** Generates a module-by-module course outline from a topic, target audience, skill level, and optional notes.

**Full `system_prompt` text:**

```
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
```

**Full `user_prompt_template` text:**

```
Generate a complete course outline using the structure in your system instructions.

Topic: {{topic}}
Target Audience: {{target_audience}}
Skill Level: {{skill_level}}
Additional Notes from the Author: {{extra_notes}}

If "Additional Notes" is blank or says "none," ignore it.
Return only the Markdown outline. No preamble, no commentary.
```

**Variables consumed:**

- `{{topic}}` - from `CourseBrief#topic`
- `{{target_audience}}` - from `CourseBrief#target_audience`
- `{{skill_level}}` - from `CourseBrief#skill_level`
- `{{extra_notes}}` - from `CourseBrief#extra_notes` (`.to_s` so nil becomes an empty string)

**`model`:** `gemini-2.0-flash` (default). No justification for a different model; the task is structured text generation, not reasoning or code.

**`max_output_tokens`:** `2500`. Slightly above the 2000 default to accommodate longer outlines with 8 modules and 5 lessons each. A full outline at this scope runs approximately 600-900 tokens, so 2500 provides comfortable headroom without enabling runaway output.

**`temperature`:** `0.6`. Slightly below the default 0.7. Course outlines benefit from structural consistency over creative variation; a lower temperature reduces the chance of Gemini inventing unusual module structures or skipping the required Markdown format. Not so low that all outlines for similar topics feel identical.

**`notes`:**

This prompt works best when `topic` is concrete ("Python web scraping with BeautifulSoup") rather than abstract ("Python"). Vague topics produce correctly formatted but shallow outlines. The gatekeeper's 5000-character input limit is unlikely to be hit here, but `extra_notes` is the most likely vector for long inputs - the 1000-character limit on that field provides adequate protection.

The most common failure mode is Gemini adding a preamble sentence before the `# Heading` (e.g., "Here is your outline:"). The title parsing logic in the controller should skip non-heading lines when extracting the course title.

A second failure mode is Gemini producing fewer than 5 modules for very narrow topics. This is acceptable behavior; do not add module-count validation that would discard valid short outlines.

Iteration tip: if outlines feel generic, sharpen `extra_notes` to supply context about the instructor's unique angle or their learners' specific job roles.

**Where it's called:**

`CourseBriefsController#create` and `CourseBriefsController#regenerate` both call:

```ruby
GeminiService.generate(
  template: "coursement_outline_v1",
  variables: {
    topic:           @brief.topic,
    target_audience: @brief.target_audience,
    skill_level:     @brief.skill_level,
    extra_notes:     @brief.extra_notes.to_s
  }
)
```

**Expected output format:** Markdown. Not JSON.

**How the response is parsed and rendered:**

1. The raw response string is stored directly in `CourseOutline#gemini_raw`.
2. The controller scans the response line by line for the first line starting with `# ` and uses that as `CourseOutline#title` (stripping the `# ` prefix). If no `# ` line is found, the title defaults to the brief's `topic`.
3. The full response string is stored in `CourseOutline#body`.
4. In views, `body` is rendered to HTML using the `redcarpet` gem with safe HTML and no raw HTML options. The rendered HTML is wrapped in a `div` with class `outline-body`.

**Which domain field stores the raw response:** `CourseOutline#gemini_raw`

---

## 8. AI Safety Considerations (Specific to This App)

**Content sensitivity.** Course outline generation is a low-stakes domain. Topics are educational in nature. The app does not deal with health, legal, financial, or life-decision advice.

**Consequential outputs.** The worst-case outcome is a poorly structured outline that an instructor follows when designing a bad course. This is equivalent to getting bad advice from a poorly-informed colleague. No physical, legal, or financial harm results from acting on a weak outline. Consequentiality is low.

**Domain accuracy requirements.** Factual accuracy in the outline itself is relatively low-stakes: the outline names modules and lessons but does not assert claims. An instructor who is a subject-matter expert will immediately spot if a module title reflects a misconception. The raw response toggle lets users verify exactly what Gemini produced.

**App-specific disclaimers.** No disclaimer beyond the boilerplate footer note ("AI-generated content can be incorrect. Verify before acting.") is warranted for this domain. A small contextual note on the outline card is appropriate: "Review this outline before building your course. Module structure and lesson titles are suggestions, not authoritative curricula." This note should appear in muted text below each outline title.

**Tightened settings.** No tightening is needed. The default daily call cap (50) is appropriate. The gatekeeper's prompt-injection check is sufficient for this input surface - users are inputting course topics, not open-ended free text. `max_output_tokens: 2500` is a reasonable ceiling for this output shape.

**What this demo deliberately does NOT do (for safety reasons):**

- Does not generate lesson content, scripts, or assessments. Scope is outline only; the larger production app handles content generation with more context about the learner's platform and the instructor's voice.
- Does not validate that topics are appropriate for the stated skill level. If a user asks for an "Advanced" outline on a beginner-only topic, Gemini will do its best; the user is responsible for evaluating fit.
- Does not claim pedagogical expertise. The footer note and the "Review before building" card note both position this as a starting point, not a certified instructional design output.

This app is one of the lower-stakes demos in the portfolio. No additional safety treatment beyond what the boilerplate provides is required.

---

## 9. RSpec Outline

### `spec/models/course_brief_spec.rb`

1. Validates presence of `topic`, `target_audience`, and `skill_level`
2. Rejects `skill_level` values outside the allowed enum
3. Validates `topic` length (rejects strings over 200 characters)
4. Validates `extra_notes` length (rejects strings over 1000 characters; allows blank)
5. `has_draft?` returns false when no outline has `is_draft: true`, and true when one does

### `spec/models/course_outline_spec.rb`

1. Validates presence of `title`, `body`, and `gemini_raw`
2. `belongs_to :course_brief` - outline is invalid without a brief
3. `belongs_to :user` - outline is invalid without a user
4. Setting `is_draft: true` on one outline clears `is_draft` on all sibling outlines for the same brief
5. `module_count` returns the correct count of `## Module` headings in `body`

### `spec/requests/course_briefs_spec.rb`

1. `GET /course_briefs/new` - renders the form for authenticated users; redirects unauthenticated users to sign in
2. `POST /course_briefs` (success path) - creates a `CourseBrief`, calls `GeminiService.generate` with the stubbed double, creates a `CourseOutline` with `is_draft: true`, creates an `LlmRequest` record, and redirects to the brief show page
3. `POST /course_briefs` (Gemini error path) - when the stub raises `GeminiService::GeminiError`, renders the form with an error partial and does not persist a `CourseOutline`
4. `POST /course_briefs/:id/regenerate` - calls Gemini again with the same brief variables, creates a second `CourseOutline` with `is_draft: false`, creates an `LlmRequest` record
5. `GET /course_briefs/:id/compare` with valid two-outline IDs - renders the compare view; with outlines belonging to a different user, returns 404

### `spec/requests/course_outlines_spec.rb`

1. `PATCH /course_outlines/:id/set_draft` - sets `is_draft: true` on the target outline, clears `is_draft` on sibling outlines, redirects to the parent brief
2. `PATCH /course_outlines/:id/set_draft` for an outline belonging to a different user - returns 404 (access control)
3. `DELETE /course_outlines/:id` - deletes the outline when the brief has more than one outline; redirects to the parent brief
4. `DELETE /course_outlines/:id` when the brief has only one outline - returns 422 with an inline error; does not delete

### `spec/requests/dashboard_spec.rb`

1. `GET /dashboard` for authenticated user - renders all their briefs; does not render briefs belonging to other users
2. `GET /dashboard` for unauthenticated user - redirects to sign in

---

## 10. Seed Data

### AiTemplate Seed

`db/seeds.rb` creates the `coursement_outline_v1` template as specified in Section 7:

```ruby
AiTemplate.find_or_create_by!(name: "coursement_outline_v1") do |t|
  t.description       = "Generates a module-by-module course outline from topic, audience, skill level, and optional notes."
  t.system_prompt     = <<~PROMPT
    [full system prompt text from Section 7]
  PROMPT
  t.user_prompt_template = <<~PROMPT
    [full user prompt template text from Section 7]
  PROMPT
  t.model             = "gemini-2.0-flash"
  t.max_output_tokens = 2500
  t.temperature       = 0.6
  t.notes             = "Lower temperature improves structural consistency. Vague topics produce shallow outlines - encourage specific topics. Watch for preamble before the # Heading line when parsing the title."
end
```

### Domain Seed Data

Three `CourseBrief` records are seeded for the demo admin user to demonstrate the dashboard card grid immediately after `bin/setup`:

**Brief 1 - Beginner Python:**
- `topic`: "Python for Data Analysis with Pandas"
- `target_audience`: "Business analysts who know Excel but have never written code"
- `skill_level`: "beginner"
- `extra_notes`: "Emphasize real-world datasets; avoid computer science theory"

**Brief 2 - Intermediate SQL:**
- `topic`: "Advanced SQL for Analytics Engineers"
- `target_audience`: "Analysts who can write basic SELECT queries and want to learn window functions, CTEs, and query optimization"
- `skill_level`: "intermediate"
- `extra_notes`: ""

**Brief 3 - Advanced Rails:**
- `topic`: "Scaling Ruby on Rails Applications"
- `target_audience`: "Mid-level Rails developers who have shipped production apps and are encountering performance problems"
- `skill_level`: "advanced"
- `extra_notes`: "Focus on database performance, caching strategies, and background job architecture"

Each brief is seeded with one saved `CourseOutline` using hardcoded body content (not a live Gemini call) so the app displays meaningful sample data without requiring a Gemini API key at setup time. Brief 1's outline has `is_draft: true`. The hardcoded outlines follow the exact Markdown structure the template produces so they serve as realistic examples of expected output.

---

## 11. README Additions

### App Name and Tagline

**Coursement Demo** - Describe a course topic. Get a complete module-by-module outline in seconds.

### Description

Coursement Demo is a single-purpose Rails 8 app that generates structured course outlines using Google Gemini. Enter a topic, a target audience, and a skill level. Gemini returns a complete module-by-module outline with learning objectives and lesson titles in seconds. Generate multiple versions for the same brief, compare them side by side, and promote your favorite to "working draft" when you are ready to start building.

### Screenshot

`[Screenshot: Brief form on the left, generated outline on the right with module cards visible]`

### Why I Built This

The hardest part of building an online course is not writing the content - it is staring at a blank document wondering how to organize everything you know into a coherent learning journey. This generator solves that cold-start problem in seconds.

This demo is one feature extracted from Coursement, a larger AI-powered course-building platform I am building for instructors and small teams. The full product is multi-tenant: teams of instructors collaborate on courses, modules, and lessons inside shared workspaces. This demo strips all of that down to one user and one clean feature so you can see the engine clearly.

The source code is open under the MIT license. Clone it, run it locally, and tune the AI prompt in the admin UI to fit your needs. If you want to see the full multi-tenant platform, visit [coursement.app] (link placeholder).

### Editing the AI Prompt

This app's outline template is stored as a database record, not hardcoded in the source. After running `bin/setup`, sign in as the demo admin (`demo@example.com` / `password123`) and visit `/admin/ai_templates`. Click `coursement_outline_v1` to open the template editor. You can edit the system prompt and user prompt, type sample variable values in the test panel, and see Gemini's response without saving. When you find a prompt you like, save it and try it in the main app. No server restart needed.

### App-Specific Setup

No additional setup steps beyond `bin/setup`. The app seeds hardcoded sample outlines so it looks meaningful on first load without a Gemini API key. To generate real outlines, add `GEMINI_API_KEY=your_key_here` to `.env` (see `.env.example` for all variables).

---

## 12. Bootstrap Dark Mode and Accent Color Notes

### Layout Pattern

This app uses a card-heavy layout: brief cards on the dashboard, outline cards on the brief show page, and two equal-width columns on the compare page. Bootstrap's `.card`, `.card-body`, `.card-title`, and `.card-footer` components handle the bulk of the layout without custom CSS.

### Accent Color Application

Accent color `#06b6d4` (cyan) is set in `app/assets/stylesheets/_accent.scss`:

```scss
:root {
  --accent: #06b6d4;
  --accent-hover: #0891b2;
}
```

The accent color is applied consistently in the following places:

- Primary buttons (`.btn-primary` overridden to use `var(--accent)` background and `var(--accent-hover)` on hover)
- Active nav link underline or text color for "My Courses" and "New Outline" when on their respective pages
- "Working Draft" badge background (custom class `.badge-draft` using `var(--accent)`)
- Skill level badges for "Beginner" use a muted Bootstrap color; "Intermediate" uses a secondary; "Advanced" uses `var(--accent)` to signal highest engagement
- The compare-view column headers (brief title text) use `var(--accent)` to distinguish them from body content
- Outline card left border on the draft outline: a 3px solid `var(--accent)` border provides immediate visual hierarchy when scanning multiple outlines

### Custom CSS

Custom CSS beyond the boilerplate is minimal and confined to `_accent.scss`:

- `.badge-draft` - background `var(--accent)`, white text, applied to the "Working Draft" badge
- `.outline-body` - `line-height: 1.7; max-width: 72ch;` for readable Markdown rendering; no font size changes
- `.border-draft` - `border-left: 3px solid var(--accent);` applied to draft outline cards
- `pre.gemini-raw` - `font-size: 0.8rem; white-space: pre-wrap; word-break: break-word;` for the raw response toggle block

All other styling uses Bootstrap utility classes directly in the templates.

---

*v1.0 - Coursement Demo spec. Built on Open Demo Starter v2.0. Open source under MIT license.*
