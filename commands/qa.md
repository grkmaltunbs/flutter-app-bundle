---
description: Run an on-demand full QA sweep on the project's QA runtime (integration tests + runtime-error sweep + the overflow matrix)
argument-hint: [flow or scope]
allowed-tools: Read, Grep, Glob, Bash, Task, TodoWrite
---

Run a full QA sweep on the project's QA runtime: $ARGUMENTS

Delegate to the **flutter-qa** agent. This is the **full milestone sweep** —
all flows plus the responsive/overflow pass. Use it to re-check the whole app
at milestones (e.g. before `/ship`, which runs it, after a refactor, or when
something feels off).

Scope:
- If `$ARGUMENTS` names a flow/feature/screen, verify that plus its dependent
  flows.
- If `$ARGUMENTS` is empty, run the **full** `integration_test/` suite plus the
  responsive/overflow pass across the entire size matrix.
- **`qa.runtime` only** (iOS simulator unless the manifest says otherwise);
  never another device class "to be thorough".
- **Screenshots only if `qa.screenshots` allows** — by default evidence is
  verbatim errors, test output, and widget-inspector dumps.

**Runtime policy comes from the project, not this file.** `plan/kit.yaml` →
`qa.runtime` names the device class (`ios-simulator` is the default; Android
only when it says so), `qa.screenshots` says whether evidence may be an image
(default no — evidence is verbatim errors, test output and widget-inspector
dumps), `qa.text_scales` lists the text scales the overflow matrix must cover
(default `[1.0, 2.0, 3.12]` — 3.12 is iOS's real largest setting), and
`CLAUDE.md`'s QA policy adds the project's own rules. Where they and this text
disagree, they win.

**Firebase guardrail (every agent in this kit):** the project is
`plan/kit.yaml` → `firebase.project`, verified at runtime with `firebase use`
or an explicit `--project <id>`; refuse any other project. `qa.backend`
decides the rest. **`live`** — every run (the app, the integration tests, QA)
hits that project: only accounts carrying the `qa.test_account_prefix`
prefix, never real user data, never destructive scripts, **no emulator wiring
anywhere**, and never a rules/functions/indexes deploy as a side effect of a
step — deploys happen only where a step says so. **`emulator`** — day-to-day
work targets the local Emulator Suite under a `demo-<app>` project id behind
the dev environment guard; the live project is for the backend integration
pass and releases. Either way, states the backend cannot produce on demand
(offline, injected errors) are covered at the bloc/widget layer with mocked
repositories — never with flavor fakes unless the project already has them.

The agent:
1. Boots a typical device of the `qa.runtime` class.
2. Runs the relevant integration tests under the `qa.backend` policy — with
   `qa.test_account_prefix` accounts against `firebase.project` when it is
   `live`, against the Emulator Suite when it is `emulator`.
3. Sweeps the Dart MCP runtime-error log (`mcp__dart__get_runtime_errors`)
   for exceptions/overflow.
4. Runs the **overflow-guard widget tests** across the full size matrix
   (smallest / typical / largest / tablet) at every scale in
   `qa.text_scales`, with `qa.narrowest_locale` on the narrowest screen.
5. Returns **PASS**, or **FAIL** with per-defect verbatim error, repro, and
   routing tag (`→ debugger` / `→ developer` / `→ tester`), plus any
   manual-checklist items the runtime cannot verify (second device, push
   delivery, sandbox IAP) — those become `device` items.

After the agent reports:
- On FAIL, summarize the defects and ask whether to route fixes now.
- If the user defers the fixes, record the defects durably: add a step
  `plan/steps/qa-defects-<n>.yaml` (copy
  `${CLAUDE_PLUGIN_ROOT}/templates/plan/step.yaml.template`; title
  "Fix defects from /qa <scope>", no dependencies, the defect list verbatim in
  its Description), run `kit validate`, so `/next` and `/step` surface them.
  Also append the root causes to `docs/BUILD_NOTES.md`.
- On PASS, report flows exercised and tests run.

This command does not edit source code — it only runs and observes (deferred
defects are recorded in `plan/` and `docs/BUILD_NOTES.md`).
