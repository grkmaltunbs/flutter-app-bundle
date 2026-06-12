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

Integration tests run the **demo flavor against fakes** on a simulator — no
Firebase emulators, and NEVER the live project (the Firebase project ID
recorded in CLAUDE.md, Project overview → "Firebase project"; verify at
runtime via `firebase use`):
`flutter test integration_test/ --dart-define=APP_ENV=demo -d <device>`
