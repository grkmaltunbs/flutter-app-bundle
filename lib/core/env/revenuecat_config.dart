import 'dart:io' show Platform;

/// Compile-time, non-secret configuration for the RevenueCat integration.
///
/// Mirrors `gemini_config.dart`: tunable knobs as `const`s. The only runtime
/// pieces are the **public** SDK API keys, injected per platform via
/// `--dart-define` (`REVENUECAT_IOS_KEY` / `REVENUECAT_ANDROID_KEY`) so no key
/// literal lives in git. These are public RevenueCat SDK keys — never the
/// secret server key.
abstract final class RevenueCatConfig {
  const RevenueCatConfig._();

  /// The RevenueCat entitlement identifier that grants premium (ad removal +
  /// unlocked reasoning). Must match the entitlement configured in RevenueCat.
  static const String premiumEntitlementId = 'premium';

  /// The offering identifier the paywall reads (RevenueCat "default" offering).
  static const String offeringId = 'default';

  /// The package identifier of the monthly plan within the offering.
  static const String monthlyPackageId = r'$rc_monthly';

  /// The package identifier of the annual plan within the offering.
  static const String annualPackageId = r'$rc_annual';

  static const String _iosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');

  static const String _androidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
  );

  /// The public RevenueCat SDK key for the current platform.
  ///
  /// Resolves the iOS key on iOS/macOS and the Android key on Android. Empty
  /// when unset — `Purchases.configure` is only ever called in the prod
  /// flavor, where the build supplies the key via `--dart-define-from-file`.
  static String get apiKey => Platform.isAndroid ? _androidKey : _iosKey;
}
