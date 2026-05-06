# Coursement Demo

> Describe a course topic. Get a complete module-by-module outline in seconds.

Coursement Demo is a single-purpose Rails 8 app that generates structured course outlines using Google Gemini. Enter a topic, a target audience, and a skill level. Gemini returns a complete module-by-module outline with learning objectives and lesson titles in seconds. Generate multiple versions for the same brief, compare them side by side, and promote your favorite to "working draft" when you are ready to start building.

---

## Quick Start

```bash
git clone https://github.com/natron19/open-coursement.git
cd open-coursement
bin/setup
bin/rails server
```

Visit http://localhost:3000 and sign in with `demo@example.com` / `password123`.

The app seeds three sample briefs with realistic outlines so it looks meaningful on first load — no Gemini API key required to explore. To generate real outlines, add your key to `.env`:

```
GEMINI_API_KEY=your_key_here
```

Get a free key at https://aistudio.google.com/app/apikey.

---

## Why I Built This

The hardest part of building an online course is not writing the content — it is staring at a blank document wondering how to organize everything you know into a coherent learning journey. This generator solves that cold-start problem in seconds.

This demo is one feature extracted from Coursement, a larger AI-powered course-building platform I am building for instructors and small teams. The full product is multi-tenant: teams of instructors collaborate on courses, modules, and lessons inside shared workspaces. This demo strips all of that down to one user and one clean feature so you can see the outline engine clearly.

The source code is open under the MIT license. Clone it, run it locally, and tune the AI prompt in the admin UI to fit your needs.

---

## Features

- **Brief form** — topic, target audience, skill level (beginner / intermediate / advanced), optional notes
- **AI outline generation** — Gemini produces a module-by-module outline with learning objectives and lesson titles for each module, rendered as formatted Markdown
- **Multiple outlines per brief** — regenerate as many times as you like; all versions are saved
- **Side-by-side comparison** — select any two outlines and view them in two columns
- **Working draft** — promote one outline as your working draft; the badge and accent border make it easy to spot
- **Raw response toggle** — see exactly what Gemini returned before any parsing
- **Admin template editor** — edit the AI prompt, test it with sample variables, and see the response live — no server restart needed

---

## Editing the AI Prompt

This app's outline template is stored as a database record, not hardcoded in the source. After running `bin/setup`, sign in as the demo admin (`demo@example.com` / `password123`) and visit `/admin/ai_templates`. Click `coursement_outline_v1` to open the template editor. You can edit the system prompt and user prompt, type sample variable values in the test panel, and see Gemini's response without saving. When you find a prompt you like, save it and try it in the main app. No server restart needed.

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `APP_NAME` | `"Coursement Demo"` | Displayed in the navbar and page title |
| `APP_TAGLINE` | — | Shown in the footer and landing page |
| `APP_DESCRIPTION` | — | Shown on the landing page |
| `GEMINI_API_KEY` | (required for generation) | Your Google Gemini API key |
| `AI_CALLS_PER_USER_PER_DAY` | `50` | Daily AI call budget per user |
| `AI_GLOBAL_TIMEOUT_SECONDS` | `15` | Gemini request timeout in seconds |

Copy `.env.example` to `.env` and fill in your values.

---

## Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8.1 |
| Database | PostgreSQL with UUID primary keys |
| Auth | Rails native (`has_secure_password`, sessions) |
| CSS | Bootstrap 5 dark mode (CDN) |
| JavaScript | Stimulus + Turbo via importmap |
| AI | Google Gemini via `faraday` + `gemini-ai` |
| Markdown | Redcarpet |
| Queue / Cache / Cable | Solid Stack (no Redis) |
| Testing | RSpec |

---

## AI Safety Posture

**What this app enforces:**
- Per-user daily call cap (default: 50/day, configurable via `AI_CALLS_PER_USER_PER_DAY`)
- Pre-flight gatekeeper: input length limit, prompt injection patterns, profanity filter
- Hard output token cap (2500 tokens) on the outline template
- Configurable request timeout (default: 15s)
- Full request log with status, tokens, duration, and cost estimate in the admin panel
- Fail-soft UI: errors render an inline alert, never crash the page
- AI disclaimer in the footer on every page
- Contextual note on every outline card: "Module structure and lesson titles are suggestions, not authoritative curricula"

---

## Demo Credentials

| Field | Value |
|---|---|
| Email | `demo@example.com` |
| Password | `password123` |
| Admin | Yes |

---

## Running Tests

```bash
bundle exec rspec
```

All tests stub the Gemini API — no real API calls are made during the test suite.

---

## Built On

[Open Demo Starter](https://github.com/natron19/open-base) — a minimal Rails 8 + AI boilerplate for single-purpose demo apps.

---

## License

MIT — see [LICENSE](LICENSE)
