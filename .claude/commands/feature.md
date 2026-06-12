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
   `dart run build_runner build --delete-conflicting-outputs` after any
   `@freezed` / `@JsonSerializable` / `@injectable` / `@DriftDatabase` edit.

3. Delegate to the **flutter-tester** agent to add bloc_tests, usecase tests,
   widget tests, the integration test(s) for each flow (happy + error/edge,
   demo flavor), the responsive overflow-guard test, and golden tests for
   visually-critical widgets. Build the `demo`-flavor fakes the flows need.

4. Delegate to the **flutter-reviewer** agent for a final audit against the
   hard rules (no `BuildContext` in events, no `setState` in build, no
   `MediaQuery.of`, no `GetIt.I` in BLoCs, paid features entitlement-gated,
   etc.). Address any blockers; surface important findings to the user.

5. Run `dart format .`, `flutter analyze`, `flutter test`. All green before
   proceeding.

6. **Runtime verification (gating).** Delegate to the **flutter-qa** agent with
   the feature's flows and the dependent-flow regression set. It boots the iOS
   and Android simulators, drives the new flow + dependent flows on the demo
   flavor, sweeps runtime errors, and runs the responsive/overflow pass. If it
   returns FAIL, route defects (`→ debugger` / `→ developer` / `→ tester`) and
   re-verify until PASS. Do not declare done while any runtime error or overflow
   remains.

7. Summarize:
   - What was built (one short paragraph)
   - Files added/modified
   - Test count delta
   - flutter-qa verdict (platforms run, flows exercised) + screenshots
   - Anything left as TODO and why

8. Record it in the plan: append the shipped feature to `PROJECT_PLAN.md` as a
   completed `[x]` step (id, spec_refs, one-line description) so the plan stays
   the source of truth for regression sets. Offer to update `PRODUCT_SPEC.md`
   with the new flow/screens.
