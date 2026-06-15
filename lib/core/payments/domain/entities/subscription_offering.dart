import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';

part 'subscription_offering.freezed.dart';

/// The set of plans the paywall renders, normalized from the active offering.
///
/// Either plan may be absent if the store does not return it. Pure Dart —
/// the data layer builds this from a RevenueCat `Offerings.current`.
@freezed
abstract class SubscriptionOffering with _$SubscriptionOffering {
  /// Creates a [SubscriptionOffering].
  const factory SubscriptionOffering({
    SubscriptionPackage? monthly,
    SubscriptionPackage? annual,
  }) = _SubscriptionOffering;
}
