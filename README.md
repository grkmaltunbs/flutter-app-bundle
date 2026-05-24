# Flutter App Bundle for Claude Code

A starter kit for building Flutter apps with Claude Code. Human-in-the-loop
workflow — you direct, Claude Code implements.

## What's included

```
.claude/
├── commands/       Slash commands (/init-app, /step, /plan-status, etc.)
├── agents/         8 specialist agents (architect, developer, debugger, etc.)
├── skills/         10 Flutter-specific skills
└── settings.json   Permissions (allow/ask/deny lists)
templates/          CLAUDE.md, PROJECT_PLAN.md, HUMAN_SETUP.md templates
docs/
└── lessons-learned.md  Known pitfalls and fixes
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
   This walks you through: app idea → design intake → creative pass →
   fill project files → `flutter create` → setup walkthrough → smoke test.

4. **Build step by step:**
   ```bash
   /step           # implement next pending step
   /step auth      # implement a specific step by id
   /plan-status    # see progress
   ```

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
- **flutter-tester** — Writes and runs tests
- **flutter-ui-designer** — Builds polished UI components

## Requirements

- Flutter SDK (stable channel)
- Claude Code CLI (`claude login`)
- Dart MCP: `claude mcp add dart -- dart mcp-server`
- Firebase CLI (optional, if using Firebase): `npm install -g firebase-tools`

## Verification approach

No flutter-skill dependency. The bundle verifies work via:

1. `flutter analyze` — static analysis
2. `flutter test` — unit + widget tests
3. `flutter test integration_test/` — integration tests on simulator
4. `xcrun simctl io "<device>" screenshot` — visual verification

## Architecture

Default stack (customizable during `/init-app`):

- **State:** flutter_bloc + freezed
- **Routing:** go_router
- **DI:** get_it + injectable
- **Local DB:** drift
- **Backend:** Firebase (optional)
- **Lints:** very_good_analysis
- **Testing:** bloc_test, mocktail, integration_test

Clean architecture with vertical feature slices:
`domain/` (pure Dart) → `data/` (infrastructure) → `presentation/` (Flutter + Bloc)

## Lessons learned

See `docs/lessons-learned.md` for known pitfalls:
- Firebase bootstrap order
- iOS cold build times
- CocoaPods conflicts
- Emulator port collisions
- And more

## License

MIT
