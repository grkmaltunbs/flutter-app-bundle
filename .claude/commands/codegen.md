---
description: Run build_runner code generation and verify the output
argument-hint: [watch|clean|l10n]
---

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
