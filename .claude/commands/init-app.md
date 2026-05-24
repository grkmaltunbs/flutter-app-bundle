# /init-app — Project initialization

You are running the initialization flow for a new Flutter app. Your job
is to take the user from "empty directory with this bundle cloned" to
"ready to start building features step by step."

Your output is three filled files: `CLAUDE.md`, `PROJECT_PLAN.md`,
`HUMAN_SETUP.md`, plus a working Flutter project scaffold.

## Operating rules

- **Be opinionated.** Propose specific takes on flow, monetisation,
  screen decisions, tech-stack overrides. Cite trade-offs.
- **Ask one question at a time.** Long lists overwhelm.
- **Always use AskUserQuestion for structured choices.**
- **Verify file existence before editing.** Templates live in
  `templates/`. Real project files start as copies.

## Workflow

### Stage 1 — Idea capture

Greet the human briefly. Ask them to describe their app in ~1
paragraph: who's it for, what's the core loop, what would v1 look like.

Then ask in this order (one question per turn):

1. **Platforms.** iOS + Android? iOS only? Add web/desktop?
2. **Backend.** Firebase (default) / Supabase / custom REST / none.
3. **Monetisation intent.** Free, freemium, paid, ad-supported, not-decided.
4. **Special integrations.** Maps, payments, push, OAuth providers,
   HealthKit, video, real-time chat, ML, etc.

### Stage 2 — Design intake

Ask for the design source:

- **"Claude Design URL"** — download with `curl -L <url> -o /tmp/design.tar.gz`,
  extract to `docs/design/`. Read README.md and chat transcripts first.
- **"Figma file"** — ask for screenshots in `docs/design/screens/`.
- **"None"** — describe screens, suggest palette + type stack.

Summarise what you see in 5–10 bullets.

### Stage 3 — Creative pass

For each, give your read and push back if needed:

1. **Screen flow.** Missing screens? Screens that should merge?
2. **Monetisation specifics.** Concrete gates and upsell surfaces.
3. **Tech-stack overrides.** Default is bloc + freezed + go_router +
   drift + Firebase. Swap if the app type demands it.
4. **Naming.** App name, tagline, bundle ID, Firebase project ID.

When the human says "looks good, let's lock it in", move to Stage 4.

### Stage 4 — Fill the templates

1. Copy templates to project root:
   ```bash
   cp templates/CLAUDE.md.template CLAUDE.md
   cp templates/PROJECT_PLAN.md.template PROJECT_PLAN.md
   cp templates/HUMAN_SETUP.md.template HUMAN_SETUP.md
   ```
2. Fill CLAUDE.md — replace every `<PLACEHOLDER>`.
3. Fill PROJECT_PLAN.md — build a step ladder for the feature set.
   Steps should be sized for one Claude Code session each.
4. Fill HUMAN_SETUP.md — remove items that don't apply, add
   project-specific items.

### Stage 5 — Create the Flutter project

Run `flutter create` NOW, during init — not deferred to a plan step:

```bash
flutter create . --org <org> --project-name <name> --platforms ios,android
```

This unblocks HUMAN_SETUP.md items that need `ios/` and `android/`
directories (flutterfire configure, Xcode signing, key.properties).

### Stage 6 — Walk through HUMAN_SETUP.md live

For each `- [ ]` item:
- Tell the human exactly what to do (full commands, not vague instructions).
- Wait for confirmation.
- Flip `- [ ]` → `- [x]` on completion.
- If the item produces a value, plug it into CLAUDE.md.
- Items that can be deferred — say so explicitly.

### Stage 7 — Smoke test

```bash
flutter doctor
flutter analyze
flutter test
```

If any fail, diagnose and fix.

### Stage 8 — Handoff

Print:

```
✅ Initialization complete.

Files ready:
- CLAUDE.md
- PROJECT_PLAN.md (<N> steps)
- HUMAN_SETUP.md (all items resolved)

Flutter project created and compiling.

To start building, run:
    /step

Or implement a specific step:
    /step <step-id>

Use /plan-status to see progress at any time.
```

## What you must NOT do

- Don't write `pubspec.yaml` beyond what `flutter create` generates.
  Step 0 (bootstrap) handles the full dependency setup.
- Don't `git init` or `git commit`.
- Don't edit `.claude/`, `docs/lessons-learned.md`.
- Don't push to GitHub or any remote.
