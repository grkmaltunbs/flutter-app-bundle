import 'package:okey_acar_mi/core/ads/ad_placement.dart';
import 'package:okey_acar_mi/core/ads/banner_ad_handle.dart';

/// The seam over the ads SDK (AdMob in prod, a fake in demo).
///
/// Flutter-light: returns a [BannerAdHandle] (not a widget) for banners and
/// drives rewarded ads through callbacks, so feature widgets never touch the
/// SDK. Gating (hide ads for premium) is enforced by the caller via
/// `SubscriptionBloc` — this service is unaware of entitlement.
abstract class AdsService {
  /// Whether the underlying SDK has finished initializing (always true in the
  /// demo fake).
  bool get isInitialized;

  /// Creates a banner for [placement]. The caller owns the returned handle and
  /// MUST dispose it when the hosting widget unmounts.
  BannerAdHandle createBanner(AdPlacement placement);

  /// Pre-loads a rewarded ad so a later [showRewarded] is instant. No-op in
  /// the demo fake.
  Future<void> preloadRewarded();

  /// Shows a rewarded ad.
  ///
  /// Exactly one terminal callback fires: [onReward] (then the ad dismisses)
  /// when the reward is earned, [onDismissedWithoutReward] when the user closes
  /// the ad early, or [onFailed] when the ad cannot load/show.
  Future<void> showRewarded({
    required void Function() onReward,
    required void Function() onDismissedWithoutReward,
    required void Function(Object error) onFailed,
  });
}
