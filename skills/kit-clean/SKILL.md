---
name: kit-clean
description: "Clean build artifacts and rebuild the project from scratch"
---

> **Where things are.** This file is `skills/kit-clean/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Before anything else set, in the shell, `PLUGIN` to that root (Claude Code: `${CLAUDE_PLUGIN_ROOT}`) and `KIT="$PLUGIN/kit/kit.sh"`; every `kit` command below runs as `bash "$KIT" …`, in the project folder. `$ARGUMENTS` means the words after `$kit-clean` in the user's message. Agents named in bold (flutter-tester, flutter-qa, …) are the Codex custom agents `$kit-codex-setup` installs into the project's `.codex/agents/`; spawn them by name, and where one is not installed do that part yourself.


Clean and rebuild the project.

Steps:
1. `flutter clean`
2. `rm -rf .dart_tool build`
3. `flutter pub get`
4. `dart run build_runner clean`
5. `dart run build_runner build --delete-conflicting-outputs`
6. `flutter gen-l10n` (if any ARB files changed)
7. `flutter analyze`

Report anything that broke as a result, since `clean` sometimes surfaces
issues hidden by stale build artifacts (notably stale `*.freezed.dart` /
`*.g.dart` / `*.config.dart` files).
