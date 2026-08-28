---
description: Implement a new feature end-to-end with tests and runtime verification
argument-hint: <description>
---

Implement a new feature end-to-end: $ARGUMENTS

Workflow:

1. Delegate to the **flutter-architect** agent to produce a plan (file tree,
   Bloc shape, test strategy). The architect scaffolds against
   `lib/features/_template/` for the reference structure. Show the plan to
   the user briefly.

2. Execute the plan bottom-up (domain → data → presentation). Route screen/
   widget construction and visual polish to the **flutter-ui-designer** agent
   and Bloc/data wiring to the **flutter-developer** agent. The developer runs
   `dart run build_runner build --delete-conflicting-outputs` **once per batch**
   of `@freezed` / `@JsonSerializable` / `@injectable` / `@DriftDatabase` edits
   (before the verify phase) — never per file.

3. Delegate to the **flutter-tester** agent to add bloc_tests, usecase tests,
   widget tests, the integration test(s) for each flow (happy + error/edge,
   dev flavor against the local emulators), the responsive overflow-guard
   test, and golden tests for visually-critical widgets. Add `demo`-flavor
   fakes only for states the emulator can't simulate (offline, injected
   errors).

4. Delegate to the **flutter-reviewer** agent for a final audit against the
   hard rules (no `BuildContext` in events, no `setState` in build, no
   `MediaQuery.of`, no `GetIt.I` in BLoCs, paid features entitlement-gated,
   etc.). Address any blockers; surface important findings to the user.

5. Run `dart format .`, `flutter analyze`, `flutter test`. All green before
   proceeding.

6. **Runtime verification (gating).** Delegate to the **flutter-qa** agent on
   the **iOS simulator** with the feature's flows and the dependent-flow
   regression set. It boots the iOS simulator, runs the flow's integration
   tests plus the regression set under the project's `qa` policy
   (`plan/kit.yaml`: runtime, backend, test-account prefix), and sweeps
   runtime errors — screenshots only where `qa.screenshots` allows; evidence
   is verbatim errors and test output. If it returns FAIL,
   route defects (`→ debugger` / `→ developer` / `→ tester`); after each fix
   re-run only the failed flow on the iOS simulator plus analyze + affected
   unit tests, then run one final full pass when all defects are green. Do
   not declare done while any runtime error or overflow remains. QA never
   touches Android; if the work changed `android/` or platform channels, note
   it for the user's manual device testing.

7. Summarize:
   - What was built (one short paragraph)
   - Files added/modified
   - Test count delta
   - flutter-qa verdict and flows exercised
   - Anything left as TODO and why

8. Record it in the plan: append the shipped feature to `PROJECT_PLAN.md` as a
   completed `[x]` step (id, one-line description) so the plan stays the
   source of truth for regression sets.
