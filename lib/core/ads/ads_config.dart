import 'dart:io' show Platform;

/// Compile-time AdMob ad-unit configuration.
///
/// Defaults to Google's **public test ad-unit ids** (safe to commit; they
/// always fill with test ads), overridden per platform at build time via
/// `--dart-define` (`ADMOB_IOS_BANNER`, `ADMOB_ANDROID_BANNER`,
/// `ADMOB_IOS_REWARDED`, `ADMOB_ANDROID_REWARDED`) from `dart_defines/prod.json`.
///
/// NOTE: the AdMob **App ID** is NOT here — it must live natively in
/// `ios/Runner/Info.plist` (`GADApplicationIdentifier`) and
/// `android/app/src/main/AndroidManifest.xml` (`com.google.android.gms.ads.APPLICATION_ID`).
/// That is a human setup step; this file never invents a real App ID.
abstract final class AdsConfig {
  const AdsConfig._();

  // Google's documented public test ad-unit ids.
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';

  static const String _bannerIosOverride = String.fromEnvironment(
    'ADMOB_IOS_BANNER',
  );
  static const String _bannerAndroidOverride = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER',
  );
  static const String _rewardedIosOverride = String.fromEnvironment(
    'ADMOB_IOS_REWARDED',
  );
  static const String _rewardedAndroidOverride = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED',
  );

  /// The banner ad-unit id for the current platform (override, else test id).
  static String get bannerUnitId => Platform.isAndroid
      ? (_bannerAndroidOverride.isEmpty
            ? _testBannerAndroid
            : _bannerAndroidOverride)
      : (_bannerIosOverride.isEmpty ? _testBannerIos : _bannerIosOverride);

  /// The rewarded ad-unit id for the current platform (override, else test id).
  static String get rewardedUnitId => Platform.isAndroid
      ? (_rewardedAndroidOverride.isEmpty
            ? _testRewardedAndroid
            : _rewardedAndroidOverride)
      : (_rewardedIosOverride.isEmpty
            ? _testRewardedIos
            : _rewardedIosOverride);
}
