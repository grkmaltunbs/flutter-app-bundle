---
name: kit-refactor
description: "Refactor code in small, test-guarded steps with behavior unchanged"
---

> **Where things are.** This file is `skills/kit-refactor/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Before anything else set, in the shell, `PLUGIN` to that root (Claude Code: `${CLAUDE_PLUGIN_ROOT}`) and `KIT="$PLUGIN/kit/kit.sh"`; every `kit` command below runs as `bash "$KIT" …`, in the project folder. `$ARGUMENTS` means the words after `$kit-refactor` in the user's message. Agents named in bold (flutter-tester, flutter-qa, …) are the Codex custom agents `$kit-codex-setup` installs into the project's `.codex/agents/`; spawn them by name, and where one is not installed do that part yourself.


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

5. If the refactor changed widget trees/layout, navigation structure, or DI
   wiring: delegate a scoped **flutter-qa** pass over the affected flows (iOS
   simulator, dev flavor against the local emulators) — behavior must be
   observably unchanged. A pure
   logic/Bloc-internal refactor with green characterization tests does not
   need a QA pass.

6. Summarize improvements, files touched, and any follow-up refactors worth
   doing later.
