# CLAUDE.md — 101 Okey Açar Mı

> Açar mı? Bir bakışta öğren.
> A camera-based tile solver for the Turkish games 101 Okey and plain Okey.

## Project overview

**101 Okey Açar Mı** lets a player photograph their rack (istaka) and, fully
on-device, **detects every tile by number + color** (OpenCV segmentation + Google
ML Kit recognition, exploiting the 2-row rack layout), lets the user review/correct
the reading and **pick the indicator (gösterge)**, then runs a **solver** for the
best legal arrangement. In **101 mode** it answers **"Açar / Açmaz"** (does the hand
reach ≥101, or the 5-pairs open) with the score; in **Okey mode** it shows the best
arrangement + tiles-to-win. Audience: Turkish Okey players (Turkish-first, English
secondary). Stage: **greenfield**. Monetised with **AdMob** banner + rewarded ads and
a **RevenueCat** "remove ads" subscription. The full spec — every flow, screen state,
and the authoritative game rules — is in **`PRODUCT_SPEC.md`**; UI follows the design
bundle in `docs/design/101-okey-acar-mi/`. UI-fidelity and **zero-overflow** on the
variable-length rack (14–21 tiles, 2 rows) are hard constraints.

**Bundle ID:** `com.okeyacarmi.okey_acar_mi`
**Firebase project (if any):** _TBD — set after `flutterfire configure` (see HUMAN_SETUP.md)._

## Architecture

Layered Clean Architecture, organised in **vertical slices** (one folder per
feature, each with its own `domain/`, `data/`, `presentation/`).

```
lib/
├── main.dart
├── bootstrap.dart              Pre-runApp init (env, DI, backend, error zone)
├── app.dart                    MaterialApp.router + global providers
├── core/                       Cross-cutting kernel
│   ├── di/                     get_it + injectable (env-scoped registration)
│   ├── env/                    AppEnv (demo | prod) from --dart-define
│   ├── error/                  Failure sealed hierarchy + error mapper
│   ├── extensions/             context.colors, context.l10n, context.mq
│   ├── logging/                Talker wrapper
│   ├── network/                ConnectivityService
│   ├── payments/               RevenueCat wrapper + entitlement interface
│   ├── router/                 go_router declarative
│   ├── theme/                  AppTheme, AppColors, AppTypography
│   ├── time/                   Clock (inject; never raw DateTime.now())
│   └── widgets/                Shared widgets
└── features/
    ├── _template/              Reference skeleton — copy for new features
    └── <feature_name>/
        ├── data/
        │   ├── datasources/
        │   ├── dtos/
        │   ├── repositories/   real (prod) repository impls
        │   └── fakes/          in-memory seeded fakes (demo flavor)
        ├── domain/{entities, repositories, usecases}/
        └── presentation/{blocs, pages, widgets}/
```

### Layer rules

- `domain/` — **pure Dart.** Must NOT import: `flutter/*`, Firebase,
  drift, data layer, presentation layer.
- `data/` — infrastructure. May import: own feature's `domain/`, `core/`.
  DTOs own JSON serialization. Repository impls map infra errors → `Failure`.
- `presentation/` — Flutter. May import: own feature's `domain/`, `core/`.
  **Must NOT** import `data/`.

### Hard rules

- **No `BuildContext` in events.** Side effects via `BlocListener`.
- **No `setState()` inside `build()`.** Ever.
- **Use `MediaQuery.sizeOf(context)`** — never `MediaQuery.of`.
- **Inject `Clock`** (`core/time/clock.dart`). Never raw `DateTime.now()`.
- **All `StreamSubscription`, `*Controller`, `FocusNode`** must be disposed.
- **All Firestore queries:** `.where('ownerId', isEqualTo: uid)` + `.limit(...)`.
- **All multi-doc writes:** `WriteBatch` or `runTransaction`.
- **BLoCs screen-scoped via `BlocProvider(create:)` by default.**
- **Every BLoC overrides `close()`** if it holds subscriptions.
- **Every paid feature is gated through `SubscriptionBloc`** (entitlement check)
  — never read a purchase SDK directly from a widget or feature Bloc.
- **Every repository interface has a fake** in `data/fakes/`, registered under
  the `demo` environment. Real impls register under `prod`.
- **No Firebase emulators.** Verification runs the `demo` flavor against fakes
  on real simulators. Never add emulator wiring to `bootstrap.dart`.

### Performance rules

- `const` everywhere it compiles.
- Lazy lists only (`ListView.builder`, `SliverList`).
- Heavy work (>50 ms) in isolates.
- `BlocSelector` / `buildWhen` for any state with >3 fields.
- Extract any `build` method >150 lines into a separate widget class.

## Flavors, fakes & no emulators

This project does **not** use Firebase emulators. Every backend dependency sits
behind a repository interface with two implementations, selected by environment:

- **`prod`** — real impls (Firebase, RevenueCat, network).
- **`demo`** — in-memory, **seeded** fakes in `data/fakes/`. Deterministic,
  offline, instant. This is what all verification runs against.

```bash
# Build/run the demo flavor (fakes) — used for all simulator verification:
flutter run --dart-define=APP_ENV=demo -d <device>
```

Wiring (via `injectable` environments):

```dart
@Environment('prod')
@LazySingleton(as: AuthRepository)
class FirebaseAuthRepository implements AuthRepository { … }

@Environment('demo')
@LazySingleton(as: AuthRepository)
class FakeAuthRepository implements AuthRepository { … }   // seeded users
```

Rules:
- Fakes are **seeded with representative data** covering each screen state
  (populated, empty, error, offline) and each entitlement state (free,
  subscribed, expired) so every flow is reachable on a simulator.
- Fakes can simulate failures (toggle/inject errors) so error/edge paths are
  testable without a backend.
- The real `prod` path is exercised only by the human via `HUMAN_SETUP.md`
  smoke items — Claude never touches the live backend project.

### Monetization (RevenueCat)

- Entitlements via `purchases_flutter` (RevenueCat), exposed through
  `core/payments/` and consumed only via `SubscriptionBloc`.
- **iOS simulator:** purchases are testable with a StoreKit configuration file
  (`ios/*.storekit`) — purchase, restore, subscribe, expire — no App Store
  Connect needed. Enable it in the Runner scheme.
- **Android & cross-platform:** `FakePurchaseRepository` (demo flavor) covers
  paywall, gating, restore, upgrade/downgrade, and expiry on the emulator.
- A **Restore Purchases** action is mandatory (App Store requirement).

## Responsive & render-safety

**Zero render (overflow) errors on any size is a hard requirement.** Every
content-bearing layout uses flex (`Expanded`/`Flexible`/`Wrap`/`FittedBox`) and
`LayoutBuilder` / `MediaQuery.sizeOf` — never fixed pixel sizes — and must
survive the **size matrix**:

| Platform | Smallest | Typical | Largest | Tablet |
|----------|----------|---------|---------|--------|
| iOS | iPhone SE | iPhone 16 Pro | iPhone 16 Pro Max | iPad |
| Android | small phone AVD | Pixel-class | — | tablet AVD |

…each at **textScale 1.0 and 2.0**.

Every top-level screen carries an **overflow-guard** widget test. A `RenderFlex`
overflow throws in debug, so pumping at each matrix size and asserting no
exception catches it deterministically:

```dart
const _matrix = <Size>[Size(320, 568), Size(393, 852), Size(430, 932), Size(834, 1194)];

for (final size in _matrix) {
  for (final scale in const [1.0, 2.0]) {
    testWidgets('HomeScreen no overflow @ $size x$scale', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: const _Harness(child: HomeScreen()),
      ));
      expect(tester.takeException(), isNull);
    });
  }
}
```

## Tech stack

> This stack is the project's **explicit override** of the State Management and
> Dependency Injection defaults in `docs/flutter-rules.md` (which otherwise
> defaults to built-in state management + manual constructor DI). All other
> rules in that document apply as written.

- **State:** `flutter_bloc` + sealed states via `freezed`.
- **Models:** `freezed` + `json_serializable`.
- **Routing:** `go_router` (declarative; deep links).
- **DI:** `get_it` + `injectable` (env-scoped: `demo` | `prod`).
- **Local DB:** `drift` (compile-time SQL).
- **Backend:** Firebase (Auth + Firestore + Analytics + Crashlytics).
- **Payments:** `purchases_flutter` (RevenueCat); fakes + `.storekit` for sims.
- **Logging:** `talker_flutter`.
- **App icon / splash:** `flutter_launcher_icons`, `flutter_native_splash`.
- **Lints:** `very_good_analysis`.
- **Testing:** `bloc_test`, `mocktail`, `integration_test` (run on simulators
  against the `demo` flavor — no emulators).

**Project-specific dependencies & overrides**

- **Tile detection (on-device, core):**
  - `camera` — live photo/video capture (CameraX/AVFoundation).
  - `image_picker` — gallery import.
  - `google_mlkit_text_recognition` (and/or `google_mlkit_object_detection`) —
    read tile numerals.
  - **OpenCV** via `opencv_dart` (or an FFI/platform-channel binding) — rack
    segmentation using the **2-row baseline** assumption + per-tile color
    classification in HSV.
  - All detection runs **off the UI isolate**; results carry per-tile confidence.
- **Solver:** pure-Dart in `domain/` (no Flutter imports). Computes the max-score
  legal arrangement (sets/runs + 5-pairs path); jokers/false-jokers are **wild**
  and take the value/identity of the tile they substitute. 101 mode → Açar/Açmaz
  @ ≥101; Okey mode → tiles-to-win. Memoized; runs off-isolate for large racks.
- **Monetization:** `purchases_flutter` (RevenueCat, entitlement `premium`) +
  `google_mobile_ads` (AdMob banner + rewarded). Ads/entitlement **only** via
  `SubscriptionBloc` / an `AdsService` interface — never an SDK call from a widget.
- **Consent/ATT:** `app_tracking_transparency` + AdMob UMP (`ConsentInformation`)
  gate personalized ads + analytics. Guard ATT on simulator (unavailable).
- **Auth:** `firebase_auth`, `google_sign_in`, `sign_in_with_apple`
  (Apple Sign-In mandatory because Google is offered). In-app **account deletion**
  with re-auth is required.
- **Misc:** `connectivity_plus` (offline banner), `permission_handler` (denied /
  permanently-denied → Open Settings), `flutter_secure_storage` (extra secrets).

> **Authoritative game rules** (tiles, colors, indicator→okey `(n+1) mod 13`, wild
> jokers, sets/runs, ≥101 / 5-pairs, rack 20–21 for 101 / 14–15 for Okey) live in
> `PRODUCT_SPEC.md` → *Domain rules*. The solver and all fakes must match them.

## Design reference

**Source:** `docs/design/101-okey-acar-mi/` (Claude Design bundle — read
`README.md`, `chats/chat1.md`, then `project/*.jsx` + `project/styles.css`).

**Type stack** (via `google_fonts`):
- **Instrument Serif** — editorial display moments ("Açar mı?", "Açar.", greetings).
- **Geist** — UI / body.
- **Geist Mono** — tile numerals, scores, eyebrows, stats.

**Design tokens → Flutter** (`core/theme/`; map the CSS custom props in `styles.css`):

| Token (CSS) | Meaning | Flutter |
|-------------|---------|---------|
| `--bg`, `--surface`, `--surface-2/3` | surfaces | `ColorScheme` surfaces |
| `--ink`, `--ink-2`, `--muted`, `--faint` | text inks | `onSurface` ramp / text styles |
| `--accent` (sage `oklch(0.55 0.13 165)`) | brand seed (tweakable, 4 swatches) | seed for `ColorScheme.fromSeed` + accent picker |
| `--tile-red/black/yellow/blue` | the 4 tile colors | `AppColors` tile palette (joker = glyph) |
| `--good/warn/bad` | feedback | semantic colors |
| `--r-sm/md/lg/xl` (8/14/22/28) | radii | shape tokens |

**Themes:** light / dark / system / **felt** (green-table) — all four ship as user
settings, plus a **tile-style** setting (classic / flat / minimal / bold) and the
**accent** picker. See `styles.css` `[data-theme=...]` blocks.

**Key components to port:** `Tile` (5 sizes × 4 styles, joker glyph), `Rack`
(2 rows — must flex to **14–21 tiles** without overflow), `Meld` (bracketed group +
score), pill, card, the verdict moment, the indicator picker (new — not in the
prototype), and ad/paywall surfaces (new — not in the prototype).

## Common commands

```bash
flutter pub get
dart run build_runner build
flutter gen-l10n
dart format .
flutter analyze
flutter test
# Run / test the demo flavor (fakes) on a simulator — no emulators:
flutter run --dart-define=APP_ENV=demo -d <device>
flutter test integration_test/ --dart-define=APP_ENV=demo -d <ios-sim>
flutter test integration_test/ --dart-define=APP_ENV=demo -d <android-emu>
xcrun simctl io "iPhone 16 Pro" screenshot /tmp/screenshot.png
```

## Codegen workflow

Generated files are committed. Workflow:

1. Edit `*.dart` annotated with `@freezed`, `@JsonSerializable`, etc.
2. Run `dart run build_runner build`.
3. Commit the generated files.

## Verification

After implementing a feature, `/step` (via the `flutter-qa` agent) gates on:
1. `flutter analyze` — clean.
2. `flutter test` — all unit/bloc/widget tests pass.
3. Demo flavor runs on an **iOS simulator** and an **Android emulator**; the new
   flow's happy + error/edge paths and **every dependent flow** are exercised
   via `integration_test`.
4. **Zero runtime errors/exceptions** in the Dart MCP error log during the runs.
5. **Zero render (overflow) errors** across the responsive size matrix (see
   `PRODUCT_SPEC.md` → Non-functional) at textScale 1.0 and 2.0.
6. Successful flows captured as permanent integration tests; screenshots saved.

## Platform support

iOS 15+ and Android 8+ (API 26), **phone only**, **portrait-locked**. Tablets run
the scaled phone layout (no dedicated tablet UI). No web/desktop. Min-OS floor is
set by Google ML Kit, CameraX, and AdMob.

## Flutter & Dart rules

`docs/flutter-rules.md` is the **primary, authoritative rule set** — it wins
over agents, commands, and skills wherever they conflict. It covers SOLID
principles, code quality, Dart best practices, testing, theming, accessibility,
layout, and code generation conventions. The only sanctioned deviations are the
**State Management** and **Dependency Injection** choices in the Tech stack
section above, which the rules doc's own "unless explicitly requested" clause
permits.

## Working with Claude Code in this repo

- **Commands:** `/init-app`, `/step`, `/plan-status`, `/plan-extend`,
  `/feature`, `/fix`, `/refactor`, `/review`, `/test`, `/qa`, `/ship`,
  `/codegen`, `/clean`, `/deps`
- **Agents:** flutter-architect, developer, debugger, refactorer,
  releaser, reviewer, tester, qa, ui-designer
- **MCP required:** `dart` (dart mcp-server). Firebase plugin optional.
