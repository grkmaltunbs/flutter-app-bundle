---
description: Take a new app from idea to spec, plan, and working Flutter scaffold
disable-model-invocation: true
---

# /init-app — Project initialization

You are running the initialization flow for a new Flutter app. Your job is to
take the user from "empty directory with this bundle cloned" to "ready to build
features step by step — with a spec complete enough that nothing important was
forgotten."

Your output is four filled files plus a scaffold:
`PRODUCT_SPEC.md`, `CLAUDE.md`, `PROJECT_PLAN.md`, `HUMAN_SETUP.md`, and a working
Flutter project.

## Operating rules

- **Completeness is the goal.** The deliverable is a spec so thorough that after
  the plan steps finish, the only work left is the external/store setup in
  `HUMAN_SETUP.md`. Use `docs/requirements-checklist.md` as the coverage engine.
- **Be opinionated.** Propose specific takes on flows, monetisation, screens,
  tech-stack overrides. Cite trade-offs. When the user has no opinion, propose a
  default and record it as an **assumption** (don't stall).
- **Ask one question at a time.** Long lists overwhelm. Use `AskUserQuestion`
  for structured choices.
- **No Firebase emulators.** This bundle verifies against **injected fakes** in a
  **demo flavor** running on real simulators — never Firebase emulators. Do not
  add Firebase emulator setup anywhere.
- **Verify file existence before editing.** Templates live in `templates/`.

## Workflow

### Stage 1 — Idea capture
Greet briefly. Ask the user to describe the app in ~1 paragraph: who it's for,
the core loop, what v1 looks like.

### Stage 2 — Design intake
Ask for the design source:
- **Claude Design URL** — `curl -L <url> -o /tmp/design.tar.gz`, extract to
  `docs/design/`, read README + transcripts first.
- **Figma** — ask for screenshots in `docs/design/screens/`.
- **None** — describe screens, propose palette + type stack.

Summarise what you see in 5–10 bullets.

### Stage 3 — Requirements interview (the core of init)
Walk **`docs/requirements-checklist.md`** category by category (1→29). For each:
- Ask one focused question (`AskUserQuestion`) eliciting the user's decision.
- If they have no opinion, state the category's **default**, record it as an
  **assumption**, and move on — do not block.
- Push back when a choice has a real downside; cite the "Why it bites" note.

You are mining for **every feature, every flow (happy + error + edge), and every
screen's states**. Pay special attention to the items users forget: account
deletion, denied-permission paths, restore purchases, offline/empty/error states
on every screen, textScale/overflow, deep links, ATT/consent.

### Stage 4 — Assumptions gate (mandatory)
Before writing anything, present **every assumed default** from Stage 3 as a
single confirm/override list (see the "Assumptions gate" section of the
checklist). Require the user to confirm or change each one. **Init may not
proceed until this list is cleared.** This is the "warn me about what I forgot"
step — do not skip or soft-pedal it.

### Stage 5 — Write the spec and derived files
Copy templates to the project root:
```bash
cp templates/PRODUCT_SPEC.md.template PRODUCT_SPEC.md
cp templates/CLAUDE.md.template CLAUDE.md
cp templates/PROJECT_PLAN.md.template PROJECT_PLAN.md
cp templates/HUMAN_SETUP.md.template HUMAN_SETUP.md
```
Then, in order:
1. **`PRODUCT_SPEC.md`** — fill it completely from Stages 1–4: feature inventory,
   every user flow with error/edge paths, every screen with all states,
   monetization spec, permissions matrix, data model, non-functional reqs, and
   the **Assumptions log** with each row marked Confirmed/Overridden.
2. **`CLAUDE.md`** — replace every `<PLACEHOLDER>`. Reflect the chosen stack and
   any overrides.
3. **`PROJECT_PLAN.md`** — **derive the step ladder from `PRODUCT_SPEC.md`**:
   every flow and screen in the spec maps to a step (or part of one). Each step
   is sized for one Claude Code session and carries Acceptance criteria taken
   from the spec's flows/states. Include a final responsive/accessibility pass
   step and a release-prep step.
4. **`HUMAN_SETUP.md`** — remove items that don't apply; add the project's
   external/store items (RevenueCat dashboard + products, App Store Connect /
   Play Console IAP products, signing, API keys, legal URLs). These are the
   irreducibly-human tasks — make each one exact and copy-pasteable.
5. **CI workflow** —
   `mkdir -p .github/workflows && cp templates/ci.yml.template .github/workflows/ci.yml`
   (CI runs analyze + test; simulator verification stays local).
6. **Build journal** — create `docs/BUILD_NOTES.md` with the one-line header:
   `Per-project build journal — appended by /step and /qa; read at the start of every step.`

### Stage 6 — Create the Flutter project
Run `flutter create` NOW (not deferred), so setup items that need `ios/` and
`android/` can be completed immediately:
```bash
flutter create . --org <org> --project-name <name> --platforms ios,android
```
Note: `flutter create` does NOT overwrite the existing `.gitignore` or
`README.md` — the bundle ships a full Flutter `.gitignore`. In this stage,
replace the bundle `README.md` with a short app-specific one.

### Stage 6.5 — Make the repo yours
The cloned bundle's `.git` history and `origin` remote still point at
`flutter-app-bundle`. Walk the user through one of:
- **Fresh history (recommended):** `rm -rf .git && git init`
- **Keep history:** `git remote set-url origin <their-repo-url>`

Note: autobuild refuses to push while `origin` points at the bundle repo.

### Stage 7 — Walk through HUMAN_SETUP.md live
For each `- [ ]` item:
- Tell the user exactly what to do (full commands, not vague instructions).
- Wait for confirmation; flip `- [ ]` → `- [x]`.
- If the item produces a value, plug it into `CLAUDE.md`.
- Items that can be deferred — say so explicitly, and note which plan step they
  unblock.

Front-load anything that gates later work (Apple Developer enrollment,
RevenueCat account, store IAP product creation) so the user starts them early.

### Stage 8 — Smoke test
```bash
flutter doctor
flutter analyze
flutter test
```
Diagnose and fix any failures.

### Stage 9 — Handoff
Print:
```
✅ Initialization complete.

Files ready:
- PRODUCT_SPEC.md  (full spec; assumptions all resolved)
- CLAUDE.md
- PROJECT_PLAN.md  (<N> steps, derived from the spec)
- HUMAN_SETUP.md   (external/store items — the only human work left)

Flutter project created and compiling.

Each /step builds a slice of the spec, then verifies it on the iOS and Android
simulators against fakes (no Firebase emulators), checking every flow + dependent flows
for bugs, exceptions, and overflow on all screen sizes.

To start building — step by step yourself:
    /step
    /step <step-id>
    /plan-status

…or hand the whole plan to the autonomous runner (set up the venv per
HUMAN_SETUP.md → "Autobuild runner", then):
    runner/.venv/bin/python runner/autobuild.py --dry-run    # smoke-test the wiring first
    caffeinate -i runner/.venv/bin/python runner/autobuild.py
```

In Stage 7, when you reach the optional "Autobuild runner" section of
HUMAN_SETUP.md, ask whether the user wants unattended builds; if yes, walk them
through creating the virtual environment and installing the SDK then and there.

## What you must NOT do
- Don't add Firebase emulator setup anywhere (this bundle is fakes-only).
- Don't write `pubspec.yaml` beyond what `flutter create` generates — Step 0
  (bootstrap) handles the full dependency set.
- Don't commit or push; the repo re-point/re-init in the "Make the repo yours"
  stage is expected.
- Don't edit `.claude/`, `docs/lessons-learned.md`, or `docs/requirements-checklist.md`.
- Don't finish init while any assumption is still unconfirmed.
