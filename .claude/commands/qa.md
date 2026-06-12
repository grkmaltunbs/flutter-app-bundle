---
description: Run an on-demand full QA sweep on the iOS simulator (Android only on explicit request)
argument-hint: [flow or scope]
allowed-tools: Read, Grep, Glob, Bash, Task, TodoWrite
---

Run a full QA sweep on the iOS simulator: $ARGUMENTS

Delegate to the **flutter-qa** agent. This is the **full milestone sweep** —
all flows plus the multi-size visual pass, on iOS by default. Use it to
re-check the whole app at milestones (e.g. before `/ship`, which runs it,
after a refactor, or when something feels off).

Scope:
- If `$ARGUMENTS` names a flow/feature/screen, verify that plus its dependent
  flows.
- If `$ARGUMENTS` is empty, run the **full** `integration_test/` suite plus the
  responsive/overflow pass across the entire size matrix.
- **Android is opt-in only.** Include Android only when `$ARGUMENTS` explicitly
  asks for it (e.g. `/qa android` or `/qa <flow> android`). Never boot an
  Android emulator otherwise.

The agent:
1. Boots a typical iOS simulator (plus smallest/largest for the responsive
   pass).
2. Runs the relevant integration tests on iOS against the **demo flavor**
   (`--dart-define=APP_ENV=demo`) — no Firebase emulators, never the live
   project.
3. Sweeps the Dart MCP runtime-error log for exceptions/overflow.
4. Runs the **multi-size visual pass** — screenshots at the smallest and
   largest iOS sizes. This pass belongs to this command (and pre-`/ship`)
   only; per-step gates never do it.
5. **Only when the user explicitly requested Android in the scope:** also
   boots a typical Android emulator (plus smallest/largest for the responsive
   pass), runs the same integration tests there against the demo flavor, and
   extends the multi-size visual pass with screenshots at the smallest and
   largest Android sizes.
6. Returns **PASS**, or **FAIL** with per-defect platform, verbatim error/
   screenshot, repro, and routing tag (`→ debugger` / `→ developer` / `→ tester`).

After the agent reports:
- On FAIL, summarize the defects and ask whether to route fixes now.
- If the user defers the fixes, record the defects durably: append a new step
  to `PROJECT_PLAN.md` — `## Step <next-N> — Fix defects from /qa <scope>` with
  a `- [ ]` checkbox, id `qa-defects-<n>`, `depends_on: none`, `spec_refs` from
  the affected flows, and the defect list verbatim in its Description — so
  `/plan-status` and `/step` surface them. Also append the root causes to
  `docs/BUILD_NOTES.md`.
- On PASS, report platforms run, flows exercised, and saved screenshots.

This command does not edit source code — it only runs and observes (deferred
defects are recorded in PROJECT_PLAN.md and docs/BUILD_NOTES.md).
