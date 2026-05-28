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
   **demo flavor** (`--dart-define=APP_ENV=demo`) — no emulators, never the live
   project.
3. Sweeps the Dart MCP runtime-error log for exceptions/overflow.
4. Captures screenshots at the smallest and largest sizes.
5. Returns **PASS**, or **FAIL** with per-defect platform, verbatim error/
   screenshot, repro, and routing tag (`→ debugger` / `→ developer` / `→ tester`).

After the agent reports:
- On FAIL, summarize the defects and ask whether to route fixes now.
- On PASS, report platforms run, flows exercised, and saved screenshots.

This command does not edit code — it only runs and observes.
