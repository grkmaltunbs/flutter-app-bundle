# dart_defines

Build-time configuration passed to the app via `--dart-define-from-file`, so
secrets (RevenueCat public SDK keys, later AdMob unit IDs) stay out of git.

## Files
- `prod.example.json` — tracked template (placeholders only).
- `prod.json` — your real prod values. **Gitignored — never committed.**

## Setup
```bash
cp dart_defines/prod.example.json dart_defines/prod.json
# then paste your real RevenueCat keys into dart_defines/prod.json
```

## Run / build with it
```bash
flutter run            --dart-define-from-file=dart_defines/prod.json -d <device>
flutter build ipa      --dart-define-from-file=dart_defines/prod.json
flutter build appbundle --dart-define-from-file=dart_defines/prod.json
```
The demo flavor needs no secrets: `flutter run --dart-define=APP_ENV=demo -d <device>`.

## Keys
| Key | Where it comes from | Notes |
|-----|---------------------|-------|
| `APP_ENV` | `demo` or `prod` | selects fakes vs. real backends |
| `REVENUECAT_IOS_KEY` | RevenueCat → Project settings → API keys → iOS app (`appl_…`) | **public** SDK key — never the secret key |
| `REVENUECAT_ANDROID_KEY` | RevenueCat → Project settings → API keys → Android app (`goog_…`) | **public** SDK key |
| `ADMOB_IOS_BANNER` | AdMob → iOS app → banner ad unit (`ca-app-pub-…/…`) | optional; empty ⇒ Google test unit |
| `ADMOB_ANDROID_BANNER` | AdMob → Android app → banner ad unit | optional; empty ⇒ Google test unit |
| `ADMOB_IOS_REWARDED` | AdMob → iOS app → rewarded ad unit | optional; empty ⇒ Google test unit |
| `ADMOB_ANDROID_REWARDED` | AdMob → Android app → rewarded ad unit | optional; empty ⇒ Google test unit |

> These keys are consumed once **Step 11 (Monetization)** wires `Purchases.configure(...)`.
> AdMob ad-unit IDs get added here too when Step 11 defines their `--dart-define` names.
> In CI, write `prod.json` from a secret (or pass the same values as individual
> `--dart-define` flags) — do not commit real keys.
