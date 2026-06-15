import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription_package.freezed.dart';

/// The billing cadence of a [SubscriptionPackage].
enum SubscriptionPeriod {
  /// Billed every month.
  monthly,

  /// Billed once per year.
  annual,
}

/// A purchasable subscription plan, normalized from the store.
///
/// Pure Dart: the data layer maps a RevenueCat `Package`/`StoreProduct` into
/// this. [priceString] is the localized, store-formatted price (e.g. `₺29,99`)
/// and is rendered as-is; the paywall never formats currency itself.
@freezed
abstract class SubscriptionPackage with _$SubscriptionPackage {
  /// Creates a [SubscriptionPackage].
  const factory SubscriptionPackage({
    required String id,
    required SubscriptionPeriod period,
    required String priceString,
    @Default(false) bool hasTrial,
    @Default(0) int trialDays,
  }) = _SubscriptionPackage;
}
