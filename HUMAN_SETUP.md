# 101 Okey Açar Mı — human setup checklist

These are the **irreducibly human** tasks — external accounts, store/dashboard
config, signing, secrets, and legal — that Claude cannot do for you. Everything
else (all code, and all simulator verification against fakes) is automated.

The app **builds and is fully verified on simulators against fakes** without any
backend, so most of this is needed only for the real (`prod`) build and
real-device smoke tests. Front-load the slow ones (Apple enrollment, store IAP
products, RevenueCat) — they gate later release work.

Items that don't apply should be struck through: `- [x] ~~item~~ _(not needed)_`

## Toolchain (one-time per machine)

- [x] Flutter SDK installed (`flutter doctor` green). _(verified: Flutter 3.41.6, Xcode 16.1, Android SDK 35, devices available)_
- [x] `claude` CLI installed and `claude login` done. _(in use)_
- [ ] Dart MCP registered: `claude mcp add dart -- dart mcp-server`  ← **not yet registered; needed for `/step` runtime verification**
- [ ] Claude Code restarted; `claude mcp list` shows dart Connected.

## Firebase (if using Firebase)

- [ ] Firebase project created. Project ID: ___________________
- [ ] `firebase login` done.
- [ ] `flutterfire configure --project=<id>` run; `firebase_options.dart` generated.
- [ ] Sign-in providers enabled: **Email/Password, Google, and Apple** (all three
      — Apple Sign-In is mandatory because Google is offered).
- [ ] Google sign-in: OAuth client + (Android) **SHA-1/SHA-256** added; (iOS)
      reversed-client-ID URL scheme added to `Info.plist`.
- [ ] Apple sign-in: **"Sign in with Apple"** capability added to the Runner target
      in Xcode; Service ID configured in the Apple Developer portal.
- [ ] Firestore security rules scoped to the owner
      (`allow read, write: if request.auth.uid == resource.data.ownerId`); published.

> No emulator setup — this bundle verifies against fakes (`demo` flavor). The
> real Firebase project is only needed for `prod` builds and your own smoke
> tests.

## Monetization — RevenueCat + store products (if paid)

This app sells a single **"remove ads"** entitlement named **`premium`**, as a
**monthly** + **annual** auto-renewing subscription with a **7-day free trial**.
Suggested product IDs (keep consistent across stores + RevenueCat + `.storekit`):
`com.okeyacarmi.premium.monthly`, `com.okeyacarmi.premium.annual`.

- [ ] RevenueCat account created; project + **public SDK API keys** (iOS + Android)
      obtained. Key(s): ___________________
- [ ] API keys provided to the app via `--dart-define=REVENUECAT_IOS_KEY=… ` /
      `REVENUECAT_ANDROID_KEY=…` (CI secret — **not committed**).
- [ ] **App Store Connect:** the two subscription products created under one
      subscription group; **7-day intro free trial** set; pricing, localizations,
      and Paid-Apps agreement/tax/banking completed.
- [ ] **Google Play Console:** matching monthly + annual subscriptions created;
      **7-day free trial** offer; pricing set.
- [ ] RevenueCat **entitlement `premium`** + an **offering** (monthly + annual)
      configured; both store products linked.
- [ ] `ios/Configuration.storekit` product IDs **match** the store product IDs
      above (for iOS-simulator purchase/restore/expire testing).
- [ ] Sandbox/license test accounts added; real-device purchase + **restore**
      verified (restore is App Store-required).

## Apple Developer (if shipping to iOS)

- [ ] Apple Developer Program enrolled.
- [ ] App ID created with bundle ID.
- [ ] Xcode auto-signing configured (Runner → Signing & Capabilities → select team).

## Android signing (if shipping to Play Store)

- [ ] Release keystore generated.
- [ ] `android/key.properties` created.
- [ ] SHA fingerprints added to Firebase project.

## Autobuild runner (optional — unattended builds)

Only needed if you want Claude to implement the whole plan on its own with
`runner/autobuild.py` (instead of running `/step` yourself). See `docs/autobuild.md`.

- [x] Python 3.10+ available (`python3 --version`). _(Python 3.13.1)_
- [x] **Virtual environment created + SDK installed** (`runner/.venv`,
      `claude-agent-sdk` 0.2.88). Activate with:
  ```bash
  source runner/.venv/bin/activate        # Windows: runner\.venv\Scripts\activate
  ```
- [x] Claude Code CLI installed + authenticated (`claude login`) — the SDK spawns it.
- [ ] An iOS simulator and an Android emulator can boot (the runner drives both).
- [ ] (Only if a step configures real Firebase) service-account key exported:
      `export GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json`
- [x] Smoke-tested the wiring (`--dry-run` launched, loaded the plan, began Step 0).

## Ads — Google AdMob (required)

- [ ] AdMob account created; an **app** registered for **both** iOS and Android.
      iOS App ID: ___________________  Android App ID: ___________________
- [ ] **AdMob App IDs** added to native config: iOS `Info.plist`
      (`GADApplicationIdentifier`) and Android `AndroidManifest.xml`
      (`com.google.android.gms.ads.APPLICATION_ID`).
- [ ] Ad units created and provided via `--dart-define` (not committed):
      **banner** (iOS+Android) and **rewarded** (iOS+Android). Unit IDs: ______
- [ ] UMP (consent) message configured in AdMob → Privacy & messaging (EEA/UK).
- [ ] During development, use Google's **test ad unit IDs** + register test devices
      so you never click live ads.

> The `demo` flavor uses `FakeAdsRepository` (labeled placeholder banners; rewarded
> grants instantly), so no AdMob account is needed for simulator verification — only
> for `prod` builds and real-device ad checks.

## On-device detection (ML Kit + OpenCV)

- [ ] iOS: run `pod install` in `ios/` after adding the ML Kit / OpenCV pods; bump
      the iOS deployment target to **15.0** if a pod requires it.
- [ ] Android: confirm `minSdkVersion 26` and (if needed) NDK/ABI filters for the
      OpenCV binding build.
- [ ] No API key needed — Google ML Kit on-device models ship with the app.

## Permission usage strings (store-required)

- [ ] iOS `Info.plist`: `NSCameraUsageDescription`,
      `NSPhotoLibraryUsageDescription`, and `NSUserTrackingUsageDescription` (ATT)
      written in Turkish + English (localized `InfoPlist.strings`).
- [ ] Android: camera + read-media permissions present in `AndroidManifest.xml`;
      no notification permission (none used).

## Fonts (licensing)

- [ ] Confirm licensing for **Geist**, **Geist Mono** (OFL), and **Instrument
      Serif** (OFL) for app embedding — all loaded via `google_fonts` at runtime by
      default; bundle them if you want offline-guaranteed rendering.

## Legal (store-required)

- [ ] **Privacy Policy** URL published and added to Settings + store listings:
      ___________________  (must disclose camera use + AdMob/Analytics data).
- [ ] **Terms of Service** URL published and added to Settings: _______________
- [ ] App Store **Privacy "Nutrition Label"** + Android **Data Safety** form
      completed (camera, identifiers for ads, crash data).

## Store presence (final art & metadata — at release)

- [ ] Final app icon + splash art (the generated 1-0-1 wordmark is a placeholder).
- [ ] Store listing: name "101 Okey Açar Mı", description (TR + EN), keywords,
      screenshots for the required device sizes.

---

When all items are `[x]`, you're ready to start building — either step by step:

```
/step
```

…or hand the whole plan to the autonomous runner (each step gets a fresh context):

```
caffeinate -i runner/.venv/bin/python runner/autobuild.py
```
