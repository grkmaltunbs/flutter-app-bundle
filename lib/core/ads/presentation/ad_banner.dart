import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/ads/ad_placement.dart';
import 'package:okey_acar_mi/core/ads/ads_service.dart';
import 'package:okey_acar_mi/core/ads/banner_ad_handle.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';

/// A bottom-anchored banner ad for [placement].
///
/// Hidden entirely for premium users (entitlement read via [SubscriptionBloc],
/// never the purchase SDK). For free users it creates one banner handle for the
/// widget's lifetime (disposed on unmount) and renders it in a fixed-height
/// container so it can never overflow. The demo flavor renders a labeled
/// placeholder via the fake handle.
class AdBanner extends StatelessWidget {
  /// Creates an [AdBanner] for [placement].
  const AdBanner({required this.placement, super.key});

  /// Where this banner is shown (drives ad attribution).
  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SubscriptionBloc, SubscriptionState, bool>(
      selector: (state) => state.isPremium,
      builder: (context, isPremium) =>
          isPremium ? const SizedBox.shrink() : _AdBannerBody(placement),
    );
  }
}

/// The non-premium banner body. Stateful so the [BannerAdHandle] is created
/// once and disposed on unmount.
class _AdBannerBody extends StatefulWidget {
  const _AdBannerBody(this.placement);

  final AdPlacement placement;

  @override
  State<_AdBannerBody> createState() => _AdBannerBodyState();
}

class _AdBannerBodyState extends State<_AdBannerBody> {
  BannerAdHandle? _handle;

  @override
  void initState() {
    super.initState();
    // Created once; survives rebuilds. Wrapped so a misconfigured prod SDK can
    // never throw during build.
    try {
      _handle = getIt<AdsService>().createBanner(widget.placement);
    } on Object {
      _handle = null;
    }
  }

  @override
  void dispose() {
    _handle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    if (handle == null) return const SizedBox.shrink();
    // Fixed height keeps the banner overflow-proof regardless of the ad's
    // reported size.
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Center(child: handle.build(context)),
    );
  }
}
