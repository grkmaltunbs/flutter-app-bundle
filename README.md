# Flutter App Bundle for Claude Code

A starter kit for building Flutter apps with Claude Code. Human-in-the-loop
workflow — you direct, Claude Code implements.

## What's included

```
.claude/
├── commands/       Slash commands (/init-app, /step, /qa, /plan-status, etc.)
├── agents/         9 specialist agents (architect, developer, debugger, qa, …)
├── skills/         Official Dart + Flutter skills
└── settings.json   Permissions (allow/ask/deny lists)
templates/          CLAUDE.md, PRODUCT_SPEC, PROJECT_PLAN, HUMAN_SETUP templates
runner/             autobuild.py — headless autonomous build loop (Agent SDK)
docs/
├── requirements-checklist.md  29-category intake coverage engine
├── flutter-rules.md           Primary, authoritative Flutter/Dart rules
├── autobuild.md               Unattended autonomous builds (setup + safety)
└── lessons-learned.md         Known pitfalls and fixes
```

## Quick start

1. **Clone into your project directory:**
   ```bash
   mkdir my-app && cd my-app
   git clone https://github.com/grkmaltunbs/flutter-app-bundle.git .
   ```

2. **Set up MCP (one-time):**
   ```bash
   claude mcp add dart -- dart mcp-server
   ```
   Restart Claude Code. Verify: `claude mcp list` shows `dart: ✓ Connected`.

3. **Run init:**
   ```bash
   claude
   /init-app
   ```
   This walks you through: app idea → design intake → a **29-category
   requirements interview** → an **assumptions gate** (confirm/override every
   default so nothing is forgotten) → writes `PRODUCT_SPEC.md` → derives
   `PROJECT_PLAN.md` from it → `flutter create` → setup walkthrough → smoke test.

4. **Build step by step:**
   ```bash
   /step           # implement next pending step
   /step auth      # implement a specific step by id
   /plan-status    # see progress
   ```

5. **Or build the whole plan unattended** with the Agent SDK runner:
   ```bash
   pip install -r runner/requirements.txt
   caffeinate -i python3 runner/autobuild.py   # touch .autobuild-stop to halt
   ```
   It runs `/step` end-to-end for every pending step — implement, test, verify on
   the iOS + Android simulators, commit, push — stopping only when done, blocked
   on a human-only task, or a guardrail/budget trips. See `docs/autobuild.md`.

## Commands

| Command | What it does |
|---|---|
| `/init-app` | Full project initialization (idea → design → setup → scaffold) |
| `/step [id]` | Implement the next (or named) step from the plan |
| `/plan-status` | Show progress on all plan steps |
| `/plan-extend` | Add, split, or remove plan steps |
| `/feature <desc>` | Implement a feature outside the plan |
| `/fix <desc>` | Debug and fix a bug |
| `/refactor <desc>` | Refactor with tests |
| `/review [files]` | Code review (read-only) |
| `/test [files]` | Add or improve tests |
| `/qa [scope]` | Run/observe the app on iOS + Android simulators (fakes) |
| `/ship [args]` | Prepare a release |
| `/codegen [args]` | Run build_runner / gen-l10n |
| `/clean` | Clean and rebuild |
| `/deps [args]` | Manage dependencies |

## Agents

Specialist agents invoked automatically by commands:

- **flutter-architect** — Plans features (no code, just design)
- **flutter-developer** — Implements features (Bloc + clean architecture)
- **flutter-debugger** — Finds and fixes bugs
- **flutter-refactorer** — Restructures code (test-driven)
- **flutter-releaser** — Builds and prepares releases
- **flutter-reviewer** — Reviews code (read-only findings)
- **flutter-tester** — Writes unit/bloc/widget/integration tests
- **flutter-qa** — Runs the app on iOS + Android simulators, drives every flow,
  reports runtime errors and overflow (read-only)
- **flutter-ui-designer** — Builds polished UI components

## Requirements

- Flutter SDK (stable channel)
- Claude Code CLI (`claude login`)
- Dart MCP: `claude mcp add dart -- dart mcp-server`
- Firebase CLI (optional, if using Firebase): `npm install -g firebase-tools`

## Verification approach

**No Firebase emulators, no flutter-skill dependency.** Every backend sits behind
a repository interface with a seeded in-memory **fake**, wired under a **demo
flavor** (`--dart-define=APP_ENV=demo`). All verification runs that flavor on real
simulators — offline, deterministic, never touching the live project.

Each `/step` is gated by the **flutter-qa** agent before it counts as done:

1. `flutter analyze` + `flutter test` — static + unit/bloc/widget tests
2. The new flow **and its dependent flows** driven via `integration_test` on an
   **iOS simulator and an Android emulator**
3. Dart MCP runtime-error sweep — zero unhandled exceptions
4. Responsive pass — zero render (overflow) errors across the size matrix
   (iPhone SE → Pro Max → iPad; small/Pixel/tablet Android) at textScale 1.0 & 2.0
5. `xcrun simctl io "<device>" screenshot` — visual capture

Run it anytime with `/qa`.

## Architecture

Default stack (customizable during `/init-app`):

- **State:** flutter_bloc + freezed
- **Routing:** go_router
- **DI:** get_it + injectable (env-scoped: demo | prod)
- **Local DB:** drift
- **Backend:** Firebase (optional) — behind repository interfaces with fakes
- **Payments:** RevenueCat (`purchases_flutter`); `.storekit` + fakes for sims
- **Lints:** very_good_analysis
- **Testing:** bloc_test, mocktail, integration_test (demo flavor on simulators)

Clean architecture with vertical feature slices:
`domain/` (pure Dart) → `data/` (infrastructure + `fakes/`) → `presentation/` (Flutter + Bloc)

## Lessons learned

See `docs/lessons-learned.md` for known pitfalls:
- Why fakes, not Firebase emulators
- Firebase bootstrap order
- iOS cold build times
- CocoaPods conflicts
- APNS on the iOS simulator
- And more

## License

MIT
