# flutter-kit — working in this checkout

This repo is three things: the **flutter-kit plugin** (`commands/`, `agents/`,
`skills/`, `hooks/`, `assets/`), the **`kit` CLI** (`kit/`, pure Dart) and the
**K.A.T.Y.A app** (`app/`, Flutter — the Mac host and the phone). It is built
with its own plugin, on either engine: `/step` in Claude Code, `$kit-step`
in Codex. Both read this file; Codex through `.codex/config.toml`.

## The plan is data

`plan/steps/<id>.yaml` and `plan/items/<id>.yaml` are the source of truth;
`PROJECT_PLAN.md` and `docs/board/` are rendered from them — never edit
those by hand. The kit under development is the one in `kit/`: run it as
`bash kit/kit.sh <command>` from this folder (`next --step`, `show <id>`,
`blocks <id>`, `step done <id>`, `render plan`, `validate`), not the
installed plugin's copy, which is a snapshot (Codex) or a symlink (Claude).

## A step, start to finish

1. implement (design decisions go into `app/DESIGN.md`, a section per built
   step, dated);
2. both suites green — `cd kit && dart test`, `cd app && flutter test` —
   and `flutter analyze` clean; there is **no `dart format` gate** and no
   reformatting sweep (see `plan/kit.yaml` → `qa`);
3. the step's gates, then **runtime QA**: `bash app/tool/ship.sh mac` puts
   the host in `~/Applications` and relaunches it; `ship.sh android`
   installs the phone build over USB. The phone is driven over adb
   (`screencap`, `input tap`), the Mac window on screen;
4. `bash kit/kit.sh step done <id>` (it refuses while a human item that
   blocks the step is open — that refusal is right), `render plan`;
5. commit and **push** — every step is pushed when done. Messages read
   `app: …`, `kit: …` or `step <id> — …`.

## Rules that are not in the code

- **QA rig.** Sessions, worktrees, pushes and Codex threads are exercised on
  `~/kit-scratch` (relay slug `scratch`). The user's real projects that the
  host knows (Nahmatik, 101Okey) are never started, edited or sent turns
  during QA.
- **Subscriptions only.** Both engines run on the user's plans (Claude, and
  ChatGPT Pro for Codex). Never suggest API-key billing as a fix.
- **The user's files.** `~/.claude.json`, `~/.claude/settings.json`,
  `~/.codex/config.toml` are theirs: when a change there is unavoidable,
  say exactly what changed and how to undo it.
- **Live bridge tests** spawn the real `claude`/`codex` and spend quota:
  they run only with `KIT_LIVE=1`.
- **Codex lives in the ChatGPT app** (`/Applications/ChatGPT.app/Contents/Resources/codex`,
  not on PATH); Browser use needs the app open. Don't quit it.
- **Plugin copies.** Claude Code's cache is a symlink to this checkout.
  Codex's is a real copy: after a change to `skills/`, `hooks/` or `kit/`,
  refresh it with `codex plugin add flutter-kit@flutter-app-bundle` (a
  symlinked cache reads as not installed).

## Where to read first

`README.md` (what the plugin does, both engines), `app/DESIGN.md` (every
decision, the bridge protocol, the Codex protocol as proven, the relay
shape), `schema/README.md` (the plan schema), `kit/test` and `app/test`
(the protocol shapes live in the tests).
