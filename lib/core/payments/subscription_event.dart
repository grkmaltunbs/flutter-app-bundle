part of 'subscription_bloc.dart';

/// Intent events for [SubscriptionBloc] (past-tense, no `BuildContext`).
@freezed
sealed class SubscriptionEvent with _$SubscriptionEvent {
  /// App start: resolve the current entitlement, then follow the stream.
  const factory SubscriptionEvent.started() = SubscriptionStarted;

  /// Re-read the current entitlement (e.g. on app resume).
  const factory SubscriptionEvent.refreshRequested() =
      SubscriptionRefreshRequested;

  /// The paywall asked to load the offering.
  const factory SubscriptionEvent.offeringsRequested() =
      SubscriptionOfferingsRequested;

  /// The user tapped subscribe on [package].
  const factory SubscriptionEvent.purchaseRequested(
    SubscriptionPackage package,
  ) = SubscriptionPurchaseRequested;

  /// The user tapped restore purchases.
  const factory SubscriptionEvent.restoreRequested() =
      SubscriptionRestoreRequested;

  /// Internal: the repository's entitlement stream emitted [entitlement].
  const factory SubscriptionEvent.entitlementChanged(Entitlement entitlement) =
      SubscriptionEntitlementChanged;
}
