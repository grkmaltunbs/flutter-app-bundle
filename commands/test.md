---
description: Add or improve tests for recent changes or a named scope
argument-hint: [files or scope]
---

Add or improve tests: $ARGUMENTS

Delegate to the **flutter-tester** agent.

If $ARGUMENTS is empty, target the most recent uncommitted changes
(`git diff`).

After the agent finishes:
- Run `flutter test` (full suite)
- Report coverage delta on the changed files only (not the whole project)
- Surface any production-code defects discovered during test writing —
  do NOT silently fix them; let the user route them to the debugger.

Integration tests run the **dev flavor against the local Emulator Suite** on a
simulator. Health-check the hub first (`curl http://localhost:4441`); if down,
start it (`firebase emulators:start --project demo-<app> --import .firebase/seed
--export-on-exit .firebase/seed`) or run headless via `firebase emulators:exec`.
States the emulator can't simulate (offline, injected errors) are covered at
the widget/bloc layer, or via demo-flavor fakes where they exist. NEVER the
live project (the Firebase project ID recorded in CLAUDE.md, Project overview →
"Firebase project"; verify at runtime via `firebase use`) — live project access
is reserved for the Backend integration pass against staging:
`flutter test integration_test/ --dart-define=APP_ENV=dev -d <device>`
