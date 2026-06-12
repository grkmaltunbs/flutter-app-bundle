---
description: Reproduce a bug, fix its root cause, and lock it in with a regression test
argument-hint: <bug description>
---

Fix this bug: $ARGUMENTS

Workflow:

1. Delegate to the **flutter-debugger** agent. They will:
   - Reproduce (preferably with a failing test)
   - Bisect to root cause
   - Apply a minimal fix
   - Confirm the regression test passes

2. After the debugger reports back:
   - Run `flutter analyze` — must be clean
   - Run `flutter test` — full suite must pass

3. Scoped runtime verification: delegate to **flutter-qa** with the affected
   flow(s) and their regression set on both platforms (demo flavor). Do not
   declare the fix complete until it returns PASS.

4. Summarize:
   - Root cause in one paragraph (not just "what was changed" — *why* it broke)
   - The fix (file:line)
   - The regression test that locks it in
   - Append the root cause to `docs/BUILD_NOTES.md`
