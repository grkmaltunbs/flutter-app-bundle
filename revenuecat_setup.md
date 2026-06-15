# 101 Okey Açar Mı / RevenueCat — full production setup (start → finish)

End-to-end runbook to take **101 Okey Açar Mı** subscriptions live: creating the
apps in both stores, all agreements/credentials, the products, RevenueCat, and
going to production. This is the **account/dashboard work**.

> Verified against Apple / Google / RevenueCat docs (June 2026). Exact console
> labels shift occasionally; the paths below were current at writing.

> ⚠️ **Unlike a "code-already-wired" project, the in-app monetization code is NOT
> built yet.** Step 11 (Monetization) of `PROJECT_PLAN.md` is still open: there is
> no `Purchases.configure()`, no paywall, no entitlement gate, no Restore button
> in `lib/` yet (the RevenueCat **Pods** are installed, but nothing Dart-side
> consumes them). **This runbook is the store/RevenueCat account work; it can be
> done in full now, but real in-app purchases can't be tested until Step 11 lands.**
> Run Step 11 with `/step` when the dashboards are ready.

---

## Project-specific values (use these verbatim)

| Thing | Value |
|---|---|
| **iOS** bundle ID | `com.okeyacarmi.okeyAcarMi` |
| **Android** applicationId | `com.okeyacarmi.okey_acar_mi` |
| App display name | `101 Okey Açar Mı` |
| Monthly product ID | `com.okeyacarmi.premium.monthly` |
| Yearly product ID | `com.okeyacarmi.premium.annual` |
| Android base-plan IDs | `monthly` / `annual` ← **use whatever you actually created in Play** |
| → RevenueCat **Google** product IDs | `com.okeyacarmi.premium.monthly:monthly`, `com.okeyacarmi.premium.annual:annual` |
| Entitlement ID | `premium` |
| Offering | mark one as **Default** (name it `default`) with a **Monthly** (`$rc_monthly`) + **Annual** (`$rc_annual`) package |
| Free trial | **7 days** (see note below) |
| Suggested prices | **₺29,99/ay**, **₺199,99/yıl** (from `ios/Configuration.storekit`; adjust freely) |
| Firebase project | `okeyacarmi-dcb8c` |
| Dart-define secrets file | `dart_defines/prod.json` (**git-ignored**; template `dart_defines/prod.example.json`) |
| iOS sim StoreKit config | `ios/Configuration.storekit` |
| Webhook function | **none — optional/future** (v1 gates client-side via `SubscriptionBloc`) |

> ⚠️ **The bundle IDs differ per platform** — Apple forbids underscores, so iOS is
> camelCase `com.okeyacarmi.okeyAcarMi` while Android keeps `com.okeyacarmi.okey_acar_mi`.
> Use each platform's **exact** string in its store and in its RevenueCat app.
> (`CLAUDE.md` documents both correctly.)

> **Free-trial placement:** the project spec calls for a 7-day trial. A common
> convention (to curb trial-farming) is **yearly-only**; the simplest is **both
> products**. **Match whatever you already created on Android** so the two stores
> stay consistent. This doc shows it on both; drop the monthly offer if you prefer
> yearly-only.

---

## Where you are right now (from setup so far)

- [x] RevenueCat **project** created; **iOS app** + **Android app** added (both SDK keys obtained)
- [x] Android **service-account JSON** uploaded (validation **propagating** — 2/3 checks green)
- [x] Android **subscriptions** created in Play Console (monthly + annual)
- [x] Public SDK keys staged in `dart_defines/prod.json` (git-ignored)
- [ ] **RevenueCat catalog** — Products → attach to `premium` → `default` offering ← **DO THIS NEXT** (Part C4–C7)
- [ ] **RTDN** test (Part B7 / C3)
- [ ] Android credentials go **green** (wait ~24–36 h)
- [ ] **iOS store side** — Apple enrollment, Paid Apps Agreement Active, ASC subscriptions, `.p8` key (Part A)
- [ ] Android **App content** declarations + **closed-testing** gate (Part B4, B8)
- [ ] **Step 11** — in-app code: paywall, `premium` gate, Restore (`/step`)
- [ ] Sandbox testing (needs Step 11) → go-live

---

## The dependency chain (why ordering matters)

The #1 cause of "my products don't show up / offering is empty" is doing these out
of order. Both stores gate product fetching on agreements + credentials:

```
Apple:  Enroll → register App ID (com.okeyacarmi.okeyAcarMi) → create app record →
        Paid Apps Agreement ACTIVE (tax + banking cleared) → create subscriptions → IAP .p8 Key
Google: Account → payments profile → create app → upload signed .aab to a track →
        app-content declarations → create+activate subscriptions → service account +
        3 Play permissions (wait ~24–36h)
Both →  RevenueCat: add apps + creds → entitlement → products → attach → offering →
        public keys → (optional webhook) → sandbox test → go live
```

Apple and Google tracks are independent — run them in parallel.

---

# PART A — Apple (App Store Connect)

**Prereqs:** an Apple Account with **2-factor auth ON**; your **legal name**; a card
for the **$99/yr** fee; a Turkish **IBAN** + **tax/identity number** (TCKN/VKN). A
Mac/Xcode is **not** needed for A1–A6 (browser-based); Xcode is only needed later
to upload the build.

### A1. Enroll in the Apple Developer Program ($99/yr)
- **developer.apple.com/programs/enroll/** — sign in (2FA), choose **Individual**
  (recommended for a solo app — near-instant, no D-U-N-S) vs Organization (needs a
  free **D-U-N-S number** + website; days to verify). Enter your **legal name
  exactly**, accept, pay $99.
- Individual approval is usually minutes–48h. Pay with **your own** card or Apple
  may ask for photo ID.

### A2. Register the App ID
- **developer.apple.com/account → Certificates, Identifiers & Profiles →
  Identifiers → (＋) → App IDs → App → Explicit** → Bundle ID
  **`com.okeyacarmi.okeyAcarMi`** → Register.
- Enable **Sign in with Apple** (mandatory — you offer Google sign-in). In-App
  Purchase is on by default for explicit App IDs.

### A3. Create the app record
- **appstoreconnect.apple.com → Apps → (＋) → New App** — Platform **iOS**; Name
  `101 Okey Açar Mı`; Primary Language **Turkish (Türkçe)**; Bundle ID = select
  `com.okeyacarmi.okeyAcarMi`; SKU = internal e.g. `OKEYACARMI001` (permanent).
- If (＋) is blocked, do **A4** first.

### A4. Paid Apps Agreement + Tax + Banking — make it **ACTIVE** ← #1 blocker
> Apple, verbatim: *"The agreement must be Active to test In-App Purchases in the
> sandbox."* Until **Active**, RevenueCat fetches **zero** iOS products. Not
> "signed" — **Active**.
- **App Store Connect → Business → Agreements** → **Paid Apps** → **View and Agree
  to Terms** (only the **Account Holder** can sign).
- **Tax Forms** → add the **Paid Apps** form. As a Turkish developer complete the US
  **W-8BEN** (individual) with your Turkish tax/identity number. ⚠️ **W-8BEN is
  final on submit** — verify legal name + country (Türkiye) first.
- **Bank Accounts** → Add → Country **Türkiye**, currency **TRY**, **IBAN** in the
  IBAN field (leading zeros), holder name **exactly** as the bank prints it. Wait
  for status **Clear**.
- The agreement flips **Pending → Active** once tax + banking clear (hours–~a day).

### A5. Create the subscriptions
**App Store Connect → Apps → 101 Okey Açar Mı → Monetization → Subscriptions**
1. **(＋) Subscription Group** — Reference Name e.g. `101 Okey Premium`. Both
   products go in **one group** (monthly↔yearly is an upgrade/downgrade; one trial
   per user).
2. **Create** → product **`com.okeyacarmi.premium.monthly`** (Ref Name "Premium
   Monthly"), Duration **1 Month**. ⚠️ Product ID is **permanent & non-reusable**.
3. **Create** → product **`com.okeyacarmi.premium.annual`** (Ref Name "Premium
   Annual"), Duration **1 Year**.
4. **Subscription ranking** → both at the **same level** (same `premium`
   entitlement = crossgrade).
5. **Subscription Prices** → for each, base on **Türkiye/TRY** (≈ **₺29,99/mo**,
   **₺199,99/yr**). Apple auto-converts other storefronts. Set price **before** the
   trial.
6. **Localizations** — add at **both** the **group** level **and** each **product**
   level (Türkçe + English). Missing the **group** localization is the most common
   cause of stuck **"Missing Metadata"** (ASC often doesn't flag it).
7. **7-day trial** — on the chosen product(s) → Subscription Prices → **Set Up
   Introductory Offer** → countries (incl. Türkiye) → Type **Free** → Duration **1
   Week** (= 7 days; there's no literal "7 days" option). ⚠️ Intro offers **can't be
   edited** after creation.
8. **Review screenshot** — each product → Review Information → upload a **portrait
   screenshot of the paywall** (e.g. 1290×2796) + review notes. **Only the App
   reviewer sees it.** ⚠️ The paywall screen doesn't exist until **Step 11** — until
   then, either capture it after Step 11 builds the paywall, or submit the products
   alongside the app's first build. Treat as **required** to reach "Ready to Submit".
9. Products show **"Ready to Submit"**; they reach **"Approved"** only with the
   app's **first review** — but you can sandbox-test once they're Ready to Submit
   and the agreement is **Active**.

### A6. Generate the In-App Purchase Key for RevenueCat (**required**)
> RevenueCat, verbatim: with Purchases SDK v5+/StoreKit 2 (your `purchases_flutter`
> 10.x), *"transactions will fail to be recorded without this key."* The legacy
> shared secret is **not** sufficient.
- **App Store Connect → Users and Access → Integrations → Keys → In-App Purchase →
  Generate** → name `RevenueCat 101 Okey` → **download the `.p8` (one time only!)**.
  Note the **Key ID** (row) and **Issuer ID** (UUID at top). Upload these in **C2**.
- App-Specific Shared Secret is **optional** (StoreKit 1) — skip.

---

# PART B — Google (Play Console)

**Prereqs:** a Google account with 2-Step Verification; **$25** one-time fee (no
prepaid cards); government photo ID; a **Turkey payments profile** (TRY payout).

> You have already done much of B5–B6. The steps are kept here for completeness and
> for the **closed-testing gate (B8)**, which is the biggest schedule risk.

### B1. Create the Play Console developer account
- **play.google.com/console/signup** — **Personal** (simplest) or Organization;
  accept; pay **$25**; complete ID verification (hours–2 days).

### B2. Payments / merchant profile
- **Play Console → Setup → Payments profile** — create a **Turkey** profile (TRY
  payout). Required before any subscription can be created.

### B3. Create the app + upload a signed build to a track
- **Play Console → All apps → Create app** — name `101 Okey Açar Mı`; default
  language **Türkçe (tr-TR)**; type **App**; **Free**.
- **Test and release → Testing → Internal testing → Create new release** — enroll
  in **Play App Signing**, upload a **signed `.aab`** built with
  `applicationId=com.okeyacarmi.okey_acar_mi`. ⚠️ **Subscriptions can't be
  activated until a build with the Play Billing Library is uploaded & processed**
  (`purchases_flutter` 10.x bundles Billing 7+ and auto-adds the `BILLING`
  permission — don't add it manually).

### B4. App-content declarations (Play blocks production until complete)
- **Play Console → Policy → App content** — complete **all**: Privacy policy URL
  (must disclose **rack photos sent to Google Vertex AI for tile detection** +
  AdMob/Analytics), Ads, **App access** (the app is behind sign-in — provide test
  credentials or review fails), Content rating (IARC), Target audience, **Data
  safety** (Firebase Auth, FCM, camera, advertising ID), Advertising ID. Set the
  store listing + select **Türkiye** (and others).

### B5. Create + activate the subscriptions  ✅ (done)
> Hierarchy: **subscription → base plan → offer**. Users buy the **base plan**.
> RevenueCat's product ID is `subscriptionId:basePlanId`.
- **`com.okeyacarmi.premium.monthly`**, base plan `monthly`, **Auto-renewing**,
  **Monthly**, **TRY** price → **Save → Activate**.
  (RevenueCat ID: `com.okeyacarmi.premium.monthly:monthly`.)
- **`com.okeyacarmi.premium.annual`**, base plan `annual`, **Auto-renewing**,
  **Yearly**, **TRY** price → **Save → Activate**.
  (RevenueCat ID: `com.okeyacarmi.premium.annual:annual`.)
- **7-day trial** → base plan → **Add offer** → ID `freetrial-7d` → eligibility
  **New customer acquisition** → phase **Free trial, 7 days** → region Türkiye →
  **Save → Activate**.
- ⚠️ Product/base-plan/offer IDs are **permanent & globally non-reusable**. Each
  must be **Activated** (Save ≠ Active). Don't put price/"free trial" wording in the
  Name/benefits (Google flags it).

### B6. Service account credentials for RevenueCat  ✅ (uploaded; propagating)
1. **Google Cloud Console** (project = **okeyacarmi-dcb8c**) → **APIs & Services →
   Library** → enable **Google Play Android Developer API**, **Google Play
   Developer Reporting API**, **Cloud Pub/Sub API** (the RevenueCat `credentials.sh`
   script does this automatically).
2. **IAM & Admin → Service Accounts** — `revenuecat-service-account`, roles **Pub/Sub
   Editor** + **Monitoring Viewer** (for RTDN/metrics, *not* Play billing access).
3. **Manage keys → Add key → JSON** → download `revenuecat-key.json`. **Secret —
   git-ignored, never commit.**
4. **Play Console → (account-level) Users and permissions → Invite** → the
   service-account email → **Account permissions** → tick **all three**: *View app
   information (read-only)* · *View financial data, orders, and cancellation survey
   responses* · **Manage orders and subscriptions** (the one people forget). ⚠️
   **Account-level**, not app-level.
5. ⏳ **Wait ~24–36 h** for propagation. "Invalid/needs-attention" until then is
   **expected**. (The **subscriptions API** check is the last to go green — your
   now-Active subscriptions give it something to validate.)

### B7. Real-time Developer Notifications (do from RevenueCat — see C3)
- On the RevenueCat Android app → **Connect to Google** → it generates a Pub/Sub
  **Topic ID** → **Play Console → Monetize → Monetization setup → Real-time
  developer notifications** → paste **Topic name** → **"Subscriptions, voided
  purchases, and all one-time products"** → **Save** → **Send test notification**.
  Success = a **"Last received"** timestamp back in RevenueCat.
- If the test fails: grant `google-play-developer-notifications@system.gserviceaccount.com`
  the **Pub/Sub Publisher** role on that topic.

### B8. ⚠️ Closed-testing gate (biggest schedule risk)
- **Personal** accounts created after **2023-11-13** must run a **Closed testing**
  track with **≥12 testers opted-in for 14 consecutive days** before requesting
  production access (internal testing does **not** count toward the 14 days). Start
  recruiting testers **early**. Organization accounts may be exempt — verify.

---

# PART C — RevenueCat dashboard

### C1. Project  ✅ (done)
- **app.revenuecat.com** → one project `101 Okey Açar Mı` holds **both** platforms.

### C2. iOS (App Store) app
- **Project Settings → Apps & providers → ＋ New → App Store** — App name `101 Okey
  Açar Mı`; **Bundle ID `com.okeyacarmi.okeyAcarMi`**.
- **In-app purchase key configuration** → upload the **`.p8`** from **A6** + paste
  **Issuer ID** (+ Key ID). **Required.** Optionally add the App Store Connect API
  key to auto-import products.

### C3. Android (Play Store) app  ✅ (added; creds propagating)
- **Apps & providers → ＋ New → Play Store** — Package Name
  **`com.okeyacarmi.okey_acar_mi`** → upload **`revenuecat-key.json`** (B6). Then
  **Connect to Google** for RTDN (finish in **B7**).

### C4. Entitlement  ← do next
- **Product catalog → Entitlements → ＋ New** → identifier **`premium`**.

### C5. Products  ← do next
- **Product catalog → Products** →
  - **App Store** tab: add `com.okeyacarmi.premium.monthly`, `com.okeyacarmi.premium.annual`.
  - **Play Store** tab: add `com.okeyacarmi.premium.monthly:monthly` and
    `com.okeyacarmi.premium.annual:annual`.
- Products must exist in the stores first (Android ✅). **Import** works only once
  store credentials are **green**; otherwise **add manually** by typing the IDs.

### C6. Attach products to the entitlement  ← easy to forget
- **Entitlements → premium → Attach** → add all product rows (2 Google now; the 2
  Apple once C2/A5 are done). **Without this, purchases succeed but nothing unlocks.**

### C7. Offering with Monthly + Annual packages  ← do next
- **Product catalog → Offerings → ＋ New** → identifier `default` → **Mark as the
  Default Offering** (the SDK reads it as `offerings.current`) →
  - package **Monthly** (`$rc_monthly`) → attach the monthly product(s)
  - package **Annual** (`$rc_annual`) → attach the yearly product(s)
- Don't configure the trial here — it's **auto-detected** from the stores.

### C8. Public SDK keys → into the build  ✅ (staged)
- **Project Settings → API keys** → the **public** keys: iOS **`appl_…`**, Android
  **`goog_…`**. They live in **`dart_defines/prod.json`** (git-ignored; copy
  `dart_defines/prod.example.json`):
  ```json
  { "APP_ENV": "prod", "REVENUECAT_IOS_KEY": "appl_…", "REVENUECAT_ANDROID_KEY": "goog_…" }
  ```
- ⚠️ Use the **public** SDK keys (not a secret `sk_` key, never in the app). Never
  ship a **Test Store** key in a release build (it fails review).

### C9. Webhook → Firebase function  *(optional — NOT built for v1)*
> 101 Okey v1 gates entitlement **client-side**: `SubscriptionBloc` reads
> `CustomerInfo.entitlements.active['premium']` from the SDK. **No server webhook is
> required** for the app to work, and none exists in this repo.
- Add this **only if** you later want server-side sync (e.g. mirror `premium` to
  Firestore for analytics/cross-device). It would mean: a Cloud Function (not yet in
  `functions/`), a shared secret via `firebase functions:secrets:set`, and a
  RevenueCat **Integrations → Webhooks** entry with an `Authorization: Bearer
  <secret>` header. Out of scope until explicitly planned.

---

# PART D — Build & run with the keys

```bash
# dev (real backends + RevenueCat) — only meaningful AFTER Step 11 wires the SDK
flutter run            --dart-define-from-file=dart_defines/prod.json
# release
flutter build appbundle --release --dart-define-from-file=dart_defines/prod.json
flutter build ipa       --release --dart-define-from-file=dart_defines/prod.json
# demo flavor (fakes, no secrets) — current default for verification
flutter run --dart-define=APP_ENV=demo -d <device>
```
Add the same `--dart-define-from-file` to CI release jobs. **Until Step 11 wires
`Purchases.configure()`, these keys are read but unused** — the app runs fine and
the paywall doesn't exist yet.

---

# PART E — Sandbox testing  *(requires Step 11 in-app code)*

**iOS:** App Store Connect → Users and Access → **Sandbox → Testers** → create a
tester. On a real device: sign out of your Apple ID, add the sandbox account
(Settings → Developer → Sandbox Apple Account, iOS 18+), run a dev build, buy the
trial product → confirm the **7-day trial** shows and `premium` unlocks. Toggle
**View sandbox data** in RevenueCat. (On the iOS **simulator**, use
`ios/Configuration.storekit` for purchase/restore/expire without sandbox.)

**Android:** Play Console → Setup → **License testing** (add tester Google accounts)
+ a **Closed/Internal** track with that tester. **Open the track opt-in URL on the
device** (skipping this = products won't load — common miss). Be signed into **only**
the licensed tester account.

> Both require Step 11's paywall + `Purchases.configure()`. Before that, validate
> the dashboard wiring with RevenueCat's built-in **Test Store**.

---

# PART F — Production go-live checklist

- [ ] Apple Paid Apps Agreement **Active**; tax + banking **Clear**.
- [ ] Google payments profile active; **App content** all green; **closed-testing
      gate** satisfied (≥12 testers / 14 days, if a personal account post-2023-11-13).
- [ ] Both products **Ready to Submit** (iOS) / **Active** base plans (Android), with
      the 7-day trial.
- [ ] RevenueCat: all products **attached** to `premium`; **Default** offering
      returns Monthly + Annual with correct **TRY** prices (`getOfferings`).
- [ ] Release build uses the real **`appl_`/`goog_`** keys (not Test Store).
- [ ] **Step 11 shipped**: paywall renders the `default` offering; `premium` gate +
      ad removal work; **Restore Purchases** present (App Store-required).
- [ ] iOS: subscription disclosure text in the description + App Privacy done.
      Android: Data safety done. Privacy Policy / Terms URLs live (see
      `lib/core/constants/legal_links.dart` placeholders).
- [ ] Submit the first app version **with** the subscriptions attached; phased/staged
      rollout. Allow ~24h post-approval for products to propagate.

---

# Appendix — "products are empty" / common failures

- **Apple agreement not Active** (tax/banking not Clear) → zero iOS products. #1 cause.
- **iOS "Missing Metadata"** → add the **group-level** localization + review screenshot.
- **Android offering empty** → base plan not **Activated**, or RevenueCat product ID
  missing the `:basePlanId`, or the **~24–36h** service-account propagation isn't
  done, or the track **opt-in URL** wasn't opened on the device.
- **Wrong bundle ID per platform** → iOS `com.okeyacarmi.okeyAcarMi`, Android
  `com.okeyacarmi.okey_acar_mi`. Mixing them = "product not found" / app mismatch.
- **Purchases succeed but nothing unlocks** → products not **attached** to the
  `premium` entitlement (C6).
- **Paywall is empty** → the offering isn't marked **Default**.
- **Nothing happens in-app at all** → **Step 11 isn't built yet** (expected today).
- **Propagation patience**: Apple up to ~24h after agreement Active; Google up to
  ~36h after granting Play permissions. Don't assume a misconfig before then.

---

*Companion docs:* `HUMAN_SETUP.md` (full human checklist), `PRODUCT_SPEC.md`
(authoritative rules + paywall flow), `PROJECT_PLAN.md` → **Step 11** (the in-app
monetization code this runbook unblocks).
