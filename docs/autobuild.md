# Autobuild — unattended autonomous builds

`runner/autobuild.py` drives the bundle through `PROJECT_PLAN.md` with **no human
in the loop**. For each pending step it runs a fresh Claude Agent SDK `query()`
that follows `.claude/commands/step.md` — implement → test → verify on the iOS
and Android simulators (demo flavor, fakes) — and the runner commits each verified
step and pushes to `main`.

This is the headless twin of running `/step` over and over yourself. Use it once
the plan is solid and the simulators work; babysit the first run.

## What it does each iteration

1. Parse `PROJECT_PLAN.md`, pick the next step whose deps are `[x]` and that
   isn't done. (`PROJECT_PLAN.md` is the source of truth — fresh context per step.)
2. Run a `query()` (Opus, `bypassPermissions`) that follows `step.md`, delegating
   to the developer/tester/qa agents and using the Dart MCP (+ Firebase MCP).
3. If the step flips to `[x]`, QA returned PASS, and the run succeeded → `git
   commit` + `git push origin main`.
4. Stop on: all steps done · a `blocked` step needing human action · N
   consecutive failures · budget cap · wall-clock cap · a kill file.

## Prerequisites

- **Claude Code CLI** installed and authenticated (`claude login`) — the SDK
  spawns it. `ANTHROPIC_API_KEY` also works for API-key auth.
- **Python 3.10+**: `pip install -r runner/requirements.txt`
- **Flutter toolchain** + a booted **iOS simulator** and **Android emulator**.
- **Dart MCP** available (`dart mcp-server` — ships with the SDK).
- A completed `/init-app` (so `PRODUCT_SPEC.md` + `PROJECT_PLAN.md` exist).
- **Firebase MCP (optional)**: only needed if a step does real Firebase config.
  Provide a **service account** — `firebase login` is interactive and won't work
  unattended. Export `GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json`. Without it
  the Firebase MCP is disabled and the build runs against fakes (which is the
  normal verification path anyway).

## Run

```bash
# caffeinate keeps the Mac awake so the simulators keep running:
caffeinate -i python3 runner/autobuild.py
```

Clean stop after the current step:

```bash
touch .autobuild-stop      # delete it to resume later
```

Progress streams to the terminal and to `autobuild.log`. Blocked items are
appended to `AUTOBUILD_NEEDS_HUMAN.md`.

## Configuration (environment variables)

| Var | Default | Meaning |
|-----|---------|---------|
| `AUTOBUILD_PROJECT` | `.` | Project root (contains `PROJECT_PLAN.md`) |
| `AUTOBUILD_MODEL` | `claude-opus-4-8` | Model for each step |
| `AUTOBUILD_MAX_TURNS` | `60` | Max agentic turns per step (iOS builds are slow) |
| `AUTOBUILD_BUDGET_USD` | `50` | Total spend cap across the run |
| `AUTOBUILD_MAX_FAILURES` | `2` | Consecutive step failures before halting |
| `AUTOBUILD_WALLCLOCK_HOURS` | `8` | Max total runtime |
| `AUTOBUILD_PUSH` | `main` | `main` · `branch:<name>` · `off` |
| `GOOGLE_APPLICATION_CREDENTIALS` | — | Firebase service-account JSON (enables Firebase MCP) |
| `AUTOBUILD_SLACK_WEBHOOK` | — | Optional Slack webhook for notifications |

## Safety model — stricter than your interactive session

Nobody is watching, so the runner is intentionally more locked down than the
permissive `settings.json` you use interactively:

- Runs `permissionMode: bypassPermissions` (never blocks on a prompt), but a
  **`PreToolUse` guardrail hook** + a **deny list** still block `rm -rf`, `sudo`,
  `git reset --hard`, fork bombs, raw disk writes, and **prod `firebase deploy`**
  — even though interactive settings allow some of these.
- The **agent is forbidden from running any `git` push/commit**; the *driver*
  commits and pushes deterministically, so history stays clean and intentional.
- Per-step commit = every checkpoint is recoverable; `AUTOBUILD_PUSH=branch:…`
  or `off` if pushing straight to `main` unattended feels too aggressive.
- A step that hits a human-only dependency (store IAP products, signing, real API
  keys) **stops and records it** in `AUTOBUILD_NEEDS_HUMAN.md` rather than faking
  past it.

## Caveats

- **The Mac must stay awake and unlocked** — simulators need a live GUI session.
  Use `caffeinate`; don't run it against a locked console.
- **Cost is real.** A full plan on Opus can run into dollars; the budget cap is
  your backstop. Watch `autobuild.log` on the first run.
- **Firebase MCP command** in `mcp_servers()` may need to match your
  `claude mcp get firebase` invocation — adjust if your plugin registers it
  differently.
- Slash commands aren't loaded by the SDK, so the runner has the agent **read
  `step.md`** rather than invoking `/step`. Keep that file authoritative.
