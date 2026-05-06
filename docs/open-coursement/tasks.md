# Coursement Demo — Build Task Tracker

Reference spec: `docs/open-coursement/coursement-demo-spec.md`  
Implementation guide: `docs/open-coursement/phased-build-spec.md`

Legend: `[ ]` todo · `[x]` done · `[-]` skipped/deferred

---

## Phase 0: App Configuration & Branding

- [x] Update `.env.example` with `APP_NAME`, `APP_TAGLINE`, `APP_DESCRIPTION`, and all required env vars
- [x] Set accent color variables in `app/assets/stylesheets/application.css` (`--accent: #06b6d4`)
- [x] Add custom CSS classes: `.badge-draft`, `.outline-body`, `.border-draft`, `pre.gemini-raw`
- [x] Add "My Courses" and "New Outline" nav links to `app/views/layouts/application.html.erb`

**Manual test:** App title shows "Coursement Demo", navbar renders without errors, no JS console errors.

---

## Phase 1: Data Models & Migrations

- [x] Generate and write `CourseBrief` migration (uuid PK, user reference, topic, target_audience, skill_level, extra_notes, timestamps)
- [x] Generate and write `CourseOutline` migration (uuid PK, course_brief reference, user reference, title, body, is_draft, gemini_raw, timestamps; index on is_draft)
- [x] Write `app/models/course_brief.rb` (associations, SKILL_LEVELS, validations, `draft_outline`, `has_draft?`)
- [x] Write `app/models/course_outline.rb` (associations, validations, `before_save` callback, `module_count`)
- [x] Run `rails db:migrate`
- [x] Create `spec/factories/course_briefs.rb`
- [x] Create `spec/factories/course_outlines.rb` (with `:draft` trait)
- [x] Write `spec/models/course_brief_spec.rb` (5 cases)
- [x] Write `spec/models/course_outline_spec.rb` (5 cases)

**Manual test:** `rails console` — create brief and outline, verify validations, `has_draft?`, `module_count`, and sibling-clearing callback.  
**RSpec:** `bundle exec rspec spec/models/course_brief_spec.rb spec/models/course_outline_spec.rb`

---

## Phase 2: Routes

- [x] Add `resources :course_briefs` with `member` routes (regenerate, compare) to `config/routes.rb`
- [x] Add `resources :course_outlines` with `member` route (set_draft) to `config/routes.rb`

**Manual test:** `rails routes | grep course` — all 8 routes present with correct helpers.

---

## Phase 3: Controllers

- [x] Create `app/controllers/course_briefs_controller.rb` with all 6 actions (new, create, show, destroy, regenerate, compare)
- [x] Create `app/controllers/course_outlines_controller.rb` with set_draft and destroy actions
- [x] Override `app/controllers/dashboard_controller.rb` (load briefs with outlines, ordered by created_at desc)

**Manual test:** Sign in, visit `/course_briefs/new` — get template-missing (controller works). Visiting `/dashboard` — get template-missing (controller works).

---

## Phase 4: Landing Page & Dashboard Views

- [x] Override `app/views/home/index.html.erb` (tagline, pitch, CTA button, static sample outline card)
- [x] Override `app/views/dashboard/show.html.erb` (card grid, empty state, skill level badges, draft badge, action links)

**Manual test:** Visit `/` — landing page renders. Sign in, visit `/dashboard` — empty state appears with "New Outline" button.

---

## Phase 5: Course Brief Views (Non-AI)

- [x] Create `app/views/course_briefs/new.html.erb`
- [x] Create `app/views/course_briefs/_form.html.erb` (topic, target_audience, skill_level radio buttons, extra_notes, submit with hint text, validation errors)
- [x] Create `app/views/course_briefs/show.html.erb` (brief details card + outlines list + compare form UI)
- [x] Create `app/views/course_briefs/_outline_card.html.erb` (title, draft badge, advisory note, module count, date, body placeholder, set-draft button, delete button, raw response collapse)
- [x] Create `app/views/course_briefs/compare.html.erb` (two-column layout, back link, column headers in accent color)

**Manual test (use rails console to create test data):**
- Brief form renders and validates
- Show page lists outlines with correct badges
- "Set as Draft" works
- "Compare Selected" with two checkboxes renders compare page
- Delete outline (> 1) works; delete last outline returns 422
- Delete brief redirects to dashboard

---

## Phase 6: AI Integration & Redcarpet

- [x] Add `gem "redcarpet"` to `Gemfile` and run `bundle install`
- [x] Add `render_markdown` helper to `app/helpers/application_helper.rb`
- [x] Wire `render_markdown(outline.body)` into `_outline_card.html.erb`
- [x] Add `coursement_outline_v1` AI template to `db/seeds.rb` (full system prompt and user prompt template from spec Section 7; use `gemini-2.5-flash`)
- [x] Run `rails db:seed` to load the template
- [x] Add rate limiting (`rate_limit to: 10, within: 1.minute`) on create and regenerate actions
- [x] Verify `CourseBriefsController#create` calls `GeminiService.generate`, parses title, saves `CourseOutline` with `is_draft: true`, handles all 4 error types
- [x] Verify `CourseBriefsController#regenerate` calls `GeminiService.generate`, saves outline with `is_draft: false`, handles all error types

**Manual test (requires `GEMINI_API_KEY` in `.env`):**
- Admin test panel: visit `/admin/ai_templates`, test `coursement_outline_v1` with sample variables
- Generate real outline from `/course_briefs/new` form
- Verify title parsed from `# Heading` line
- Verify Markdown renders in outline card
- Verify "Regenerate" creates a second non-draft outline
- Verify "Show raw response" toggle reveals `gemini_raw`

---

## Phase 7: Seed Data

- [x] Add 3 `CourseBrief` records to `db/seeds.rb` with `find_or_create_by!` (Python/beginner, SQL/intermediate, Rails/advanced)
- [x] Add 1 hardcoded `CourseOutline` per brief (realistic Markdown, no live Gemini call; Brief 1 outline has `is_draft: true`)
- [x] Run `rails db:seed` and verify idempotency (re-running does not duplicate records)

**Manual test:** Sign in as `demo@example.com` / `password123`. Dashboard shows 3 cards. Brief 1 has "Draft" badge. Outline pages render correct Markdown with module counts.

---

## Phase 8: Visual & Layout Polish

- [x] Verify `.btn-primary` uses `var(--accent)` background (CSS override in `application.css`)
- [x] Verify "Working Draft" badge uses `.badge-draft` class
- [x] Verify draft outline card has `.border-draft` left border applied
- [x] Verify skill level badge colors: beginner = `bg-secondary`, intermediate = `bg-info text-dark`, advanced = `badge-draft`
- [x] Verify compare page column headers render in accent color
- [x] Verify `.outline-body` applies `line-height: 1.7; max-width: 72ch`
- [x] Verify `pre.gemini-raw` styles in raw response toggle
- [x] Verify nav links "My Courses" and "New Outline" only show for signed-in users
- [x] Add `current_page?` active styling to nav links

**Manual test:** Full end-to-end walkthrough — land → sign up → create brief → view outline → regenerate → compare → set draft → delete outline → delete brief → sign out. Check at desktop (1280px) and mobile (375px).

---

## Phase 9: RSpec Test Suite

- [x] Write `spec/requests/course_briefs_spec.rb` (5 cases):
  - [x] `GET /course_briefs/new` — authenticated renders form; unauthenticated redirects to sign in
  - [x] `POST /course_briefs` success — creates brief + outline (is_draft true), redirects to show
  - [x] `POST /course_briefs` Gemini error — renders form + error partial, no outline persisted
  - [x] `POST /course_briefs/:id/regenerate` — creates second outline (is_draft false)
  - [x] `GET /course_briefs/:id/compare` — renders with valid IDs; 404 for other user's outlines
- [x] Write `spec/requests/course_outlines_spec.rb` (4 cases):
  - [x] `PATCH set_draft` — sets draft, clears siblings, redirects to brief
  - [x] `PATCH set_draft` for another user's outline — 404
  - [x] `DELETE` — deletes when > 1 outline, redirects to brief
  - [x] `DELETE` last outline — 422, does not delete
- [x] Write `spec/requests/dashboard_spec.rb` (2 cases):
  - [x] Authenticated — renders user's briefs only
  - [x] Unauthenticated — redirects to sign in
- [x] Define `SAMPLE_OUTLINE` stub string in test helpers or shared context for Gemini stubs

**Manual test:** `bundle exec rspec` — all tests green, zero real API calls. `bundle exec rspec --format documentation` — review output.

---

## Done Criteria

The app is complete when:
- [x] All phases above are checked off
- [x] `bundle exec rspec` passes with no failures
- [x] Full end-to-end walkthrough works on localhost
- [x] Seed data loads cleanly with `rails db:seed`
- [x] Admin test panel successfully calls Gemini with `coursement_outline_v1`
- [x] README is updated per spec Section 11
