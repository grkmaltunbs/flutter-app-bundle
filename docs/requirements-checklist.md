# Requirements coverage checklist

The canonical "things people forget" list. `/init-app` walks this category by
category during intake. The goal is **completeness**: for every item, either the
user makes an explicit decision, or Claude records a sensible **default** and
surfaces it in the assumptions gate for confirmation. Nothing is left implicit.

Every decision (or confirmed default) is written into `PRODUCT_SPEC.md`. The
`PROJECT_PLAN.md` step ladder is derived from that spec — so coverage here
becomes coverage in the plan.

> **How to use this during intake:** Go category by category, one focused
> question at a time (use `AskUserQuestion`). When the user has no opinion,
> propose the default, mark it as an **assumption**, and move on. Do **not**
> block the interview waiting for perfect answers — capture the default and let
> the assumptions gate (end of intake) force a final confirm/override pass.

Legend for each item: **Ask** = what to elicit · **Default** = what to assume if
undecided · **Why it bites** = the failure mode if skipped.

---

## 1. Platforms & form factors
- **Ask:** iOS, Android, web, desktop? Phone only or tablet too? Orientations?
- **Default:** iOS + Android, phone + tablet, portrait + landscape.
- **Why it bites:** Tablet/landscape layouts are an afterthought → overflow and
  stretched UI on real devices.

## 2. Core features & primary loop
- **Ask:** What is the one core loop a user repeats? What are v1 features vs
  later? Rank by priority.
- **Default:** Smallest loop that delivers the core value; everything else → v2.
- **Why it bites:** Scope creep; "v1" balloons and never ships.

## 3. Authentication & account lifecycle
- **Ask:** Anonymous/guest mode? Sign-up methods (email/password, Google, Apple,
  phone)? Email verification? Password reset? Sign-out? **Account deletion**
  (Apple App Store *requires* in-app account deletion if you have accounts)?
  Re-authentication for sensitive actions? Multi-device? Session/token expiry
  handling?
- **Default:** Email/password + Google + Apple (Apple Sign-In is required by
  Apple if you offer any third-party login); email verification on; password
  reset on; in-app account deletion present; silent token refresh with a
  re-login fallback.
- **Why it bites:** Missing account deletion → App Store rejection. Unhandled
  token expiry → silent logouts and infinite spinners.

## 4. Onboarding & first-run
- **Ask:** Welcome/intro screens? Permission priming before the OS prompt?
  Tutorial/coach marks? What does the very first empty state look like?
- **Default:** One concise value-prop screen, prime permissions in-context (not
  on launch), seed an inviting empty state.
- **Why it bites:** Cold launch into an empty, contextless screen; OS permission
  prompts fired on launch and denied.

## 5. Navigation & information architecture
- **Ask:** Tabs, drawer, or stack-first? How many top-level destinations? Deep
  links / universal links? Back-button behavior (Android hardware back)?
- **Default:** Bottom nav for 3–5 destinations, `go_router` with deep links,
  Android back maps to router pop.
- **Why it bites:** Deep links and Android hardware back are routinely forgotten
  → broken navigation from notifications/links.

## 6. Per-screen states (mandatory for EVERY screen)
- **Ask:** For each screen: loading, empty, error, success, partial, and offline
  states — what does each look like?
- **Default:** Skeleton/spinner for loading, illustrated empty state with a CTA,
  inline error with retry, offline banner.
- **Why it bites:** Screens built only for the happy "full data" path; real
  users see spinners forever or blank screens on error.

## 7. Data model & persistence
- **Ask:** Core entities and relationships? Source of truth (server vs local)?
  Offline-first or online-only? Local cache (drift)? Sync & conflict resolution?
- **Default:** Server is source of truth, drift as local cache, last-write-wins,
  read-through cache with optimistic UI where safe.
- **Why it bites:** No offline story → app is unusable on flaky networks.

## 8. Connectivity & offline behavior
- **Ask:** What works offline? How is "no connection" surfaced? Queued writes?
- **Default:** Reads from cache offline, writes queued where safe, global
  offline banner, automatic retry on reconnect.
- **Why it bites:** Spinner-of-death and lost user input when offline.

## 9. Permissions & denied paths
- **Ask:** Which permissions (camera, photos, location, mic, notifications,
  contacts, health, etc.)? When requested? What happens on **denied** and
  **permanently denied** (deep link to Settings)?
- **Default:** Request in-context at point of need; on permanent denial show a
  rationale + "Open Settings" button; degrade gracefully.
- **Why it bites:** App dead-ends when a permission is denied; no recovery path.

## 10. Push & local notifications
- **Ask:** Push types and their deep-link targets? Local notifications/reminders?
  Foreground-message handling? When is notification permission requested?
- **Default:** Permission primed after first value moment; taps deep-link to the
  relevant screen; foreground messages shown as in-app banners.
- **Why it bites:** Notification taps that go nowhere; permission asked too early
  and denied. (Note: APNS tokens are unavailable on the iOS simulator — guard.)

## 11. Monetization
- **Ask:** Model (free / freemium / paid / subscription / ads)? Products & tiers?
  Where are the paywalls (which surfaces/gates)? Free-tier limits? Free trial?
  Restore purchases? Upgrade/downgrade? Cancellation & billing-retry/grace?
  Entitlement checks per gated feature?
- **Default (subscriptions):** RevenueCat with monthly + annual, a single
  "premium" entitlement, paywall on first gated action, 7-day trial, mandatory
  Restore button, entitlement checked via `SubscriptionBloc` before every gate.
- **Why it bites:** Restore is App Store-required and routinely omitted; gates
  checked inconsistently → paid content leaks or false paywalls.

## 12. Settings & preferences
- **Ask:** Theme toggle? Language? Notification toggles? Account management?
  Legal links? About/version? Data export/delete?
- **Default:** Theme (light/dark/system), language picker, notification
  toggles, account section (incl. delete), legal links, version string.

## 13. Profile & user content
- **Ask:** Editable profile? Avatar upload? Privacy/visibility controls?
- **Default:** Editable display name + avatar, private by default.

## 14. Search, filter, sort, pagination
- **Ask:** Which lists need search/filter/sort? Page size? Infinite scroll vs
  pages?
- **Default:** Debounced search, infinite scroll with page size 20, empty/“no
  results” state distinct from the empty-collection state.
- **Why it bites:** Loading all rows at once → jank and overflow on long lists.

## 15. Sharing & deep links
- **Ask:** Shareable content? Universal/app links? Share-sheet targets?
- **Default:** Share via native sheet, universal links resolve to the right
  screen with a cold-start fallback.

## 16. Localization & i18n
- **Ask:** Which languages at launch? RTL? Locale-aware dates/numbers/currency?
  Pluralization?
- **Default:** English only at launch but **all user-facing strings via ARB**
  from day one; RTL-safe layouts; `intl` for dates/numbers.
- **Why it bites:** Hardcoded strings make later localization a full rewrite.

## 17. Theming
- **Ask:** Light/dark/system? Brand seed color? Dynamic color (Material You)?
  Custom fonts?
- **Default:** Light + dark + system via `ColorScheme.fromSeed`, brand seed
  color, `google_fonts` text theme.

## 18. Accessibility
- **Ask:** Screen-reader support? Text scaling up to 2x? Contrast targets?
  Reduce-motion? Tap-target sizes?
- **Default:** Semantics on all interactive/icon-only elements, layouts survive
  textScale 2.0, WCAG AA contrast, ≥48dp targets, respect reduce-motion.
- **Why it bites:** Text-scaling overflow and unlabeled buttons fail real users
  and store accessibility checks.

## 19. Analytics & telemetry
- **Ask:** Track events? Which? User properties? Consent required first?
- **Default:** A thin analytics interface (fake in demo flavor) with core funnel
  events, gated behind consent where required.

## 20. Crash & error reporting
- **Ask:** Crashlytics, Sentry, or none? Capture handled errors too?
- **Default:** Crashlytics (or Sentry) in release, behind a logging interface;
  handled `Failure`s recorded, PII scrubbed.

## 21. Legal & compliance
- **Ask:** Privacy policy & ToS URLs? App Tracking Transparency (iOS)? GDPR/
  consent banner? Age gating? Data export/delete (right to be forgotten)?
- **Default:** Privacy + ToS links in settings, ATT prompt before any tracking,
  consent gate where required, account+data deletion available.
- **Why it bites:** Missing ATT/consent or privacy links → store rejection.

## 22. Security
- **Ask:** Secure storage for tokens? App lock / biometrics? Certificate
  pinning? Where do secrets/keys live?
- **Default:** `flutter_secure_storage` for tokens, optional biometric lock,
  no secrets in the repo (provided via `--dart-define` / CI), Firestore rules
  scoped to the owner.

## 23. App lifecycle & background
- **Ask:** Refresh on resume? Background fetch? Cold-start from deep link/
  notification? Handle app being killed mid-flow?
- **Default:** Refresh stale data on resume, restore navigation/deep-link target
  on cold start, no silent data loss on kill.

## 24. Performance & limits
- **Ask:** Largest expected list/dataset? Image sizes? Rate limits? Frame-budget
  sensitive screens (charts, animations)?
- **Default:** Lazy lists everywhere, cached/resized network images, heavy work
  (>16ms) off the UI isolate, memoized chart data.

## 25. Error handling & resilience
- **Ask:** Retry strategy? Timeouts? How are errors surfaced to the user?
- **Default:** Typed `Failure`s mapped to friendly messages, retry with backoff
  on transient errors, no silent failures.

## 26. Edge content
- **Ask:** Very long text, no data, slow network, huge datasets, special
  characters/emoji — handled per screen?
- **Default:** Text truncates/wraps gracefully, skeletons during slow loads,
  pagination for large sets. (These become explicit test cases.)

## 27. Platform-specific behavior
- **Ask:** iOS vs Android differences — back gesture, share sheet, haptics,
  status-bar styling, safe-area/notch, edge-to-edge?
- **Default:** Respect platform conventions; test both. Honor safe areas and
  display cutouts.

## 28. App identity & store presence
- **Ask:** App name, bundle/app ID, icon source art, splash, store listing
  metadata & screenshots?
- **Default:** Claude generates a placeholder icon + splash and wires
  `flutter_launcher_icons`/`flutter_native_splash`; final art & store metadata
  are human tasks in `HUMAN_SETUP.md`.

## 29. Non-functional requirements
- **Ask:** Minimum OS versions? Supported device matrix? Responsive size matrix?
- **Default:** iOS 14+, Android API 24+. Responsive size matrix (used by QA):
  - **iOS:** iPhone SE (smallest), iPhone 16 Pro (typical), iPhone 16 Pro Max
    (large), iPad (tablet).
  - **Android:** a small phone, a Pixel-class phone, a tablet AVD.
  - **Text scale:** 1.0 and ~2.0 on each.

---

## Assumptions gate (end of intake — mandatory)

Before `/init-app` completes, present **every item that was left to a default**
as an explicit list and require the user to confirm or override each one:

```
You didn't specify these — here's what I'll assume. Confirm or change:
  [ ] (3) Auth: email + Google + Apple, verification on
  [ ] (11) Monetization: RevenueCat, monthly+annual, 7-day trial
  [ ] (16) Localization: English only at launch, all strings via ARB
  ... one line per assumed default ...
```

Record each as **Confirmed** or **Overridden** in `PRODUCT_SPEC.md` →
*Assumptions log*. Init is not "done" until this list is cleared. This is the
mechanism that prevents "I forgot to mention that flow" surprises after the plan
is built.
