---
description: Review code and present prioritized findings — read-only, never auto-fixes
argument-hint: [files or scope]
allowed-tools: Read, Grep, Glob, Bash, Task, TodoWrite
---

Review code: $ARGUMENTS

Delegate to the **flutter-reviewer** agent.

If $ARGUMENTS is empty, review uncommitted changes (`git diff`). Otherwise
review the named files / feature.

The agent returns a prioritized list (Blockers / Important / Minor / Analyzer
output). Present the full list to the user. This command is **read-only** —
it never edits code. ASK the user before routing any fixes; only on their
approval hand Blockers to the appropriate agent (developer for code fixes,
tester for missing tests) as a follow-up.

**Runtime policy comes from the project, not this file.** `plan/kit.yaml` →
`qa.runtime` names the device class (`ios-simulator` is the default; Android
only when it says so), `qa.screenshots` says whether evidence may be an image
(default no — evidence is verbatim errors, test output and widget-inspector
dumps), `qa.text_scales` lists the text scales the overflow matrix must cover
(default `[1.0, 2.0, 3.12]` — 3.12 is iOS's real largest setting), and
`CLAUDE.md`'s QA policy adds the project's own rules. Where they and this text
disagree, they win.

**Firebase guardrail (every agent in this kit):** the project is
`plan/kit.yaml` → `firebase.project`, verified at runtime with `firebase use`
or an explicit `--project <id>`; refuse any other project. `qa.backend`
decides the rest. **`live`** — every run (the app, the integration tests, QA)
hits that project: only accounts carrying the `qa.test_account_prefix`
prefix, never real user data, never destructive scripts, **no emulator wiring
anywhere**, and never a rules/functions/indexes deploy as a side effect of a
step — deploys happen only where a step says so. **`emulator`** — day-to-day
work targets the local Emulator Suite under a `demo-<app>` project id behind
the dev environment guard; the live project is for the backend integration
pass and releases. Either way, states the backend cannot produce on demand
(offline, injected errors) are covered at the bloc/widget layer with mocked
repositories — never with flavor fakes unless the project already has them.