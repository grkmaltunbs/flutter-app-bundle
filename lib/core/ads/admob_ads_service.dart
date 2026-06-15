import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/ads/ad_placement.dart';
import 'package:okey_acar_mi/core/ads/ads_config.dart';
import 'package:okey_acar_mi/core/ads/ads_service.dart';
import 'package:okey_acar_mi/core/ads/banner_ad_handle.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/consent/domain/repositories/consent_service.dart';

/// Production [AdsService] over `google_mobile_ads` (AdMob).
///
/// Assumes `MobileAds.instance.initialize()` already ran in `bootstrap` (prod
/// only). Lazy-loads a single rewarded ad on demand; banners are fixed-size and
/// returned as a [BannerAdHandle] the widget owns. Reads the non-personalized
/// flag from [ConsentService] for every ad request.
@Environment('prod')
@LazySingleton(as: AdsService)
class AdMobAdsService implements AdsService {
  /// Creates an [AdMobAdsService].
  AdMobAdsService(this._consent, this._logger);

  final ConsentService _consent;
  final AppLogger _logger;

  RewardedAd? _rewarded;

  @override
  // MobileAds.instance.initialize() runs in bootstrap before this service is
  // ever resolved, so by construction the SDK is ready.
  bool get isInitialized => true;

  AdRequest get _request =>
      AdRequest(nonPersonalizedAds: !_consent.personalizedAdsAllowed);

  @override
  BannerAdHandle createBanner(AdPlacement placement) {
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdsConfig.bannerUnitId,
      request: _request,
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          _logger.error('Banner failed to load ($placement): $error');
          unawaited(ad.dispose());
        },
      ),
    );
    unawaited(ad.load());
    return _AdMobBannerHandle(ad);
  }

  @override
  Future<void> preloadRewarded() async {
    if (_rewarded != null) return;
    await _loadRewarded();
  }

  Future<void> _loadRewarded() async {
    final completer = Completer<void>();
    await RewardedAd.load(
      adUnitId: AdsConfig.rewardedUnitId,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          _rewarded = null;
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      ),
    );
    return completer.future;
  }

  @override
  Future<void> showRewarded({
    required void Function() onReward,
    required void Function() onDismissedWithoutReward,
    required void Function(Object error) onFailed,
  }) async {
    try {
      if (_rewarded == null) await _loadRewarded();
    } on Object catch (error) {
      onFailed(error);
      return;
    }
    final ad = _rewarded;
    if (ad == null) {
      onFailed(StateError('Rewarded ad unavailable'));
      return;
    }
    _rewarded = null;

    var rewarded = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (!rewarded) onDismissedWithoutReward();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        unawaited(ad.dispose());
        onFailed(error);
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
        onReward();
      },
    );
  }
}

/// Prod [BannerAdHandle] wrapping a real [BannerAd] + its [AdWidget].
class _AdMobBannerHandle implements BannerAdHandle {
  _AdMobBannerHandle(this._ad);

  final BannerAd _ad;
  bool _disposed = false;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _ad.size.width.toDouble(),
    height: _ad.size.height.toDouble(),
    child: AdWidget(ad: _ad),
  );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_ad.dispose());
  }
}
