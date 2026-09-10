---
name: kit-fix
description: "Reproduce a bug, fix its root cause, and lock it in with a regression test"
---

> **Where things are.** This file is `skills/kit-fix/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Before anything else set, in the shell, `PLUGIN` to that root (Claude Code: `${CLAUDE_PLUGIN_ROOT}`) and `KIT="$PLUGIN/kit/kit.sh"`; every `kit` command below runs as `bash "$KIT" …`, in the project folder. `$ARGUMENTS` means the words after `$kit-fix` in the user's message. Agents named in bold (flutter-tester, flutter-qa, …) are the Codex custom agents `$kit-codex-setup` installs into the project's `.codex/agents/`; spawn them by name, and where one is not installed do that part yourself.


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

3. Scoped runtime verification — **only if the fix touched widgets, routes,
   rendering/layout, or platform channels**: delegate to **flutter-qa** with the
   affected flow(s) and their regression set on the project's QA runtime
   (`plan/kit.yaml` → `qa`: runtime, backend, test-account prefix,
   screenshots). Do not declare the fix complete until it returns PASS. If
   the bug is Android-specific, say so explicitly and hand the user a manual
   Android repro/verify checklist instead of silently passing.
   Logic-only fixes skip this: they're gated by the regression test plus the
   full-suite run in step 2 (that run stays — it is this command's single
   authoritative suite run).

4. Summarize:
   - Root cause in one paragraph (not just "what was changed" — *why* it broke)
   - The fix (file:line)
   - The regression test that locks it in
   - Append the root cause to `docs/BUILD_NOTES.md`
