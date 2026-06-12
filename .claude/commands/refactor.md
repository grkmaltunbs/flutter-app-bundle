---
description: Refactor code in small, test-guarded steps with behavior unchanged
argument-hint: <what to refactor>
---

Refactor: $ARGUMENTS

Workflow:

1. Delegate to the **flutter-refactorer** agent.

2. The agent first verifies test coverage on the target area. If the
   refactorer reports insufficient coverage, this command pauses and
   delegates to **flutter-tester** for characterization tests BEFORE the
   refactor proceeds (the refactorer cannot delegate on its own).

3. The refactor proceeds in small, independently-green steps. Tests run after
   each step.

4. After the refactor:
   - `flutter analyze` clean
   - `flutter test` passes
   - No public API changes unless explicitly requested
   - Codegen rerun if any annotated source changed

5. If the refactor touched widgets, Blocs, or routes: delegate a scoped
   **flutter-qa** pass over the affected flows (both platforms, demo flavor) —
   behavior must be observably unchanged.

6. Summarize improvements, files touched, and any follow-up refactors worth
   doing later.
