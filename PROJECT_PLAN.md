# 101 Okey Açar Mı — project plan

Steps are **derived from `PRODUCT_SPEC.md`** — every flow and screen in the spec
maps to a step (or part of one). Each `## Step N` is one implementation session,
worked through in order via `/step`. Mark `[x]` when complete.

`/step` does not mark a step done until it has been **verified on the iOS and
Android simulators** (demo flavor, fakes — no emulators): the new flow plus every
dependent flow are exercised, with zero runtime errors/exceptions and zero render
overflow across the responsive size matrix. Write Acceptance criteria as
**verifiable flow/state outcomes taken from the spec**.

Format per step:

```
## Step N — <Title>
- [ ] <!-- checkbox, flipped to [x] when done -->
- id: <kebab-slug>
- depends_on: <comma-separated step ids, or none>
- spec_refs: <flow/screen ids from PRODUCT_SPEC.md this step implements>

### Description
...what to build...

### Acceptance
- bullet list of verifiable criteria (happy path + error/edge paths + states
  from the spec; responsive on the size matrix; entitlement-gated if paid)

### Touchpoints
- expected files/dirs
```

---

## Step 0 — Bootstrap the project
- [x]
- id: bootstrap
- depends_on: none

### Description

Set up the Flutter project scaffolding. `/init-app` already ran
`flutter create`, so the project structure exists.

- Replace the generated `pubspec.yaml` with the full dependency set
  from CLAUDE.md → Tech stack (flutter_bloc, get_it/injectable, freezed,
  json_serializable, go_router, drift, talker_flutter, very_good_analysis,
  bloc_test, mocktail, integration_test) **plus** the project-specific deps
  (camera, image_picker, google_mlkit_text_recognition, opencv_dart,
  purchases_flutter, google_mobile_ads, app_tracking_transparency,
  firebase_core/auth, cloud_firestore, firebase_analytics, firebase_crashlytics,
  google_sign_in, sign_in_with_apple, connectivity_plus, permission_handler,
  flutter_secure_storage, google_fonts, flutter_launcher_icons,
  flutter_native_splash).
- Create the directory skeleton under `lib/`: `core/` and `features/_template/`.
- Add `analysis_options.yaml` extending `very_good_analysis`.
- Stub `bootstrap.dart`, `app.dart`, theme/router/logging/clock, env (demo|prod).
- Set up DI scaffolding (`@Environment('demo'|'prod')`) and run `build_runner`.
- Set up `l10n.yaml` and stub ARB files (`app_tr.arb` default, `app_en.arb`).

### Acceptance
- `flutter analyze` exits 0; `flutter test` exits 0; `build_runner build` succeeds.
- App boots to a blank Material screen on an **iOS simulator** and an **Android
  emulator** in the demo flavor (`--dart-define=APP_ENV=demo`) with fakes wired.
- No runtime errors/exceptions in the Dart MCP error log on boot.

### Touchpoints
- `pubspec.yaml`, `analysis_options.yaml`, `l10n.yaml`,
  `lib/main.dart`, `lib/app.dart`, `lib/bootstrap.dart`,
  `lib/core/**`, `lib/features/_template/**`, `ios/Configuration.storekit`.

---

## Step 1 — Design system, theming & the Tile/Rack kit
- [x]
- id: design-system
- depends_on: bootstrap
- spec_refs: NFR (responsive/a11y), Theming, Design reference

### Description
Port the design tokens and core visual primitives so every later screen is built
from them.
- `core/theme/`: `AppColors` (4 tile colors + semantic), `AppTypography`
  (Instrument Serif / Geist / Geist Mono via google_fonts), `AppTheme` for
  **light / dark / system / felt**; seed via `ColorScheme.fromSeed` + accent picker.
- `core/widgets/`: `Tile` (5 sizes × 4 styles: classic/flat/minimal/bold + joker
  glyph), **`Rack`** (2 rows, flexes to **14–21 tiles** with no overflow),
  `Meld` (bracketed group + score), pill, card, eyebrow, primary/secondary buttons.
- Wire theme + tileStyle + accent into a `SettingsCubit`-backed `InheritedWidget`
  so the panel choices are live.

### Acceptance
- Light/dark/system/felt all render correctly; tile-style + accent switch live.
- **`Rack` renders 14, 15, 20, and 21 tiles with zero overflow** on the full size
  matrix at textScale 1.0 and 2.0 (overflow-guard widget tests for each count/size).
- `Tile` renders all 4 styles + joker; Semantics labels present.

### Touchpoints
- `lib/core/theme/**`, `lib/core/widgets/**`, `test/core/widgets/**` (overflow guards).

---

## Step 2 — App shell, routing, navigation & localization
- [ ]
- id: app-shell
- depends_on: design-system
- spec_refs: flow-onboard, screen-splash, screen-home (shell), screen-tutorial, Localization

### Description
- `go_router` with routes for splash, login, home, camera, analyzing, review,
  result, history, settings, paywall, tutorial; Android hardware back → pop.
- Bottom nav (Home / History / Settings); guest-first entry.
- **Splash** (1-0-1 letter tiles, "Açar mı?"), **Tutorial** (3 steps + worked
  example), placeholder Home/History/Settings.
- ARB strings for everything built so far (TR default + EN); language switch live.

### Acceptance
- Splash → guest → Home; Devam et → Login route; bottom nav switches tabs.
- Android back pops correctly; deep route restoration on cold start (no crash).
- TR/EN switch re-renders all visible strings; no hardcoded user-facing strings.
- Zero overflow across the matrix on splash/tutorial/shell at 1.0 & 2.0.

### Touchpoints
- `lib/core/router/**`, `lib/app.dart`, `lib/features/onboarding/**`,
  `lib/features/tutorial/**`, `lib/l10n/**`.

---

## Step 3 — Auth & account lifecycle (guest + email/Google/Apple)
- [ ]
- id: auth
- depends_on: app-shell
- spec_refs: flow-auth-signin, flow-account-delete, screen-login, screen-settings (account)

### Description
- `AuthRepository` interface + **FakeAuthRepository** (demo, seeded users:
  signed-out/guest, signed-in, unverified) and FirebaseAuthRepository (prod).
- Login/Sign-up screen: email+password, Google, Apple, guest; show/hide; forgot
  password; verification on sign-up; sign-out.
- **Account deletion** with re-authentication; merge local guest history on sign-in
  (stubbed until Step 7).
- `AuthBloc`; route guards; token-expiry → silent refresh → guest fallback banner.

### Acceptance
- Sign in/up (email/Google/Apple/guest) happy paths; field errors; network error;
  provider-cancelled; forgot-password — all via fakes on both simulators.
- Account deletion requires re-auth, then returns to guest with confirmation.
- Apple Sign-In button present on iOS. No infinite spinners.
- Zero overflow on login at 1.0 & 2.0; keyboard inset handled.

### Touchpoints
- `lib/features/auth/**` (domain/data/fakes/presentation), `test/features/auth/**`.

---

## Step 4 — Camera capture (photo / video / gallery)
- [ ]
- id: capture
- depends_on: app-shell
- spec_refs: flow-scan (capture portion), screen-camera, Permissions matrix

### Description
- Camera screen: viewfinder + reticle, mode toggle (photo/video/gallery), shutter,
  flash, flip; portrait-locked; release camera on background.
- Permission priming **in-context**; denied / permanently-denied → rationale +
  **Open Settings**; **camera-denied falls back to gallery import**.
- `CaptureService` interface + **FakeCaptureService** (demo: returns seeded rack
  images/fixtures so the flow is reachable on a simulator without a real camera).
- Outputs a capture payload (still, or sampled video frames) for detection.

### Acceptance
- Photo, video, and gallery modes each produce a capture (via fake on simulators).
- Camera-denied → gallery still works; permanently-denied → Open Settings path.
- Backgrounding mid-capture releases the camera and resumes without crash.
- Zero runtime errors in the Dart MCP log; safe-area insets correct.

### Touchpoints
- `lib/features/capture/**`, `test/features/capture/**`.

---

## Step 5 — On-device tile detection (OpenCV + ML Kit)
- [ ]
- id: detection
- depends_on: capture, design-system
- spec_refs: flow-scan (detect portion), screen-analyzing, Domain rules

### Description
- `TileDetector` interface; **FakeTileDetector** (demo: deterministic seeded
  detections incl. low-confidence + a no-tiles + a wrong-count case) and the real
  OpenCV+ML Kit impl (prod). Runs **off the UI isolate**.
- Real pipeline: OpenCV segments the rack using the **2-row baseline** assumption,
  crops tiles, ML Kit reads numerals, HSV classifies color into the 4 buckets;
  unnumbered tiles flagged as candidate false jokers; per-tile confidence.
- **Analyzing** screen: staged progress + per-tile reveal; reduce-motion variant;
  failure (no tiles / error) → retry; cancellable.

### Acceptance
- Demo detection yields a reviewable 2-row rack (14–21 tiles) with confidences.
- No-tiles and detection-error states show retry, not a dead-end.
- Video mode aggregates multiple frames per position (fake demonstrates).
- Detection runs without jank (off-isolate); reduce-motion respected.

### Touchpoints
- `lib/features/detection/**` (incl. `data/` isolate + native binding),
  `test/features/detection/**`.

---

## Step 6 — Review & correct + indicator (gösterge) picker
- [ ]
- id: review-indicator
- depends_on: detection
- spec_refs: flow-scan (review portion), screen-review, Domain rules (joker)

### Description
- Review screen: detected tiles in the **2-row rack** (14–21), tap a tile to fix
  **number/color**; low-confidence dots; **add / remove** a tile to match the
  expected count for the mode; wrong-count warning.
- **Indicator picker** (color + number) — derives the **okey** = color, `(n+1) mod
  13`; marks the 2 false jokers as that okey; blocks **Hesapla** until the
  indicator is set.
- `ReviewBloc` holding the editable rack + indicator.

### Acceptance
- Tap-to-edit changes number/color and clears the low-confidence flag.
- Add/remove tile enforces 14–15 (Okey) / 20–21 (101); wrong-count warns.
- Indicator picker computes the correct okey (incl. 13→1 wrap); false jokers shown
  as okey; solving blocked until indicator chosen.
- **Rack of 21 tiles edits without overflow** on SE @2.0.

### Touchpoints
- `lib/features/review/**`, `test/features/review/**`.

---

## Step 7 — Solver (101 + Okey) — pure Dart domain
- [ ]
- id: solver
- depends_on: review-indicator
- spec_refs: flow-scan (solve), f-solve-101, f-solve-okey, Domain rules

### Description
- Pure-Dart solver in `domain/` (no Flutter imports): enumerate the max-score legal
  arrangement of sets/runs; handle **wild okey/false-jokers** taking substituted
  value/identity; the **5-pairs** open path; runs/sets validity (1 low only).
- **101 mode:** total ≥101 (or 5-pair) → opens; else points short.
- **Okey mode:** best arrangement + **tiles-to-win** (sets/runs + final pair /
  7-pairs). Memoized; runs off the UI isolate for 20–21-tile racks.
- Produce a structured result (melds, leftover, total, opens|distanceToWin,
  human-readable reasoning steps).

### Acceptance
- Exhaustive unit tests: known opening hands (≥101), 5-pair opens, non-opening
  hands (correct points-short), joker substitution at correct value, 13→1 wrap,
  Okey-mode tiles-to-win, 20–21 tile racks within time budget.
- Solver is deterministic and has **no Flutter/data/presentation imports**.

### Touchpoints
- `lib/features/solver/domain/**`, `test/features/solver/**` (heavy unit coverage).

---

## Step 8 — Result presentation (verdict, rack, melds, layouts)
- [ ]
- id: result
- depends_on: solver
- spec_refs: flow-scan (result), screen-result, f-result

### Description
- Result screen: big serif **"Açar." / "Açmaz."** (101) or arrangement +
  **tiles-to-win** (Okey); score /101; visual **rack with meld brackets + legend**;
  **rack** and **list** layouts; Again / Done.
- States: opens / closes / okey-mode / loading / solver-error → retry.
- Detailed "why this" reasoning view built but **gated** (wired in Step 11).

### Acceptance
- Açar and Açmaz render with correct score + meld legend; Okey-mode shows distance.
- Rack of up to 21 tiles wraps to 2 rows with bracketed melds, zero overflow @2.0.
- Solver-error state retries; verdict scales via FittedBox.

### Touchpoints
- `lib/features/result/**`, `test/features/result/**`.

---

## Step 9 — History + persistence (drift) + sync
- [ ]
- id: history
- depends_on: result, auth
- spec_refs: flow-history, flow-history-sync, screen-history, Data model

### Description
- drift DB for Scans + Preferences; `ScanRepository` interface +
  **FakeScanRepository** (demo: seeded history incl. opened/closed, empty case)
  and a drift-backed local impl; Firestore sync impl (prod, owner-scoped) used when
  signed in; merge local guest scans on sign-in (last-write-wins).
- History screen: filter chips (all/opened/closed), **infinite scroll (page 20)**,
  tap → re-open Result; Home "last scan" + stats fed from the repo.
- Empty vs no-results states; offline → local only with banner.

### Acceptance
- Scans persist across restarts (drift); filters + pagination work; empty &
  no-results states distinct; tapping a scan re-opens its Result.
- Sign-in merges guest history; signed-in writes go to Firestore (fake/owner-scoped
  in demo); offline shows local with banner.

### Touchpoints
- `lib/features/history/**`, `lib/core/db/**`, `test/features/history/**`.

---

## Step 10 — Settings, preferences & connectivity
- [ ]
- id: settings
- depends_on: history
- spec_refs: flow-settings, flow-consent (storage), screen-settings, Settings/Connectivity

### Description
- Settings screen: theme, tile style, accent, language, default game mode; account
  section (sign in/out, **delete account**), **restore purchases**, manage
  subscription (wired in Step 11), legal links, version.
- Persist preferences (drift); guest upsell vs signed-in profile card.
- Global **offline banner** via `connectivity_plus`; refresh on resume.

### Acceptance
- Every preference persists and is applied live (theme/tile/accent/lang/mode).
- Guest sees "Üye ol"; signed-in shows email + delete; restore button present.
- Offline banner appears/clears with connectivity; rows survive textScale 2.0.

### Touchpoints
- `lib/features/settings/**`, `lib/core/network/**`, `test/features/settings/**`.

---

## Step 11 — Monetization: RevenueCat subscription + AdMob ads + consent
- [ ]
- id: monetization
- depends_on: settings, result
- spec_refs: flow-purchase, flow-detail, flow-consent, screen-paywall, Monetization spec

### Description
- `core/payments/`: RevenueCat wrapper + entitlement interface, consumed only via
  **`SubscriptionBloc`**. Fakes: **FakePurchaseRepository** (demo: free / premium /
  expired) + `.storekit` config (iOS sim). Paywall (monthly/annual + 7-day trial,
  **Restore**, manage, terms).
- `core/ads/`: `AdsService` interface + **FakeAdsRepository** (demo: labeled
  placeholder banners; rewarded grants instantly). AdMob banner on Result + History
  (free only); **rewarded** unlocks the detailed reasoning per result.
- **Consent/ATT:** UMP + iOS ATT gating personalized ads + analytics; guard sim.
- Gate the detailed "why this" view: premium → always; free → rewarded ad.

### Acceptance
- Purchase / cancel / restore / expiry all work (StoreKit on iOS sim,
  FakePurchaseRepository on Android) → entitlement drives every gate.
- Banner shows for free, hidden for premium; rewarded unlocks detail (and does not
  consume on failure/early-dismiss).
- ATT/UMP prompts appear at the right moment and are guarded on simulator.
- Every gate checks `SubscriptionBloc` — no direct SDK reads from widgets.

### Touchpoints
- `lib/core/payments/**`, `lib/core/ads/**`, `lib/features/paywall/**`,
  `lib/features/consent/**`, `ios/Configuration.storekit`, `test/**`.

---

## Step 12 — Responsive & accessibility pass (size matrix, textScale 2.0)
- [ ]
- id: responsive-a11y
- depends_on: monetization
- spec_refs: Non-functional requirements

### Description
Sweep **every** screen across the size matrix (iPhone SE / 16 Pro / 16 Pro Max,
small/Pixel Android, iPad scaled) at textScale **1.0 and 2.0**. Fix all overflow;
add overflow-guard widget tests per top-level screen. Audit Semantics on
interactive + icon-only controls (shutter, tile-edit, indicator, ad/paywall CTAs);
verify ≥48dp targets, WCAG AA contrast (all 4 themes), reduce-motion paths.

### Acceptance
- **Zero render/overflow errors** on any screen across the full matrix at 1.0 & 2.0
  — including the **21-tile rack** on Review and Result.
- Semantics present on all interactive/icon elements; ≥48dp targets; AA contrast in
  light/dark/felt; reduce-motion disables scan-line/pulse.

### Touchpoints
- `test/**/overflow/**`, targeted layout fixes across `lib/features/**`.

---

## Step 13 — Release prep
- [ ]
- id: release-prep
- depends_on: responsive-a11y
- spec_refs: App identity, HUMAN_SETUP.md

### Description
- App icon + splash from the **1-0-1 tile wordmark** via `flutter_launcher_icons` /
  `flutter_native_splash`; app display name "101 Okey Açar Mı"; bundle
  `com.okeyacarmi.okey_acar_mi`; version 1.0.0.
- Confirm `--dart-define` wiring for RevenueCat key + AdMob IDs; prod vs demo flavor
  builds; Crashlytics/Analytics behind consent.
- Final `flutter analyze` + full test suite + integration_test pass on both
  simulators (demo flavor). Verify all `HUMAN_SETUP.md` gating items.

### Acceptance
- Release (prod) and demo builds compile for iOS + Android; icon/splash correct.
- All unit/bloc/widget/integration tests green; analyze clean; zero overflow.
- No secrets committed; entitlement + ads behave correctly in a prod-config smoke.

### Touchpoints
- `pubspec.yaml` (icons/splash), `ios/**`, `android/**`, CI/build config.
