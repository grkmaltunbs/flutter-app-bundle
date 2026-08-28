---
description: Implement the next plan step and verify it at runtime before calling it done
argument-hint: [step-id]
---

# /step — Implement the next plan step

The plan lives in `plan/` (schema: `${CLAUDE_PLUGIN_ROOT}/schema/README.md`).
The project's plan markdown is a generated view of it — read it if you like,
never edit it. State is computed by `kit`, so start there:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" next --step     # the id to work
bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" show <id>       # the step, as markdown
bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" blocks <id>     # what it waits on
```

If `$ARGUMENTS` names a step, use that id; `kit blocks <id>` tells you whether
it can start. Otherwise `kit next --step` is the one to work: the active step
if there is one, else the first ready step in rank order. An empty answer
means every pending step is blocked — say by what (`kit status`) and stop.

A step is **not done when the code compiles.** It is done when it has been
**verified running** on the project's QA runtime with every flow (its own and
the dependent ones) exercised and zero runtime errors or overflow — and when
every human item that names it in `blocks:` is closed. `kit step done`
refuses otherwise, and that refusal is correct.

**Policy comes from the project, not this file.** Read `plan/kit.yaml` → `qa`
before anything else and obey it: `runtime` (the device class — `ios-simulator`
by default; Android only when it says so), `backend` (`live` → every run hits
`firebase.project` with `test_account_prefix` accounts, never real user data,
never destructive scripts, no emulator wiring, no deploy unless the step says
so; `emulator` → the local Emulator Suite under a `demo-<app>` id), `screenshots`
(default false — evidence is verbatim errors and test output), `text_scales`
(the overflow matrix; default `[1.0, 2.0, 3.12]`), `narrowest_locale`, `format`
(the paths `dart format` may touch), `runner` (a single-launch integration
runner, if the project has one), `test_accounts` (the fixed QA roster) and
`design_export`. `CLAUDE.md` adds the project's own rules. Where they and this
text disagree, they win.

## Workflow

1. **Read context.** `CLAUDE.md`, `docs/BUILD_NOTES.md` if it exists (the
   journal of quirks and defect root causes), and the step from `kit show
   <id>` — its Description, Acceptance and QA walkthrough sections are the
   spec, plus `qa.design_export` for anything visual and whatever the step's
   `spec_refs` name.

2. **Check it can start.** `kit blocks <id>` must show no missing
   dependencies. If it does, tell the user and stop — do not skip ahead.
   Then `bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" step start <id>`.

3. **Implement.** Architect first if the step is large or greenfield. Route
   screen/widget construction and visual polish to **flutter-ui-designer**
   and Bloc/data wiring to **flutter-developer**. Follow the architecture and
   hard rules in `CLAUDE.md` and the step's spec exactly.

4. **Write tests — before QA, not after.** Delegate to **flutter-tester**:
   unit/bloc tests, widget tests, the integration test(s) for the step's
   flows (happy path plus the error/edge paths reachable against the
   project's backend policy), and the **responsive overflow-guard** widget
   test for any new or changed screen — at every scale in `qa.text_scales`,
   with `qa.narrowest_locale` on the narrowest screen. A guard written after
   the gate means defects found after the gate, which means running the gate
   twice.

5. **Static gates.** Run, then record each:
   - `dart run build_runner build --delete-conflicting-outputs` (if codegen changed)
   - `dart format <qa.format>` — only those paths; `dart format .` is wrong
     wherever a project vendors code it does not own
   - `flutter analyze` — clean → `bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" gate <id> analyze passed`
   - `flutter test` — the workflow's **single full-suite run**; inner agents
     run only affected files → `bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" gate <id> tests passed --note "<count> tests, 0 skips"`

   A failed gate is recorded too (`gate <id> tests failed --note "…"`) so the
   board tells the truth while you fix it.

6. **Runtime verification (gating).** Run the step's integration tests
   yourself first — `qa.runner` while iterating, the per-file path for the
   gate — with the **regression set**: the flows sharing Blocs, routes,
   repositories or data with what this step touched (full suite only when it
   touched shared infrastructure). Keep the simulator booted between steps.
   Then delegate to **flutter-qa** for what needs eyes: widget-inspector
   probing, the Dart MCP runtime-error sweep (`mcp__dart__get_runtime_errors`),
   the largest text scale on the changed screens. Screenshots only if
   `qa.screenshots` allows them. It returns **PASS** or **FAIL** with routed
   defects. Record it: `bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" gate <id> qa passed --note "<n>/<m> integration, 0 runtime errors"`.

7. **Resolve and re-verify.** On FAIL route each defect — `→ flutter-debugger`
   (bugs), `→ flutter-developer` (missing behaviour), `→ flutter-tester`
   (missing/flaky tests) — re-run only the failed flow plus `flutter analyze`
   and the affected unit tests, then **one** final full step-6 pass. Never
   record `qa passed` while any defect or runtime error remains.

8. **Human items.** Anything the step produced that needs the user's hands,
   accounts or judgement — a console setting, a physical device, copy to
   read in a language you drafted, a decision — is an **item**, not a
   paragraph:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" item new --id <step>-<slug> \
     --title "<what to do, as an imperative>" --needs <console|device|read|look|decision|store|money|secret|know> \
     --blocks <id> --from <id> --body-file <path to the runbook markdown>
   ```

   Use `--blocks <id>` only if the step genuinely cannot be called done
   without it (a store product that must exist, a push that must be seen on
   a phone). Everything else is provenance only (`--from`), and gates nothing.
   Give every item a **runbook** — `do` / `expect` / `if_fails` — and a
   `verify:` command wherever a machine can read the result back (a deploy
   read-back, a `dig`, a Firestore document). A decision gets a `question:`
   with exactly one `recommended: true` option. Write the YAML by hand if the
   CLI flags are too coarse; `kit validate` checks it. Also append the durable
   finding to `docs/BUILD_NOTES.md` — the journal keeps the story, the item
   carries the work.

9. **Mark complete.**

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" step done <id>
   ```

   If it refuses because human items are open, the step is **code complete**
   and that is the honest state: leave it, tell the user which items (the
   refusal lists them), and point at `/next`. Never `--force`.

10. **Render and commit.**

    ```bash
    bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" validate
    bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" render plan
    bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" render board
    ```

    Then `git add` the touched files plus `plan/`, the plan markdown and the
    board HTML, and commit `step <id> — <title>`. Skip the commit when the
    user prefers manual git. Do **not** republish the artifact board here —
    the flutter-kit app mirrors `plan/` live, and the page is republished on
    demand with `/board`.

11. **Report.** What was built, files touched, test-count delta, the
    flutter-qa verdict, the step's state (`done` or `code complete — waiting
    on <items>`), and the items created — each with what it needs.

## Rules
- Do NOT skip ahead to other steps.
- Do NOT record a gate as passed that did not pass — no "minor" runtime
  errors or overflows.
- QA runs on `qa.runtime` only; never boot another device class from this
  command. Screenshots only where `qa.screenshots` allows.
- `qa.backend` is the law on what a run may touch — test accounts only, never
  real user data, never a deploy as a side effect (deploys happen only when the
  step's Description explicitly says so, and `firebase use` must show
  `firebase.project` first).
- If you hit a wall, tell the user what's blocking and stop.
- Follow the architecture and hard rules in `CLAUDE.md` strictly.
- Prefer editing existing files over creating new ones.
