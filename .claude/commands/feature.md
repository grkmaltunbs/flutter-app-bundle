Implement a new feature end-to-end: $ARGUMENTS

Workflow:

1. Delegate to the **flutter-architect** agent to produce a plan (file tree,
   Bloc shape, test strategy). The architect scaffolds against
   `lib/features/_template/` for the reference structure. Show the plan to
   the user briefly.

2. Delegate to the **flutter-developer** agent to execute the plan
   bottom-up (domain → data → presentation). The developer runs
   `dart run build_runner build --delete-conflicting-outputs` after any
   `@freezed` / `@JsonSerializable` / `@injectable` / `@DriftDatabase` edit.

3. Delegate to the **flutter-tester** agent to add bloc_tests, usecase tests,
   widget tests, and golden tests for visually-critical widgets.

4. Delegate to the **flutter-reviewer** agent for a final audit against the
   v2 hard rules (no `BuildContext` in events, no `setState` in build, no
   `MediaQuery.of`, no `GetIt.I` in BLoCs, etc.). Address any blockers;
   surface important findings to the user.

5. Run `dart format .`, `flutter analyze`, `flutter test`. Everything green
   before declaring done.

6. Summarize:
   - What was built (one short paragraph)
   - Files added/modified
   - Test count delta
   - Anything left as TODO and why
