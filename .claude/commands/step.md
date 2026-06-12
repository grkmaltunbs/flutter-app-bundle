---
description: Implement the next pending PROJECT_PLAN.md step and verify it on both simulators
argument-hint: [step-id]
---

# /step — Implement the next plan step

Implement a step from PROJECT_PLAN.md. If `$ARGUMENTS` is provided, use it as the
step id. Otherwise, find the next pending step (first step whose dependencies are
all `[x]` and that isn't itself complete).

A step is **not done when the code compiles** — it's done when the feature has
been **verified running on the iOS and Android simulators**, with every flow (its
own and dependent ones) exercised and zero runtime errors or overflow.

## Workflow

1. **Read context.** Read `CLAUDE.md`, `PRODUCT_SPEC.md`, `PROJECT_PLAN.md`, and
   `docs/BUILD_NOTES.md` if it exists (the per-project journal of quirks and
   decisions). Find the target step and its `spec_refs` (the flows/screens it
   implements).

2. **Check dependencies.** Verify each `depends_on` step is `[x]`. If not, tell
   the user and stop.

3. **Implement.** Architect first if the step is a large/greenfield feature.
   Route screen/widget construction and visual polish to **flutter-ui-designer**
   and Bloc/data wiring to **flutter-developer**. Follow the architecture and
   hard rules in `CLAUDE.md` and the spec's flows/states exactly. Build the
   `prod` impls **and** their `demo`-flavor fakes (seeded for every state the
   flow needs).

4. **Write tests.** Delegate to **flutter-tester**: unit/bloc tests, widget
   tests, the **integration test(s) for each spec flow** (happy + every error/
   edge path, against the demo flavor), and the **responsive overflow-guard**
   test for any new/changed screens.

5. **Static quality gates** (all must pass, run after the tests exist):
   - `dart run build_runner build --delete-conflicting-outputs` (if codegen changed)
   - `dart format .`
   - `flutter analyze` — clean
   - `flutter test` — all unit/bloc/widget tests pass

6. **Runtime verification (gating).** Delegate to **flutter-qa** with the step's
   `spec_refs` and the **regression set** — the flows that depend on the same
   Blocs, routes, repositories, or data this step touched. flutter-qa boots both
   simulators, drives the new flow + dependent flows on the demo flavor, sweeps
   the Dart MCP runtime-error log, and runs the responsive/overflow pass across
   the size matrix. It returns **PASS** or **FAIL** with routed defects.

7. **Resolve & re-verify.** If flutter-qa returns FAIL, route each defect:
   `→ flutter-debugger` (bugs), `→ flutter-developer` (missing behaviour),
   `→ flutter-tester` (missing/flaky tests). Re-run step 6 until PASS. **Do not
   mark the step complete while any defect or runtime error remains.**

8. **Mark complete.** Only after flutter-qa returns PASS, flip the step's
   checkbox `- [ ]` → `- [x]` in `PROJECT_PLAN.md`.

9. **Commit the step.** `git add` the touched files plus `PROJECT_PLAN.md` and
   commit with message `step <id> — <title>`. **Skip this stage** when running
   headless under autobuild (the runner owns git — never run git in that mode)
   or when the user prefers manual git.

10. **Report.** What was built, files touched, test-count delta, the **flutter-qa
    verdict** (platforms run, flows exercised), and the saved screenshots (show
    the smallest + largest via Read). Append durable findings — new fake
    seeds/toggles, environment quirks, defect root causes — to
    `docs/BUILD_NOTES.md`.

## Rules
- Do NOT skip ahead to other steps.
- Do NOT mark a step complete if any quality gate, integration test, or QA check
  fails — no "minor" runtime errors or overflows.
- Verification runs the **demo flavor against fakes** — never Firebase emulators,
  never the live project.
- If you hit a wall, tell the user what's blocking and stop.
- Follow the architecture and hard rules in `CLAUDE.md` strictly.
- Prefer editing existing files over creating new ones.
