import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/ads/ad_placement.dart';
import 'package:okey_acar_mi/core/ads/ads_service.dart';
import 'package:okey_acar_mi/core/ads/banner_ad_handle.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';

/// Restores the [FakeAdsService] to seeded defaults when the DI container
/// resets (`getIt.reset()`), so consecutive test configs never leak toggles.
void disposeFakeAdsService(AdsService instance) =>
    (instance as FakeAdsService).reset();

/// Demo [AdsService]: no native ads, deterministic rewarded outcomes.
///
/// [createBanner] returns a placeholder handle (no native object).
/// [showRewarded] grants the reward synchronously by default; the
/// [failNextRewarded] and [dismissNextWithoutReward] toggles drive the failure
/// / early-dismiss paths for integration tests. Zero native SDK calls.
@Environment('demo')
@LazySingleton(as: AdsService, dispose: disposeFakeAdsService)
class FakeAdsService implements AdsService {
  /// Creates a [FakeAdsService].
  FakeAdsService();

  /// When set, the next [showRewarded] calls `onFailed` (then auto-clears).
  bool failNextRewarded = false;

  /// When set, the next [showRewarded] dismisses without a reward
  /// (auto-clears).
  bool dismissNextWithoutReward = false;

  @override
  bool get isInitialized => true;

  @override
  BannerAdHandle createBanner(AdPlacement placement) =>
      const _FakeBannerHandle();

  @override
  Future<void> preloadRewarded() async {}

  @override
  Future<void> showRewarded({
    required void Function() onReward,
    required void Function() onDismissedWithoutReward,
    required void Function(Object error) onFailed,
  }) async {
    if (failNextRewarded) {
      failNextRewarded = false;
      onFailed(StateError('fake rewarded failure'));
      return;
    }
    if (dismissNextWithoutReward) {
      dismissNextWithoutReward = false;
      onDismissedWithoutReward();
      return;
    }
    onReward();
    onDismissedWithoutReward();
  }

  /// Restores seeded defaults (all toggles off).
  void reset() {
    failNextRewarded = false;
    dismissNextWithoutReward = false;
  }
}

/// Demo [BannerAdHandle]: renders a labeled placeholder, no native ad.
class _FakeBannerHandle implements BannerAdHandle {
  const _FakeBannerHandle();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 56,
      alignment: Alignment.center,
      color: colors.surfaceContainerHighest,
      child: Text(
        context.l10n.adPlaceholderLabel,
        style: context.textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  void dispose() {}
}
