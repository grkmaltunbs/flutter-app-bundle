---
description: Take a new app from idea to spec, plan, and working Flutter scaffold
disable-model-invocation: true
---

# /init-app — Project initialization

You are running the initialization flow for a new Flutter app. Your job is to
take the user from "empty directory" to "ready to build features step by step —
with a spec complete enough that nothing important was forgotten."

Your output is a spec, a plan, and a scaffold:
`PRODUCT_SPEC.md`, `CLAUDE.md`, `plan/` (the step ladder and the human items —
`PROJECT_PLAN.md` is rendered from it), and a working Flutter project.

## Operating rules

- **Completeness is the goal.** The deliverable is a spec so thorough that after
  the plan steps finish, the only work left is the external/store setup in
  `HUMAN_SETUP.md`. Use `${CLAUDE_PLUGIN_ROOT}/reference/requirements-checklist.md`
  as the coverage engine.
- **Be opinionated.** Propose specific takes on flows, monetisation, screens,
  tech-stack overrides. Cite trade-offs. When the user has no opinion, propose a
  default and record it as an **assumption** (don't stall).
- **Ask one question at a time.** Long lists overwhelm. Use `AskUserQuestion`
  for structured choices.
- **Local emulators, not real Firebase.** Development verifies the **dev flavor**
  (`--dart-define=APP_ENV=dev`) against the **local Firebase Emulator Suite**
  under a `demo-<app>` project ID (the suite treats `demo-*` as offline-only —
  no real Firebase project needed). Optional `demo`-flavor fakes cover states
  the emulator can't simulate (offline, injected errors). Real (staging)
  Firebase is touched only in the **Backend integration pass**.
- **Kit files vs. project files.** Everything under `${CLAUDE_PLUGIN_ROOT}/` is
  read-only reference shipped by the plugin — never edit it. Everything you
  write goes in the user's project directory (the cwd).
- **Verify file existence before editing.** Templates live in
  `${CLAUDE_PLUGIN_ROOT}/templates/`.

## Workflow

### Stage 1 — Idea capture
Greet briefly. Ask the user to describe the app in ~1 paragraph: who it's for,
the core loop, what v1 looks like.

Confirm the working directory is empty (or contains only a `.git`). If it
already holds a Flutter project, say so and ask whether to adopt it (skip
Stage 5) or stop.

### Stage 2 — Design intake
Ask for the design source:
- **Claude Design URL** — `curl -L <url> -o /tmp/design.tar.gz`, extract to
  `docs/design/`, read README + transcripts first.
- **Figma** — ask for screenshots in `docs/design/screens/`.
- **None** — describe screens, propose palette + type stack.

Summarise what you see in 5–10 bullets.

### Stage 3 — Requirements interview (the core of init)
Walk **`${CLAUDE_PLUGIN_ROOT}/reference/requirements-checklist.md`** category by
category (1→29). For each:
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

### Stage 5 — Create the Flutter project
Run `flutter create` NOW (before writing any project files), so setup items that
need `ios/` and `android/` can be completed immediately and so the generated
`.gitignore` / `README.md` land before Stage 6 writes on top of them:
```bash
flutter create . --org <org> --project-name <name> --platforms ios,android
```
Then, if the directory is not already a git repo, `git init`.

### Stage 6 — Write the spec and derived files
Copy templates from the plugin into the project root:
```bash
cp "${CLAUDE_PLUGIN_ROOT}/templates/PRODUCT_SPEC.md.template" PRODUCT_SPEC.md
cp "${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.template"       CLAUDE.md
cp "${CLAUDE_PLUGIN_ROOT}/templates/HUMAN_SETUP.md.template"   HUMAN_SETUP.md
mkdir -p plan/steps plan/items
cp "${CLAUDE_PLUGIN_ROOT}/templates/plan/kit.yaml.template"    plan/kit.yaml
```
Then, in order:
1. **`PRODUCT_SPEC.md`** — fill it completely from Stages 1–4: feature inventory,
   every user flow with error/edge paths, every screen with all states,
   monetization spec, permissions matrix, data model, non-functional reqs, and
   the **Assumptions log** with each row marked Confirmed/Overridden.
2. **`CLAUDE.md`** — replace every `<PLACEHOLDER>`. Reflect the chosen stack and
   any overrides.
3. **`plan/kit.yaml`** — replace every `<PLACEHOLDER>`: project name, the
   Firebase project id, the QA policy (`backend: emulators` unless the user
   chose otherwise), and `release_step` (the id of the release-prep step you
   are about to write). Schema: `${CLAUDE_PLUGIN_ROOT}/schema/README.md`.
4. **`plan/steps/*.yaml`** — **derive the step ladder from `PRODUCT_SPEC.md`**:
   every flow and screen in the spec maps to a step (or part of one). One
   file per step, from `${CLAUDE_PLUGIN_ROOT}/templates/plan/step.yaml.template`;
   `rank` in tens in work order; `depends_on` by id. Each step is sized for
   one Claude Code session and carries Acceptance criteria taken from the
   spec's flows/states. Include a final responsive/accessibility pass step, a
   **Backend integration pass (staging)** step — prod flavor against a real
   **staging** project, never production — immediately before release prep,
   and a release-prep step with `depends_on` the integration pass. Then:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" validate      # must be clean
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" render plan   # writes PROJECT_PLAN.md
   ```
5. **`HUMAN_SETUP.md` → items.** Remove the checklist entries that don't
   apply; add the project's external/store items (RevenueCat dashboard +
   products, App Store Connect / Play Console IAP products, signing, API keys,
   legal URLs), each exact and copy-pasteable. Then turn every entry into an
   **item** so it gates the step it belongs to — one file each under
   `plan/items/`, from `${CLAUDE_PLUGIN_ROOT}/templates/plan/item.yaml.template`
   or via `kit item new --id <id> --title "<…>" --needs <kind> --blocks <step-id> --from bootstrap`
   — giving every one a runbook (`do` / `expect` / `if_fails`). Signing and
   store products block release-prep; a Firebase project blocks the backend
   integration pass; toolchain items block nothing. Run `kit validate`, then
   delete `HUMAN_SETUP.md` — the board (`/board`) is where the user reads
   their work from now on.
6. **Permissions** — write the project's Claude Code permissions so the build
   loop doesn't stall on prompts:
   ```bash
   mkdir -p .claude && cp "${CLAUDE_PLUGIN_ROOT}/templates/settings.json.template" .claude/settings.json
   ```
   If `.claude/settings.json` already exists, **merge** rather than overwrite:
   union the `allow`/`deny` lists, keep the user's existing entries. Show the
   user the allow list and let them trim it — it is deliberately broad (it
   includes `rm`, `git push`, `git reset --hard`) so unattended loops don't
   block; that is their call to make, not yours.
7. **Flutter rules** — copy the authoritative rule set into the project, because
   `CLAUDE.md` `@`-imports it and `@`-imports cannot reach the plugin directory:
   ```bash
   mkdir -p docs && cp "${CLAUDE_PLUGIN_ROOT}/reference/flutter-rules.md" docs/flutter-rules.md
   ```
   This is the one kit file that gets pinned into the project. `/kit-sync`
   refreshes it after a plugin update.
8. **`.gitignore`** — `flutter create` generated one in Stage 5. **Append** the
   kit's additions (secrets, the analyze-gate scratch queue) without duplicating
   lines already present:
   `${CLAUDE_PLUGIN_ROOT}/templates/gitignore.template`
8. **CI workflow** —
   ```bash
   mkdir -p .github/workflows && cp "${CLAUDE_PLUGIN_ROOT}/templates/ci.yml.template" .github/workflows/ci.yml
   ```
   (CI runs analyze + test; simulator verification stays local.)
9. **Build journal** — create `docs/BUILD_NOTES.md` with the one-line header:
   `Per-project build journal — appended by /step and /qa; read at the start of every step.`
10. **Emulator config** — write these files directly (no interactive
   `firebase init`):
   - `firebase.json` — emulator suite on non-default ports: ui 4040, hub 4441,
     auth 9199, firestore 8181, database 9100, storage 9299; rules file
     `firestore.rules`.
   - `.firebaserc` — default project `demo-<app>` (offline-only; the suite
     treats `demo-*` as needing no real project).
   - `firestore.rules` — a stub ruleset (deny-by-default) for plan steps to
     grow; the emulators exercise it continuously.
11. **App README** — replace the `flutter create` boilerplate `README.md` with a
    short app-specific one.

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

Note: the analyze gate installed by this plugin runs `dart analyze` at the end
of every turn and blocks on errors in files edited that turn. If it fires during
init, fix the reported errors — don't work around it.

### Stage 9 — Handoff
Print:
```
✅ Initialization complete.

Files ready:
- PRODUCT_SPEC.md  (full spec; assumptions all resolved)
- CLAUDE.md
- plan/            (<N> steps, <M> human items — derived from the spec)
- PROJECT_PLAN.md  (rendered from plan/; regenerated by every command)
- .claude/settings.json  (build-loop permissions)

Flutter project created and compiling.

Each /step builds a slice of the spec, then verifies the dev flavor on the iOS
simulator against the local Firebase emulators (optional demo fakes for edge
states) — checking every flow + dependent flows
for bugs, exceptions, and overflow (size-matrix widget tests). /qa runs the
full iOS sweep anytime (add "android" to the scope for an Android sweep).

To start building:
    /step
    /step <step-id>
    /plan-status
```

## What you must NOT do
- Don't wire emulators anywhere except under the dev environment guard, and
  never point dev at a real project.
- Don't write `pubspec.yaml` beyond what `flutter create` generates — Step 0
  (bootstrap) handles the full dependency set.
- Don't commit or push — leave the initial commit to the user.
- Don't edit anything under `${CLAUDE_PLUGIN_ROOT}/` — the plugin is read-only
  reference; changes there are wiped on the next plugin update.
- Don't finish init while any assumption is still unconfirmed.
