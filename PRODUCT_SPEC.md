# 101 Okey Açar Mı — product spec

> Single source of truth for **what** the app is and **every flow it must
> support**. Produced by `/init-app` from the requirements interview
> (`docs/requirements-checklist.md`). `PROJECT_PLAN.md` steps are derived from
> this document — if a flow isn't here, it won't get built or tested.

## Summary

**101 Okey Açar Mı** ("will it open?") is a camera-based **tile solver** for the
Turkish tile games **101 Okey** and **Okey** (plain). The user points the phone
at their rack (istaka), the app **detects every tile by number + color** on-device
(OpenCV segmentation + Google ML Kit recognition), lets the user **review/correct**
the reading and **pick the indicator tile (gösterge)**, then runs a **solver** that
finds the best legal arrangement of sets/runs (and the 5-pairs path). In **101
mode** it delivers the headline verdict — **"Açar." / "Açmaz."** — with the score
out of 101; in **Okey mode** it shows the best arrangement and **how many tiles
from a winning hand**. It is a utility, not a playable game. Revenue comes from
**AdMob** banners + rewarded ads, with a **RevenueCat "remove ads" subscription**.
Stage: **greenfield**. UI follows the Claude Design bundle in
`docs/design/101-okey-acar-mi/` (Instrument Serif editorial moments, Geist UI,
Geist Mono numerics; strict 4-color tile palette + joker).

## Platforms & constraints
- **Platforms:** iOS, Android.
- **Form factors:** phone only (tablets run the scaled phone layout) ·
  **Orientations:** portrait-locked.
- **Min OS:** iOS 15 / Android 8 (API 26) — floor set by Google ML Kit, CameraX,
  and AdMob.
- **Tech stack:** see `CLAUDE.md` (flutter_bloc, get_it/injectable, drift,
  go_router, Firebase, RevenueCat, AdMob, google_mlkit_*, OpenCV).

## Domain rules (the games)

These rules govern detection, the solver, and all fixtures. They are authoritative.

- **Tiles:** numbers **1–13** in **4 colors** — red, black, yellow, blue. Two of
  each number/color (104) + **2 false jokers** (sahte okey, unnumbered) = 106.
- **Indicator (gösterge):** chosen at the start of a game; the user selects it in
  the app (number + color). It defines the joker.
- **Okey (real joker):** the tile of the **indicator's color**, number **(n + 1)
  mod 13** (13 → 1). Example: indicator **Blue 3 → okey = Blue 4**. The actual
  okey tiles are **fully wild** (may substitute for any tile).
- **False jokers (2 unnumbered tiles):** represent the okey tile (e.g. Blue 4),
  so they are played as the okey and are **also effectively wild**.
- **Set (per):** 3–4 tiles of the **same number, different colors**.
- **Run (seri):** 3+ **consecutive** tiles of the **same color**. **1 is low
  only** — `12-13-1` is invalid; `13→1` does not wrap in a run.
- **Tile value:** each tile scores its **face value**; a 3-tile run/set = 3× the
  middle tile. A wild substituting in a meld **takes the value/identity of the
  tile it replaces** for scoring.
- **101 mode — "open" threshold:** lay down sets/runs totaling **≥ 101** points.
  Alternative open: **5 pairs (çift)**, where point value does not matter.
  Verdict: **Açar** (≥101 or 5-pair) / **Açmaz** (otherwise, with points short).
- **Okey (plain) mode:** no 101 threshold; goal is a complete winning hand (all
  tiles in sets/runs + a final pair, or 7 pairs). Output: best arrangement +
  **tiles-to-win** distance. No Açar/Açmaz verdict.
- **Rack capacity (hard requirement for detection + UI):**
  - **101 Okey: 20 or 21 tiles** (21 when it is the user's turn / just drew).
  - **Okey (plain): 14 or 15 tiles.**
  - Tiles sit on the rack in **2 parallel rows** (≈10–11 per row in 101 mode).
    Detection relies on the two-baseline assumption; the rack UI must render any
    count from 14–21 across 2 rows with **zero overflow** at every size.

## Feature inventory
One row per feature. `Gate` = free or a paid entitlement. `Phase` = v1 or later.

| ID | Feature | Description | Gate | Phase | Depends on |
|----|---------|-------------|------|-------|-----------|
| f-capture | Capture rack | Live camera **photo**, **video** (multi-frame), and **gallery import** of the rack. | free | v1 | — |
| f-detect | Tile detection | On-device OpenCV segmentation + ML Kit number/color recognition; 2-row baseline; per-tile confidence. | free | v1 | f-capture |
| f-review | Review & correct | Show detected tiles in a 2-row rack; tap to fix number/color; low-confidence flags; add/remove tile to match count. | free | v1 | f-detect |
| f-indicator | Indicator (gösterge) picker | Select indicator number+color; app derives the okey; mark false jokers. | free | v1 | f-review |
| f-solve-101 | 101 solver | Max-score legal arrangement; ≥101 / 5-pair open detection; Açar/Açmaz verdict + score. | free | v1 | f-review, f-indicator |
| f-solve-okey | Okey solver | Best arrangement + tiles-to-win distance (sets/runs/pairs, 7-pairs path). | free | v1 | f-review, f-indicator |
| f-result | Result presentation | Verdict + visual rack with meld brackets + legend. Layouts: rack / list. | free | v1 | f-solve-101, f-solve-okey |
| f-result-detail | Detailed "why this" | Step-by-step reasoning for the arrangement. | premium **or** rewarded-ad unlock per result | v1 | f-result |
| f-mode | Game mode chooser | Switch 101 / Okey on Home; changes solver + result. | free | v1 | — |
| f-history | History | Past scans with verdict/score; filter all/opened/closed; infinite scroll. | free | v1 | f-result |
| f-history-sync | History sync | Guest history local (drift); on sign-in, sync to Firestore (owner-scoped). | free | v1 | f-history, f-auth |
| f-auth | Auth & account | Guest by default; optional email/Google/Apple sign-in; verification; reset; sign-out; **account deletion**. | free | v1 | — |
| f-settings | Settings | Theme, tile style, accent, language, default mode, account, restore, manage sub, legal, version. | free | v1 | — |
| f-tutorial | Tutorial | 3-step how-it-works + worked example. | free | v1 | — |
| f-ads | Ads | AdMob banner on Result/History; rewarded ad to unlock f-result-detail. | free (hidden for premium) | v1 | f-consent |
| f-premium | Remove-ads subscription | RevenueCat monthly+annual, 7-day trial, paywall, restore, manage. | n/a (purchase) | v1 | f-ads |
| f-consent | Consent & ATT | iOS ATT prompt + UMP/GDPR consent gating tracking/personalized ads. | free | v1 | — |

## User flows
For **every** flow: the happy path **and** the error/edge paths. Each flow names
the screens it touches and becomes one or more integration tests.

### flow-onboard: First run & entry
- **Trigger:** App cold start, no prior session.
- **Happy path:** 1. Splash ("Açar mı? / Bir bakışta öğren."). 2. User taps
  **Devam et** → Login, or **Misafir olarak gir** → Home as guest. 3. On first
  Home, an inviting empty state + optional tutorial entry.
- **Error / edge paths:**
  - Returning signed-in user → skip splash CTA, restore session straight to Home.
  - Token expired → silent refresh; on failure, fall back to guest with a banner
    "Oturum süresi doldu, tekrar giriş yap."
- **Screens involved:** screen-splash, screen-login, screen-home.
- **Entitlement:** free.

### flow-auth-signin: Sign in / sign up
- **Trigger:** User taps Devam et / "Üye ol" / a sync-gated action.
- **Happy path:** 1. Choose email+password (sign in or sign up), Google, or Apple.
  2. On sign-up, send **email verification**; allow use meanwhile. 3. Land on Home;
  local guest history **merges/uploads** to the account.
- **Error / edge paths:**
  - Invalid credentials / wrong password → inline field error.
  - Email already in use → offer sign-in instead.
  - Network error → retry with backoff; friendly error, no infinite spinner.
  - Google/Apple cancelled → return to Login, no error toast.
  - **Apple Sign-In is mandatory** (Google offered) — present on iOS.
  - Forgot password → email reset flow with confirmation + error states.
- **Screens involved:** screen-login, screen-home.
- **Entitlement:** free.

### flow-account-delete: Account & data deletion
- **Trigger:** Settings → Account → Delete account.
- **Happy path:** 1. Confirm destructive intent. 2. **Re-authenticate** (recent
  login required). 3. Delete Firestore data + auth user; sign out to guest; show
  confirmation.
- **Error / edge paths:**
  - Requires-recent-login → route to re-auth, then resume deletion.
  - Network error mid-delete → safe retry; never leave a half-deleted account
    silently.
- **Screens involved:** screen-settings, screen-login (re-auth).
- **Entitlement:** free. (App Store requirement.)

### flow-scan: Capture → detect → review → solve → result (core loop)
- **Trigger:** Home → "Istakanı çek" (scan CTA).
- **Happy path:** 1. **Camera** opens (mode = photo/video/gallery). 2. User frames
  the 2-row rack and captures (or imports). 3. **Analyzing** runs on-device
  detection (off the UI isolate); per-tile reveal. 4. **Review** shows the 2-row
  rack (14–21 tiles) with detected number+color; low-confidence flagged. 5. User
  fixes any wrong tiles and **picks the indicator (gösterge)**. 6. Tap **Hesapla**
  → solver runs. 7. **Result**: 101 mode → **Açar/Açmaz** + score/101 + best
  arrangement; Okey mode → best arrangement + tiles-to-win. 8. Scan saved to
  History.
- **Error / edge paths:**
  - **Camera permission denied** → rationale + Open Settings; offer **gallery
    import** as fallback (works without camera).
  - **Photo-library permission denied** (gallery mode) → rationale + Open Settings.
  - **No tiles detected** → "Taş bulunamadı" empty/error state with tips
    (lighting, frame the rack) + Retry.
  - **Wrong tile count** (not 14–15 for Okey / 20–21 for 101) → warn, let the user
    add/remove tiles in Review before solving.
  - **Low light / blur / glare** → low overall confidence banner; suggest retake;
    proceed allowed after manual review.
  - **Video mode:** sample frames, aggregate per-position readings, pick highest
    confidence; if frames disagree badly → flag those positions low-confidence.
  - **No legal opening (101)** → verdict **Açmaz**, show points short + best
    possible partial arrangement.
  - **Offline:** entire scan/detect/solve works; only History sync + ads are
    deferred (offline banner).
  - **App backgrounded mid-capture** → release camera, restore on resume without
    crash; in-progress detection cancellable.
- **Screens involved:** screen-camera, screen-analyzing, screen-review,
  screen-result.
- **Entitlement:** free (detailed reasoning on Result is gated — see flow-detail).

### flow-detail: Unlock detailed reasoning
- **Trigger:** Result → "Neden böyle?" (detailed view).
- **Happy path (premium):** shown immediately.
- **Happy path (free):** 1. Prompt to **watch a rewarded ad** or **go premium**.
  2. On reward granted → reveal detailed reasoning for this result.
- **Error / edge paths:**
  - Rewarded ad not loaded / fails → graceful message, offer retry or paywall;
    do **not** consume the unlock.
  - User dismisses ad early (no reward) → keep locked, no charge.
  - Offline → rewarded unavailable; show "Bağlantı yok" + paywall option.
- **Screens involved:** screen-result, screen-paywall.
- **Entitlement:** premium bypasses; free uses rewarded ad.

### flow-purchase: Subscribe to remove ads
- **Trigger:** Paywall (from Settings "Reklamları kaldır", or a rewarded prompt).
- **Happy path:** 1. Paywall shows monthly + annual + **7-day trial**. 2. Purchase
  via RevenueCat → entitlement "premium" active → ads removed app-wide; detailed
  view always unlocked.
- **Error / edge paths:**
  - Purchase cancelled → return to paywall, no error.
  - Payment fails / pending → friendly message; entitlement unchanged.
  - **Restore purchases** (mandatory) → re-applies entitlement on a new
    device/reinstall.
  - Billing retry / grace period / expiry → re-check entitlement on resume; on
    expiry, ads return.
  - Offline → paywall shows cached offerings or a retry; purchase requires network.
- **Screens involved:** screen-paywall, screen-settings.
- **Entitlement:** drives all gates via SubscriptionBloc.

### flow-history: Review past hands
- **Trigger:** Bottom nav → History (or Home "Tümü →").
- **Happy path:** 1. List of past scans (date, mode, verdict pill, score, rack
  thumbnail). 2. Filter all / opened / closed. 3. Tap a scan → re-open its Result.
- **Error / edge paths:**
  - **Empty** (no scans yet) → illustrated empty state with a "Scan now" CTA.
  - **No-results** (filter excludes all) → distinct "no matches" state.
  - Sync conflict (guest local vs account) → last-write-wins merge on sign-in.
  - Long history → infinite scroll, page size 20.
- **Screens involved:** screen-history, screen-result.
- **Entitlement:** free (banner ad present for free users).

### flow-settings: Configure the app
- **Trigger:** Bottom nav → Settings.
- **Happy path:** Adjust theme (light/dark/system/felt), tile style, accent,
  language (TR/EN), default game mode; manage account (sign in/out, **delete**),
  **restore purchases**, manage subscription, open legal links, view version.
- **Error / edge paths:** language switch re-renders all strings (ARB); theme
  persists; guest sees "Üye ol" upsell instead of account email.
- **Screens involved:** screen-settings, screen-login, screen-paywall.
- **Entitlement:** free.

### flow-consent: ATT & ads consent
- **Trigger:** First launch (after onboarding, before first ad / tracking).
- **Happy path:** 1. UMP consent form (EEA) and **iOS ATT** prompt shown at an
  appropriate moment. 2. Choice stored; analytics/personalized-ads gated on it.
- **Error / edge paths:** declined → non-personalized ads only; analytics
  minimized; app fully usable. ATT unavailable on simulator → guard.
- **Screens involved:** system prompts over screen-home.
- **Entitlement:** free.

## Screen catalog
For **every** screen, define **all** states (no screen ships happy-path-only).

### screen-splash: Splash / brand entry
- **Purpose:** Brand moment + entry (Devam et / Misafir).
- **States:** default · returning-user (auto-advance) · (no data/error N/A).
- **Key widgets / layout:** 1-0-1 letter tiles, serif "Açar mı?", two CTAs.
- **Responsive notes:** serif scales via FittedBox; survives textScale 2.0 on SE.

### screen-login: Login / sign-up
- **Purpose:** Email+password, Google, Apple, guest; toggle sign-in/up; forgot.
- **States:** signin · signup · loading (auth in flight) · field errors ·
  network error · provider-cancelled.
- **Key widgets:** email/password inputs, show/hide, OAuth buttons, guest link.
- **Responsive notes:** scroll on small screens; keyboard inset handled.

### screen-home: Home / dashboard
- **Purpose:** Mode chooser + primary scan CTA + last scan + stats.
- **States:** default · empty (no scans → seeded empty state, no stats) · loading
  (entitlement/stats) · offline banner.
- **Key widgets:** eyebrow "AÇAR MI?", greeting, 101/Okey chooser, scan CTA, last
  scan card, stats trio, bottom nav.
- **Responsive notes:** scan CTA min-height flexes; stats row wraps; SE/2.0 safe.

### screen-camera: Camera capture
- **Purpose:** Frame + capture the rack; photo/video/gallery.
- **States:** ready · permission-denied (rationale + Open Settings) ·
  permanently-denied · capturing · video-recording · gallery-picker · no-camera
  (fallback to gallery).
- **Key widgets:** viewfinder reticle, mode toggle, shutter, flash, gallery, flip.
- **Responsive notes:** full-bleed; safe-area insets for controls; portrait only.

### screen-analyzing: Detection in progress
- **Purpose:** Run on-device detection with progress feedback.
- **States:** processing (staged messages) · per-tile reveal · success →
  auto-advance · **failure** (no tiles / error) → retry · cancel (back).
- **Key widgets:** scan-line animation, detected-tile reveal w/ bounding boxes,
  progress bar, step counter.
- **Responsive notes:** rack preview scales; respects reduce-motion (no scan-line).

### screen-review: Review & correct + indicator
- **Purpose:** Verify detected tiles; fix number/color; **pick indicator**; adjust
  tile count.
- **States:** default · editing-tile (color+number panel) · low-confidence
  highlighted · indicator-not-set (block solve until set) · wrong-count warning ·
  add/remove tile.
- **Key widgets:** 2-row rack (14–21 tiles), per-tile edit panel, **indicator
  picker (color + number)**, count indicator, Hesapla CTA.
- **Responsive notes:** **critical** — rack must render up to 21 tiles across 2
  rows without overflow on SE @2.0 (horizontal scroll or tile-size flex per row).

### screen-result: Result / verdict
- **Purpose:** Deliver verdict + best arrangement.
- **States:** opens (Açar) · closes (Açmaz, points short) · okey-mode (tiles-to-win,
  no verdict) · detailed-locked (free) · detailed-unlocked · banner ad (free) ·
  loading (solving) · error (solver failure → retry).
- **Key widgets:** big serif verdict, score/101, visual rack w/ meld brackets +
  legend (rack/list layouts), detailed reasoning (gated), Again/Done, banner ad.
- **Responsive notes:** verdict via FittedBox; rack of up to 21 tiles wraps to 2
  rows; legend list scrolls; ad anchored, never overlaps CTAs.

### screen-history: History
- **Purpose:** Past scans, filter, re-open.
- **States:** populated · empty (no scans) · no-results (filter) · loading
  (sync) · offline (local only) · paginating.
- **Key widgets:** filter chips, scan cards w/ rack thumbnail + verdict pill,
  banner ad (free).
- **Responsive notes:** lazy ListView; thumbnails fixed ratio.

### screen-settings: Settings / profile
- **Purpose:** Preferences + account + purchases + legal.
- **States:** guest (upsell) · signed-in · loading (entitlement) · premium (hide
  paywall row, show manage) · free (show "Reklamları kaldır").
- **Key widgets:** profile card, General/Appearance/Game/About sections, restore,
  manage subscription, delete account, sign out, version.
- **Responsive notes:** sectioned list scrolls; rows survive textScale 2.0.

### screen-paywall: Remove-ads paywall
- **Purpose:** Sell premium (monthly/annual + trial).
- **States:** offerings loaded · loading · purchase-in-flight · success · error ·
  restore-in-flight · offline (retry).
- **Key widgets:** plan cards, trial copy, subscribe CTA, **Restore**, legal/terms
  links, close.
- **Responsive notes:** plan cards stack; CTA pinned; survives 2.0.

### screen-tutorial: How it works
- **Purpose:** 3-step explainer + worked example.
- **States:** default (static).
- **Key widgets:** numbered steps, example melds w/ scores.
- **Responsive notes:** cards stack; meld rows scroll horizontally if needed.

## Monetization spec
- **Model:** free with **ads**, plus a **"remove ads" subscription** via
  **RevenueCat** (network: **AdMob**, mediated/keyed through RevenueCat).
- **Products / tiers:** **monthly** + **annual**; single entitlement **`premium`**.
- **Paywall surfaces:** Settings "Reklamları kaldır"; the rewarded-unlock prompt on
  Result (offers "watch ad" or "go premium").
- **Ad placements:** **banner** on Result + History (free only); **rewarded** ad to
  unlock the per-result detailed reasoning (free only). **No interstitials.**
- **Free-tier limits:** unlimited scans; the only gate is the detailed reasoning
  view (rewarded ad or premium).
- **Trial:** **7-day** free trial on the subscription.
- **Required flows:** purchase · **restore** (mandatory) · upgrade/downgrade ·
  cancellation · billing-retry/grace · entitlement check before every gate (ads
  shown, detailed view) via **SubscriptionBloc**.
- **Consent:** **iOS ATT** + **UMP/GDPR** consent gate personalized ads + analytics.
- **Simulator testing:** iOS via `.storekit` config; Android + cross-platform via
  `FakePurchaseRepository` and `FakeAdsRepository` in the demo flavor (ads render
  as labeled placeholders; rewarded grants instantly).

## Permissions matrix
| Permission | Why | Requested when | Denied path | Permanently-denied path |
|-----------|-----|----------------|-------------|--------------------------|
| Camera | Capture the rack (photo/video) | In-context on first scan (photo/video mode) | Rationale + retry; offer gallery import fallback | Rationale + **Open Settings**; gallery import still works |
| Photo library | Import an existing rack photo | When choosing gallery mode | Rationale + retry | Rationale + **Open Settings** |
| App Tracking (iOS ATT) | Personalized ads / analytics | After onboarding, before tracking | Non-personalized ads only | N/A (system-managed) |

> No microphone for video (silent capture). No location, contacts, or notifications.

## Data model
- **Entities & relationships:**
  - **User** (when signed in): id, email, displayName, createdAt, providers.
  - **Scan**: id, ownerId (or local), createdAt, gameMode (101|okey), indicator
    {color, number}, tiles[] {number|null, color|joker, confidence}, result
    {arrangement: melds[], leftover[], total, opens|distanceToWin}, thumbnailRef.
  - **Meld**: type (set|run|pair), tiles[], score.
  - **Preferences** (device): theme, tileStyle, accent, language, defaultMode,
    consent state.
- **Source of truth:** local **drift** for guest scans + all preferences; **Firestore**
  (owner-scoped) for signed-in users' scans, synced from local.
- **Offline:** **offline-first** — capture/detect/solve/save all work offline.
  Sync queues and flushes on reconnect (last-write-wins). Ads/auth need network.
- **Sync & conflict resolution:** on sign-in, merge local guest scans into the
  account; thereafter Firestore is canonical with a drift read-through cache;
  conflicts resolved last-write-wins by `createdAt`/`updatedAt`.

## Non-functional requirements
- **Responsive size matrix:** iPhone SE, iPhone 16 Pro, iPhone 16 Pro Max; small /
  Pixel-class Android; each at textScale 1.0 and 2.0. **Zero render (overflow)
  errors on any.** Tablet (iPad) runs the scaled phone layout and must also not
  overflow. **Special case:** the rack widget must render **14–21 tiles in 2 rows**
  without overflow at the smallest size + textScale 2.0 (per-row tile-size flex
  and/or horizontal scroll).
- **Accessibility:** Semantics on interactive + icon-only elements (camera shutter,
  tile-edit buttons, indicator picker), WCAG AA contrast, ≥48dp targets, survives
  textScale 2.0, respects reduce-motion (no scan-line/pulse).
- **Localization:** **Turkish (default) + English**; **all** user-facing strings via
  ARB; `intl` for dates/numbers; no RTL.
- **Performance:** OpenCV/ML Kit detection and the solver run **off the UI isolate**;
  lazy history list; cached/resized thumbnails; solver memoized; camera released on
  background.
- **Security:** Firebase-managed auth tokens (+ `flutter_secure_storage` for any
  extra secrets); **Firestore rules owner-scoped** (`ownerId == request.auth.uid`);
  **no secrets in repo** (RevenueCat public key + AdMob IDs via `--dart-define` /
  platform config); no biometric app lock.
- **Crash/analytics:** Firebase Crashlytics (release) + Firebase Analytics, both
  behind thin interfaces (fakes in demo), consent-gated, PII scrubbed.

## Assumptions log
Every default the user did **not** explicitly decide, with its final status.
Init is not complete until every row is Confirmed or Overridden.

| # | Area | Assumed default | Status |
|---|------|-----------------|--------|
| 1 | Backend (7) | Firebase: Auth + Firestore + Analytics + Crashlytics | **Confirmed** |
| 2 | Auth (3) | email+Google+Apple+guest; verification on; reset on; in-app account deletion; re-auth before delete; silent token refresh | **Confirmed** |
| 3 | Data/sync (7) | guest local (drift); sync to Firestore on sign-in; offline-first; last-write-wins | **Confirmed** |
| 4 | Rack counts (domain) | ~~14–15 tiles, 2 rows~~ → **101 Okey = 20–21**, **Okey = 14–15**, 2 rows; rack UI renders 14–21 overflow-free | **Overridden** |
| 5 | Joker (domain) | ~~joker = same color +1; false jokers act as okey~~ → indicator selected; **okey = color, (n+1) mod 13**; **okey AND false jokers fully wild** (false jokers locked to the okey tile) | **Overridden** |
| 6 | Solver | max-score legal arrangement; 101 verdict ≥101 / 5-pair; Okey mode tiles-to-win; wild takes substituted value | **Confirmed** |
| 7 | Detection errors (25) | no-tiles / wrong-count / blur / glare → retry + manual edit; never dead-end | **Confirmed** |
| 8 | Navigation (5) | bottom nav 3 tabs; go_router; Android back → pop; no external deep links v1 | **Confirmed** |
| 9 | Screen states (6) | every screen: loading/empty/error+retry/offline/success | **Confirmed** |
| 10 | Onboarding (4) | splash + optional 3-step tutorial; camera primed in-context; inviting empty states | **Confirmed** |
| 11 | History (14) | filter chips; infinite scroll page size 20; empty vs no-results distinct | **Confirmed** |
| 12 | Profile (13) | editable display name only; no avatar upload v1; private | **Confirmed** |
| 13 | Monetization (11) | unlimited free scans; rewarded unlocks detailed view; premium removes ads + always unlocked; AdMob via RevenueCat; banner + rewarded only | **Confirmed** |
| 14 | Permissions (9) | camera (required, in-context) + photos (gallery); denied → rationale + Open Settings; camera-denied falls back to gallery | **Confirmed** |
| 15 | Legal (21) | Privacy+ToS URLs (human); ATT + UMP consent; account+data deletion; no age gate | **Confirmed** |
| 16 | Security (22) | Firebase tokens + secure_storage; owner-scoped rules; no repo secrets; no biometric lock | **Confirmed** |
| 17 | Localization (16) | Turkish default + English; ARB; intl; no RTL | **Confirmed** |
| 18 | Theming (17) | light/dark/system/felt; sage seed + accent picker (4); google_fonts Geist/Geist Mono/Instrument Serif; 4 tile styles | **Confirmed** |
| 19 | Accessibility (18) | semantics; textScale 2.0; AA; ≥48dp; reduce-motion | **Confirmed** |
| 20 | Analytics/Crash (19/20) | thin interface; Firebase Analytics + Crashlytics in prod; consent-gated; PII scrubbed | **Confirmed** |
| 21 | Lifecycle/Perf (23/24) | refresh entitlement on resume; release camera on background; detection/solver off-isolate; lazy lists; cached images | **Confirmed** |
| 22 | Identity/NFR (28/29) | name "101 Okey Açar Mı"; bundle com.okeyacarmi.okey_acar_mi; icon/splash from 1-0-1 wordmark; responsive matrix incl. iPad scaled; zero overflow | **Confirmed** |

## Out of scope (v1)
- Account avatar upload; profile beyond display name.
- Sharing results (image export / share sheet) — deferred to v2.
- Push / local notifications, FCM.
- External deep links / universal links.
- Landscape orientation; dedicated tablet layouts.
- Interstitial ads.
- On-device → cloud detection fallback (detection is fully on-device).
- Real-money / gambling features (none — this is a solver).
- Video frame scrubber beyond basic multi-frame aggregation.
