/// Where in the app a banner/rewarded ad is shown.
///
/// Lets the `AdsService` (and AdMob, later) attribute revenue per surface
/// without the widget passing raw ad-unit ids around.
enum AdPlacement {
  /// The result screen (verdict + arrangement) — bottom anchored banner.
  result,

  /// The history list — bottom anchored banner.
  history,
}
