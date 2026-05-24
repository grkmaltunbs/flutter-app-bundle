Refactor: $ARGUMENTS

Workflow:

1. Delegate to the **flutter-refactorer** agent.

2. The agent will first verify test coverage on the target area. If coverage
   is insufficient, it will pause and delegate to **flutter-tester** to add
   characterization tests BEFORE touching production code.

3. The refactor proceeds in small, independently-green steps. Tests run after
   each step.

4. After the refactor:
   - `flutter analyze` clean
   - `flutter test` passes
   - No public API changes unless explicitly requested
   - Codegen rerun if any annotated source changed

5. Summarize improvements, files touched, and any follow-up refactors worth
   doing later.
