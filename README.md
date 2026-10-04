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

## Responsible AI

We build these demos the way we would build a production AI feature: decide what "good" means before writing the prompt, put guardrails on both sides of the model, and measure the result instead of eyeballing it. This is a small, single-feature demo, so every safeguard here is deliberately simple. Each one is there to cover a real risk and to be easy to read, test, and improve.

### Guardrails

**Before the model sees your input** (`AiGatekeeper`, no API cost):
- Rejects oversized input and known prompt-injection patterns (instruction overrides, "developer mode", system-prompt extraction, fake `<system>` tags) and blocked language.

**Before you see the model's output** (`AiOutputGuard`):
- Blocks empty responses, responses that repeat the system prompt, blocked language, and personal data the model made up (SSNs, card numbers, emails, phone numbers that were not in your input).

**Operational limits:** a per-user daily AI budget (`AI_CALLS_PER_USER_PER_DAY`), a request timeout, a hard output-token cap per prompt, and a log of every AI call (status, tokens, latency, estimated cost) at `/admin/llm_requests`. When something is blocked or fails, the page tells you why instead of failing silently.

**Specific to this app:**
- Contextual note on every outline card: "Module structure and lesson titles are suggestions, not authoritative curricula"

### How we evaluate it

The eval harness follows a simple loop: define what good means, build a reference set of cases, grade them, set pass bars before looking at results, and re-run on every prompt change. Details are in [`docs/ai-evals.md`](docs/ai-evals.md).

| What we check | How | Run it |
|---|---|---|
| Guardrails catch attacks and leave normal input alone | Offline attack and look-alike suite, no API cost | `bin/rails evals:guardrails` |
| Output has the right shape | Code checks: required fields, counts, lengths | `bin/rails evals:run` |
| Output is actually good | An LLM judge scores each case 1–5 against a written rubric, after first proving it agrees with human-labeled examples | `bin/rails evals:run` |
| Latency, cost, and error rate | Read from the request log for each eval case | `bin/rails evals:run` |
| The real feature works in a browser | Headless Chrome walks the main AI feature, plus a blocked-input journey | Maintainer's fleet test harness, run before releases |

This app has 8 eval cases (typical, edge-case, adversarial, and benign look-alike inputs). The judge scores it on:

- **Useful:** The outline is calibrated to the stated audience and skill level. Beginner outlines start from first principles without jargon; advanced outlines skip basics and focus on nuance and tradeoffs.
- **Accurate:** The subject-matter content is accurate. Named tools, techniques, and concepts are real and correctly described, with nothing invented.
- **Useful:** Learning objectives use measurable action verbs and the modules progress in a sensible order.

**Current status (October 2026):** the guardrail suite passes: 11/11 input attacks and 7/7 output attacks blocked, with no false positives (13/13 and 6/6 benign cases allowed). Live-model eval baselines are being run next and will be published here. Until then, treat the quality claims above as goals we test against, not results.

### What this demo does and doesn't do

**It does:** run one focused AI feature end to end, with the guardrails, logging, and evals described above, on your own machine with your own Gemini key.

**It doesn't (yet):**
- Guarantee correct output. Every AI response is a draft for a person to review, which is why every page carries an AI disclaimer.
- Catch every attack. The input and output guards are pattern-based. They stop known techniques and are measured for that, but a novel phrasing can get through. That is why the output guard and the evals exist as a second layer.
- Scrub personal data from what you type. Don't paste anything sensitive into a local demo.
- Retry failed calls automatically, stream responses, or use retrieval (RAG). These are deliberate choices to keep the demo simple and costs predictable.

## Contributing and feedback

This project is open source and we want it to be useful to real people. Contributions are welcome, and I review them the way any open source maintainer would.

- **Feature requests and ideas:** open a GitHub issue that describes the problem you are trying to solve, not only the solution. Examples of the outputs you wish you got are especially helpful.
- **Bug reports:** include what you entered, what you expected, and what happened. For AI quality problems, the output itself is the most useful evidence.
- **Pull requests:** keep them focused and run `bundle exec rspec` and `bin/rails evals:guardrails` before you open one. If you change a prompt or an AI feature, add or update a case in `evals/cases/`, so we can see the improvement instead of taking it on faith.
- **Reviews:** I read every issue and review every pull request personally. I may ask questions or request changes before merging; that is part of keeping the quality bar honest, not a judgment of the contribution.
- **Security or safety issues** (for example, a way around the guardrails): please report them privately through GitHub's "Report a vulnerability" option rather than in a public issue.

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
