---
description: Run an on-demand QA sweep on the iOS and Android simulators
argument-hint: [flow or scope]
allowed-tools: Read, Grep, Glob, Bash, Task, TodoWrite
---

Run a full QA sweep on the iOS and Android simulators: $ARGUMENTS

Delegate to the **flutter-qa** agent. This is the on-demand version of the
verification phase that `/step` runs automatically — use it to re-check the whole
app (e.g. before `/ship`, after a refactor, or when something feels off).

Scope:
- If `$ARGUMENTS` names a flow/feature/screen, verify that plus its dependent
  flows.
- If `$ARGUMENTS` is empty, run the **full** `integration_test/` suite plus the
  responsive/overflow pass across the entire size matrix.

The agent:
1. Boots a typical iOS simulator and Android emulator (plus smallest/largest for
   the responsive pass).
2. Runs the relevant integration tests on **both** platforms against the
   **demo flavor** (`--dart-define=APP_ENV=demo`) — no Firebase emulators, never
   the live project.
3. Sweeps the Dart MCP runtime-error log for exceptions/overflow.
4. Captures screenshots at the smallest and largest sizes.
5. Returns **PASS**, or **FAIL** with per-defect platform, verbatim error/
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
