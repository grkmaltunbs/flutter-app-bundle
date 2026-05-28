# Lessons learned

Things that bit us on previous projects. Read this BEFORE starting a
new app with this bundle.

## Dart MCP is the only required MCP

Register it in the project root:
```bash
claude mcp add dart -- dart mcp-server
```

It ships with the Dart SDK (which comes with Flutter). Provides:
analyze, format, hot reload, run tests, widget tree, runtime errors,
app logs, pub commands, symbol resolution.

Restart Claude Code after registering. Verify with `claude mcp list`.

## flutter-skill MCP is unreliable — don't use it

flutter-skill hangs indefinitely when connecting via the Python SDK and
frequently times out via `claude --print`. The binding initialization
(`FlutterSkillBinding.ensureInitialized()`) conflicts with
`WidgetsFlutterBinding`, causing Firebase and platform channels to fail.

**Use instead:**
- `xcrun simctl io "<device>" screenshot <path>` for screenshots
- `flutter test integration_test/` for interaction testing
- Dart MCP for widget tree, runtime errors, and app logs

## Firebase bootstrap order matters

`Firebase.initializeApp()` must complete BEFORE `configureDependencies()`
if DI registers lazy singletons for `FirebaseAuth.instance` or
`FirebaseFirestore.instance`.

Wrong:
```dart
configureDependencies();       // DI registered
await Firebase.initializeApp(); // Firebase not ready when DI resolves
```

Right:
```dart
await Firebase.initializeApp(); // Firebase ready
configureDependencies();        // DI can now resolve Firebase instances
```

Also: `main()` must be `async` and `await bootstrap()`. Using
`unawaited(bootstrap(...))` causes `Firebase.initializeApp()` to call
platform channels before the binding is ready.

## `flutter create` should run during /init-app, not Step 0

Several HUMAN_SETUP.md items need the Flutter project to exist:
- `flutterfire configure` needs `lib/`
- Xcode signing needs `ios/Runner.xcworkspace`
- `android/key.properties` needs `android/`

If `flutter create` is deferred to Step 0, you get a chicken-and-egg
deadlock: can't complete setup without the project, can't start the
project without completing setup.

Fix: `/init-app` runs `flutter create` during Stage 5 (before the
setup walkthrough), so all items can be completed immediately.

## No Firebase emulators — verify against fakes

This bundle does **not** use Firebase emulators. They were a recurring source of
pain — port collisions (`:8080` taken by Unity MCP, Tomcat, etc.), stale
processes holding ports after crashes, and `useFirestoreEmulator` /
`useAuthEmulator` hanging or throwing when the emulator wasn't running (which
blocks `runApp()` → blank white screen).

Instead, every backend dependency sits behind a repository interface with a
**seeded in-memory fake** (`lib/**/data/fakes/`), wired under the `demo`
environment via `injectable`. All verification runs the **demo flavor on real
simulators**:

```bash
flutter run --dart-define=APP_ENV=demo -d <device>
```

This is deterministic, offline, instant, and never touches the live project.
Seed fakes to cover every screen state (populated/empty/error/offline) and
entitlement state (free/subscribed/expired), and let them toggle error modes so
edge paths are testable. The real `prod` backend is exercised only by the human
in `HUMAN_SETUP.md` smoke items. See `CLAUDE.md` → "Flavors, fakes & no emulators".

## iOS cold builds are slow (3–7 minutes)

First iOS build after adding native dependencies (google_sign_in,
firebase_messaging, etc.) runs `pod install` + full Xcode compilation.
This is normal.

Warm the cache with:
```bash
flutter build ios --debug --simulator
```

Subsequent builds use the cache and are fast (~30s).

## CocoaPods version conflicts

After adding packages with native iOS deps, `pod install` may fail with
version conflicts. Fix:
```bash
pod repo update
cd ios && pod update <conflicting-pod> --repo-update
```

## iOS minimum deployment target

Set iOS platform to 14.0+ in `ios/Podfile`:
```ruby
platform :ios, '14.0'
```

Also update `IPHONEOS_DEPLOYMENT_TARGET` in `ios/Runner.xcodeproj/project.pbxproj`.
Firebase and Google Sign-In SDKs require iOS 14+.

## APNS on iOS Simulator

The simulator never receives APNS tokens. `getAPNSToken()` throws
`apns-token-not-set` in the simulator. This is non-fatal — guard with:
```dart
if (!Platform.environment.containsKey('SIMULATOR_DEVICE_NAME')) {
  // FCM registration
}
```

## Model cost awareness

| Model | Best for | Approximate cost |
|---|---|---|
| Opus 4.7 | Architecture, complex features, first-time implementations | ~$4–8/session |
| Sonnet 4.6 | UI tweaks, polish, repetitive work | ~$1–3/session |
| Haiku 4.5 | Smoke tests, simple queries | ~$0.10/session |

Use Opus for building features. Switch to Sonnet for polish and cleanup.
