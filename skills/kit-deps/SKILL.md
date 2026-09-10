---
name: kit-deps
description: "Manage pub dependencies — add, upgrade, audit, or lock"
---

> **Where things are.** This file is `skills/kit-deps/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Before anything else set, in the shell, `PLUGIN` to that root (Claude Code: `${CLAUDE_PLUGIN_ROOT}`) and `KIT="$PLUGIN/kit/kit.sh"`; every `kit` command below runs as `bash "$KIT" …`, in the project folder. `$ARGUMENTS` means the words after `$kit-deps` in the user's message. Agents named in bold (flutter-tester, flutter-qa, …) are the Codex custom agents `$kit-codex-setup` installs into the project's `.codex/agents/`; spawn them by name, and where one is not installed do that part yourself.


Manage dependencies: $ARGUMENTS

Supported intents (parse from $ARGUMENTS):

- **add** `<package>` — add to `pubspec.yaml`, run `flutter pub get`,
  show a one-line summary of what the package does, flag if it pulls in
  large transitive dependencies. ASK before adding.

- **upgrade** — run `flutter pub outdated`, show what's out of date, propose
  upgrades grouped by risk (patch=auto, minor=auto, major=ask). Apply
  approved upgrades, run `flutter analyze` and `flutter test` after.

- **audit** — run `flutter pub deps`, identify:
  - Unused dependencies (search the lib/ tree for imports)
  - Duplicated functionality (e.g. two HTTP clients)
  - Pinned old versions worth bumping
  Surface findings, do not auto-remove anything.

- **lock** — verify `pubspec.lock` is committed and up to date.

Default (no intent given): run `flutter pub outdated` and report.

Hard rule: adding a dependency is the one "developer-level" operation that is
NOT auto-approved under aggressive autonomy. Always ask the user.

Project rule: no `version: any` pins. Every dependency in `pubspec.yaml` must
have a concrete `^x.y.z` constraint.
