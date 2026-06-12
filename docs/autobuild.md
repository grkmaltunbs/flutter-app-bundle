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
   If pending steps remain but their deps can never be met (a dependency
   deadlock), they're reported as **unrunnable** — never silently treated as
   "complete".
2. Run a `query()` (Opus, `bypassPermissions`) that follows `step.md`, delegating
   to the developer/tester/qa agents and using the Dart MCP (+ Firebase MCP).
3. If the step flips to `[x]`, QA returned PASS, and the run succeeded → `git
   commit` + `git push origin main`.
4. Stop on: all steps done · a `blocked` step needing human action · N
   consecutive failures · budget cap · wall-clock cap · a kill file.

## Prerequisites

- **Claude Code CLI** installed and authenticated (`claude login`) — the SDK
  spawns it. `ANTHROPIC_API_KEY` also works for API-key auth. For
  unattended/headless auth the supported path is `claude setup-token`, then
  `export CLAUDE_CODE_OAUTH_TOKEN=…`. Note: starting **June 15, 2026**, Agent
  SDK / `claude -p` usage on subscription plans draws from a separate monthly
  **Agent SDK credit** (distinct from your interactive limits). Also note that
  `AUTOBUILD_BUDGET_USD` tracks API-style cost accounting, which is **not**
  meaningful quota accounting under subscription auth — treat it as a relative
  cap, not real dollars.
- **Python 3.10+** in a virtual environment with the SDK installed:
  ```bash
  python3 -m venv runner/.venv
  source runner/.venv/bin/activate          # Windows: runner\.venv\Scripts\activate
  pip install -r runner/requirements.txt    # installs claude-agent-sdk
  ```
- **Flutter toolchain** + a booted **iOS simulator** and **Android emulator**.
- **Dart MCP** available (`dart mcp-server` — ships with the SDK).
- A completed `/init-app` (so `PRODUCT_SPEC.md` + `PROJECT_PLAN.md` exist).
- **Firebase MCP (optional)**: only needed if a step does real Firebase config.
  Provide a **service account** — `firebase login` is interactive and won't work
  unattended. Export `GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json`. Without it
  the Firebase MCP is disabled and the build runs against fakes (which is the
  normal verification path anyway).

## Run

Always run via the venv's interpreter (or `source .../activate` first).
`caffeinate` keeps the Mac awake so the simulators keep running:

```bash
# Smoke-test the wiring FIRST — runs one step, no commit/push, prints the diff:
runner/.venv/bin/python runner/autobuild.py --dry-run

# Then the full unattended loop:
caffeinate -i runner/.venv/bin/python runner/autobuild.py
```

Clean stop after the current step:

```bash
touch .autobuild-stop      # delete it to resume later
```

Progress streams to the terminal and to `autobuild.log`. Blocked items are
appended to `AUTOBUILD_NEEDS_HUMAN.md`.

### Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Run **one** step, **no commit/push**; print what it would commit. Leaves the implemented changes in the working tree (revert with `git checkout . && git clean -fd` to re-run). |
| `--once` | Process exactly one step (commit + push as configured), then exit — step the plan manually. |
| `--step ID` | Target a specific step id (single-step; runs even if deps are unmet). |
| `--no-push` | Commit but never push, regardless of `AUTOBUILD_PUSH`. |

No flags = the full loop: every pending step, each in a **fresh context**,
committing and pushing as it goes.

## Configuration (environment variables)

| Var | Default | Meaning |
|-----|---------|---------|
| `AUTOBUILD_PROJECT` | `.` | Project root (contains `PROJECT_PLAN.md`) |
| `AUTOBUILD_MODEL` | `claude-opus-4-8` | Model for each step |
| `AUTOBUILD_MAX_TURNS` | `60` | Max agentic turns per step (iOS builds are slow) |
| `AUTOBUILD_BUDGET_USD` | `50` | Total spend cap across the run |
| `AUTOBUILD_MAX_FAILURES` | `2` | Consecutive step failures before halting |
| `AUTOBUILD_WALLCLOCK_HOURS` | `8` | Max total runtime |
| `AUTOBUILD_STEP_TIMEOUT_MIN` | `120` | Per-step time limit (minutes); a step that exceeds it is cancelled and counted as a failure |
| `AUTOBUILD_PUSH` | `main` | `main` · `branch:<name>` · `off` |
| `GOOGLE_APPLICATION_CREDENTIALS` | — | Firebase service-account JSON (enables Firebase MCP) |
| `AUTOBUILD_SLACK_WEBHOOK` | — | Optional Slack webhook for notifications |

## Safety model — stricter than your interactive session

Nobody is watching, so the runner is intentionally more locked down than the
permissive `settings.json` you use interactively:

- Runs `permissionMode: bypassPermissions` (never blocks on a prompt), but a
  **`PreToolUse` guardrail hook** + a **deny list** still block `rm -rf` — and
  its flag variants (`-fr`, `-r -f`, `-Rf`, `--recursive --force`) — `sudo`,
  `git reset --hard`, fork bombs, raw disk writes, and **prod `firebase deploy`**
  — even though interactive settings allow some of these.
- The agent is **hard-blocked from `git commit`/`add`/`rebase`/`merge` as well
  as push** (guardrail hook + disallowed tools); the *driver* commits and pushes
  deterministically, so history stays clean and intentional.
- Failed or blocked attempts **restore the working tree**
  (`git checkout -- . && git clean -fd`), so every retry starts from a clean
  slate instead of on top of a half-finished step.
- A **push preflight at startup**: the runner refuses to push while `origin`
  still points at the `flutter-app-bundle` template repo, and otherwise verifies
  push access with `git push --dry-run` — on failure it downgrades to
  `AUTOBUILD_PUSH=off` and notifies you rather than failing mid-run.
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
- **Firebase MCP command** in `mcp_servers()` is
  `["npx", "-y", "firebase-tools", "mcp"]` (`firebase mcp` replaced the old
  `experimental:mcp`). It may still need to match your
  `claude mcp get firebase` invocation — adjust if your plugin registers it
  differently.
- The runner invokes the slash command **natively**: the prompt is literally
  `/step <id>` (the SDK loads project slash commands via
  `setting_sources=["project"]`), with the unattended rules and the
  `AUTOBUILD_RESULT` marker contract riding in an appended system prompt.
  `step.md` remains the **single source of truth**, executed natively by both
  the interactive and headless paths.
