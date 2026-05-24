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
