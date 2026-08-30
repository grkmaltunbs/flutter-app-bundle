# flutter-kit

A Claude Code plugin for building Flutter apps. Human-in-the-loop — you direct,
Claude Code implements, and every step is gated on the app actually running.

## Install

```bash
/plugin marketplace add grkmaltunbs/flutter-app-bundle
/plugin install flutter-kit@flutter-app-bundle
```

Then, one-time setup:

```bash
claude mcp add dart -- dart mcp-server     # restart Claude Code afterwards
```

Verify with `claude mcp list` — `dart: ✓ Connected`.

## Installing into a project (v2, while in development)

```
claude plugin marketplace add ~/StudioProjects/flutter-app-bundle-2   # once per machine
cd <project> && claude plugin install flutter-kit@flutter-app-bundle --scope project
```

Two things to know:

- **Commands are namespaced** (`/flutter-kit:step`). A project that wants the
  bare names keeps one-line shims in `.claude/commands/` that forward to the
  plugin (see Nahmatik's). The project's own policy — QA runtime, backend,
  text scales, format paths — lives in `plan/kit.yaml` → `qa` and in
  `CLAUDE.md`; the plugin's commands and agents read it from there, so a
  project never copies a command to adapt it.
- **Claude Code copies an installed plugin** into `~/.claude/plugins/cache/`
  and refreshes the copy only on a version bump. While this branch changes
  daily, replace that copy with a symlink to the checkout:
  `rm -rf ~/.claude/plugins/cache/flutter-app-bundle/flutter-kit/<version> &&
  ln -s <checkout> ~/.claude/plugins/cache/flutter-app-bundle/flutter-kit/<version>`.
  Edits then apply on the next session.

## Use it on a new app

```bash
mkdir my-app && cd my-app && claude
/init-app
```

`/init-app` walks you through: app idea → design intake → a **29-category
requirements interview** → an **assumptions gate** (confirm or override every
default, so nothing is forgotten) → writes `PRODUCT_SPEC.md` → derives
`PROJECT_PLAN.md` from it → `flutter create` → setup walkthrough → smoke test.

Then build:

```
/step           # implement the next pending step
/step auth      # implement a specific step by id
/plan-status    # every step's state, computed — never stale
/next           # what *you* can do right now, grouped by what it needs
/blocks <id>    # everything between a step and done, and whose move it is
/done <item>    # close a human item; see what it unblocked
/board          # regenerate the board and republish it at its standing URL
```

## The plan is data, and the human is in it

v2's one structural change: `PROJECT_PLAN.md` is no longer the source of
truth — `plan/` is. Steps are `plan/steps/<id>.yaml`; the work only *you* can
do (a console, a physical phone, copy to read, a decision) is
`plan/items/<id>.yaml`, each saying what it **needs** and which step it
**blocks**. A step whose code is finished but whose items are open is *code
complete*, not done, and the tool refuses to say otherwise.

Everything you read is generated from that directory: `PROJECT_PLAN.md`,
and a board that groups your open items into sittings by what they need.
`kit validate` keeps the graph honest; `kit next` answers "what now" for both
of you. Schema: [`schema/README.md`](schema/README.md).

Migrating a project with a hand-written plan and a journal of `- [ ]` boxes:

```bash
bash "$PLUGIN/kit/kit.sh" import --plan-md PROJECT_PLAN.md --journal things_for_human_eye.md \
  --out plan --name "My App" --release-step store-submission
bash "$PLUGIN/kit/kit.sh" validate && bash "$PLUGIN/kit/kit.sh" render plan
```

The import is lossless on prose and heuristic on what nobody wrote down;
what it could not classify lands on the board under "could not sort".

The `kit` CLI is a Dart package under `kit/` (`dart test` there), compiled
to a native binary on first use.

## Use it on an existing app

```bash
cd my-existing-app && claude
/kit-sync       # installs permissions + the Flutter rules doc
```

Commands that don't depend on `PROJECT_PLAN.md` — `/feature`, `/fix`,
`/refactor`, `/app-review`, `/test`, `/qa`, `/codegen`, `/deps`, `/clean`,
`/ship` — work immediately. `/step` and `/plan-status` need a plan; run
`/init-app` in an adopted project to generate the spec and plan for it.

## Commands

| Command | What it does |
|---|---|
| `/init-app` | Full project initialization (idea → design → setup → scaffold) |
| `/step [id]` | Implement the next (or named) step from the plan |
| `/plan-status` | Every step's computed state and what it waits on |
| `/plan-extend` | Add, split, remove, reorder steps; add human items |
| `/next [id]` | What you can do right now, grouped by what it needs |
| `/blocks <id>` | Everything between a step and done |
| `/done <item>` | Close a human item and see what it unblocked |
| `/board` | Regenerate and republish the board |
| `/feature <desc>` | Implement a feature outside the plan |
| `/fix <desc>` | Debug and fix a bug |
| `/refactor <desc>` | Refactor with tests |
| `/app-review [files]` | Code review (read-only findings; asks before routing fixes) |
| `/test [files]` | Add or improve tests |
| `/qa [scope]` | Run/observe the app on the iOS simulator (Android on request) |
| `/ship [args]` | Prepare a release |
| `/codegen [args]` | Run build_runner / gen-l10n |
| `/clean` | Clean and rebuild |
| `/deps [args]` | Manage dependencies |
| `/kit-sync` | Refresh the kit files pinned into this project |

Commands are also reachable namespaced (`/flutter-kit:step`) when a bare name
collides with a built-in or another plugin.

## Agents

Specialist agents invoked automatically by the commands:

- **flutter-architect** — Plans features (no code, just design)
- **flutter-developer** — Implements features (Bloc + clean architecture)
- **flutter-debugger** — Finds and fixes bugs
- **flutter-refactorer** — Restructures code (test-driven)
- **flutter-releaser** — Builds and prepares releases
- **flutter-reviewer** — Reviews code (read-only findings)
- **flutter-tester** — Writes unit/bloc/widget/integration tests
- **flutter-qa** — Runs the app on the iOS simulator by default (Android only
  when explicitly requested), drives every flow, reports runtime errors and
  overflow (read-only)
- **flutter-ui-designer** — Builds polished UI components (routed to by `/step`
  and `/feature` for screens and visual polish)

## What the plugin ships

```
commands/     19 slash commands
agents/       9 specialist agents
skills/       19 Dart + Flutter skills
kit/          the plan engine — the `kit` CLI and the library behind it
schema/       what a plan/ directory is, field by field
hooks/        batched `dart analyze` gate (queue on edit, check at turn end)
              · `kit hook`, which spools session events for the app
reference/    flutter-rules.md · requirements-checklist.md · lessons-learned.md
templates/    CLAUDE.md · PRODUCT_SPEC · PROJECT_PLAN · HUMAN_SETUP · ci.yml
              · settings.json · gitignore · plan/ (kit.yaml · step · item)
app/          the desk-and-phone app over the same plan — see below
```

### Two files get pinned into your project

Plugins can't ship permissions, and a `CLAUDE.md` `@`-import can't reach the
plugin directory. So `/init-app` copies these into the project, where they then
go stale:

- `.claude/settings.json` — the allow/deny lists the build loop runs under
- `docs/flutter-rules.md` — the authoritative rule set, `@`-imported by `CLAUDE.md`

**`/kit-sync` re-syncs both.** Run it after a plugin update. It merges rather
than overwrites, and asks before replacing rules you've customised.

The permissions list is deliberately broad — it includes `rm`, `git push`, and
`git reset --hard` so long build loops don't stall on prompts. Read it and trim
what you don't want; `/kit-sync` reports the broad entries it adds.

## Requirements

- Flutter SDK (stable channel)
- Claude Code CLI (`claude login`)
- Dart MCP: `claude mcp add dart -- dart mcp-server`
- Firebase CLI + Java 11+ (if using Firebase, and Java only where
  `qa.backend: emulator` runs the local Emulator Suite):
  `npm install -g firebase-tools`
- Optional: the official `firebase` plugin. The settings template enables it;
  add its marketplace with
  `/plugin marketplace add anthropics/claude-plugins-official`.

## Verification approach

**The project sets the policy; the commands read it.** `plan/kit.yaml` → `qa`
is what `/step`, `/qa`, `/test`, `/fix` and `/feature` obey: `runtime` (the
device class), `backend` (`live` → runs hit the project's real Firebase with
`test_account_prefix` accounts and nothing else; `emulator` → the local
Emulator Suite under a `demo-*` id, offline, no real project needed),
`text_scales`, `narrowest_locale`, `format`, `runner`, `screenshots`. Where a
project's `kit.yaml` and this README disagree, the project wins. Where a
project says nothing, the defaults are the iOS simulator, `[1.0, 2.0, 3.12]`
and no screenshots.

Each `/step` is gated by the **flutter-qa** agent before it counts as done:

1. `flutter analyze` + `flutter test` — static + unit/bloc/widget tests
2. The new flow **and its dependent flows** driven via `integration_test` on
   `qa.runtime`, against whatever `qa.backend` names
3. Dart MCP runtime-error sweep — zero unhandled exceptions
4. Render safety — zero overflow via the widget-test size matrix
   (320-wide → iPad; small/Pixel/tablet Android) at every `qa.text_scales`
5. On FAIL only, and only where `qa.screenshots` allows: a screenshot of the
   failing screen as defect evidence

Every result is recorded — `kit gate <step> <gate> passed|failed` — so the
board tells the truth while a failure is being fixed. A passing gate is still
not *done*: a step whose human items are open is **code complete**, and `kit
step done` refuses to close it.

The full multi-size visual sweep lives in `/qa` (run it anytime) and runs
before every `/ship`; Android verification is available on explicit request
(e.g. `/qa android`) unless `qa.runtime` already says so.

## Architecture

Default stack (customizable during `/init-app`):

- **State:** flutter_bloc + freezed
- **Routing:** go_router
- **DI:** get_it + injectable (env-scoped: dev | demo | prod)
- **Local DB:** drift
- **Backend:** Firebase (optional) — behind repository interfaces (emulators in dev, optional fakes)
- **Payments:** RevenueCat (`purchases_flutter`); `.storekit` + fakes for sims
- **Lints:** very_good_analysis
- **Testing:** bloc_test, mocktail, integration_test (dev flavor on simulators)

Clean architecture with vertical feature slices:
`domain/` (pure Dart) → `data/` (infrastructure + `fakes/`) → `presentation/` (Flutter + Bloc)

## The desk-and-phone app (`app/`)

`app/` is a Flutter app over the same `plan/`: a **macOS host** that opens a
project folder, mirrors it, applies what the phone sends, watches Claude
Code's hooks and starts `claude remote-control` in the folder — and an
**Android remote** that shows the same two screens (Steps as bubbles, Your
work as sittings) and batches ticks, answers and notes behind *Send to
Claude*. Both link `kit/` directly, so a bubble is the same colour on both and
no derived state is stored anywhere. Build and layout: `app/README.md`; the
decisions behind it: `app/DESIGN.md`.

**It runs on the author's own relay** — one Firebase project
(`flutterappbundle`), owner-only rules pinned to a single uid in
`app/firestore.rules`. Installing the plugin copies these files but nothing
runs them: the commands, the board and `kit` all work with `app/` ignored. To
run it yourself, point `app/lib/firebase_options.dart` and those rules at a
Firebase project of your own.

## Local development

To work on the plugin itself without reinstalling:

```bash
claude --plugin-dir /path/to/flutter-app-bundle
```

Loads the plugin from the working tree for that session, so edits take effect
on restart rather than on publish.

## Lessons learned

`reference/lessons-learned.md` collects known pitfalls: Firebase emulator
gotchas, bootstrap order, iOS cold build times, CocoaPods conflicts, APNS on
the iOS simulator, and more.

## Autobuild runner (parked)

`runner/` holds `autobuild.py`, a headless Agent SDK driver that ran the whole
plan unattended. It is **not wired up in the plugin build** — it invoked `/step`
via `setting_sources=["project"]`, which no longer finds the command now that it
lives in a plugin. The code is kept for reference pending a rework. See
`runner/autobuild.md`.

## License

MIT

The 19 skills under `skills/` are derived from Google's official Dart and
Flutter skills, with local modifications noting this kit's conventions.
