---
name: kit-codegen
description: "Run build_runner code generation and verify the output"
---

> **Where things are.** This file is `skills/kit-codegen/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Before anything else set, in the shell, `PLUGIN` to that root (Claude Code: `${CLAUDE_PLUGIN_ROOT}`) and `KIT="$PLUGIN/kit/kit.sh"`; every `kit` command below runs as `bash "$KIT" …`, in the project folder. `$ARGUMENTS` means the words after `$kit-codegen` in the user's message. Agents named in bold (flutter-tester, flutter-qa, …) are the Codex custom agents `$kit-codex-setup` installs into the project's `.codex/agents/`; spawn them by name, and where one is not installed do that part yourself.


Run code generation: $ARGUMENTS

If $ARGUMENTS is empty, run a one-shot build:
`dart run build_runner build --delete-conflicting-outputs`

If $ARGUMENTS contains "watch", run watch mode:
`dart run build_runner watch --delete-conflicting-outputs`

If $ARGUMENTS contains "clean", run:
`dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs`

If $ARGUMENTS contains "l10n", also run `flutter gen-l10n`.

After codegen, run `flutter analyze` and report any new errors introduced
by stale generators or conflicting types. Also check that the generated
files (`*.freezed.dart`, `*.g.dart`, `*.config.dart`, `*.drift.dart`) are
checked into git — they're committed in this repo so CI doesn't need to
run build_runner.
