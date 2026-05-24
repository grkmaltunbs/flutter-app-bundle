# /step — Implement the next plan step

Implement a step from PROJECT_PLAN.md. If `$ARGUMENTS` is provided, use
it as the step id. Otherwise, find the next pending step (first step
whose dependencies are all done and that isn't marked complete in
PROJECT_PLAN.md).

## Workflow

1. **Read context.** Read CLAUDE.md, PROJECT_PLAN.md. Find the target step.
2. **Check dependencies.** If the step depends on other steps, verify
   those are marked `[x]` in PROJECT_PLAN.md. If not, tell the user.
3. **Implement.** Follow the step's Description section exactly.
   Write the code, create the files, follow the architecture in CLAUDE.md.
4. **Quality gates.** All must pass before you report done:
   - `dart run build_runner build` (if codegen files changed)
   - `dart format .`
   - `flutter analyze` — must be clean
   - `flutter test` — all tests must pass
5. **Write tests.** Every step should include unit tests and/or widget
   tests for the code it adds. Write integration tests for user-facing
   features.
6. **Take a screenshot.** If the app is running on a simulator:
   `xcrun simctl io "iPhone 16 Pro" screenshot docs/screenshots/<step-id>.png`
   Show the screenshot to the user via Read.
7. **Mark complete.** Edit PROJECT_PLAN.md to change the step's
   checkbox from `- [ ]` to `- [x]`.
8. **Report.** Tell the user what was built, what tests were added,
   and show the screenshot if available. Suggest running the app
   if they haven't already.

## Rules

- Do NOT skip ahead to other steps.
- Do NOT mark a step complete if quality gates fail.
- If you hit a wall, tell the user what's blocking and stop.
- Follow the architecture and hard rules in CLAUDE.md strictly.
- Prefer editing existing files over creating new ones.
