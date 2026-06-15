part of 'subscription_bloc.dart';

/// The transient flow state layered over the persistent [Entitlement].
///
/// Separates "what the user owns" ([SubscriptionState.entitlement], persistent)
/// from "what the paywall is doing right now" (this, transient) so a purchase
/// in flight never clobbers the entitlement and vice versa.
@freezed
sealed class SubscriptionFlow with _$SubscriptionFlow {
  /// No purchase/restore/offering operation in flight.
  const factory SubscriptionFlow.idle() = SubscriptionFlowIdle;

  /// Loading the offering for the paywall.
  const factory SubscriptionFlow.offeringsLoading() =
      SubscriptionFlowOfferingsLoading;

  /// A purchase is in flight.
  const factory SubscriptionFlow.purchasing() = SubscriptionFlowPurchasing;

  /// A restore is in flight.
  const factory SubscriptionFlow.restoring() = SubscriptionFlowRestoring;

  /// The most recent purchase succeeded (transient — drives a success
  /// listener).
  const factory SubscriptionFlow.purchaseSucceeded() =
      SubscriptionFlowPurchaseSucceeded;

  /// The most recent restore succeeded (transient).
  const factory SubscriptionFlow.restoreSucceeded() =
      SubscriptionFlowRestoreSucceeded;

  /// The last operation could not reach the store (offline).
  const factory SubscriptionFlow.offline() = SubscriptionFlowOffline;

  /// The last operation failed with [failure].
  const factory SubscriptionFlow.error(PurchaseFailure failure) =
      SubscriptionFlowError;
}

/// App-scoped subscription state: the owned [entitlement], the loaded
/// [offering] (if any), and the current [flow].
@freezed
abstract class SubscriptionState with _$SubscriptionState {
  /// Creates a [SubscriptionState].
  const factory SubscriptionState({
    required Entitlement entitlement,
    SubscriptionOffering? offering,
    @Default(SubscriptionFlow.idle()) SubscriptionFlow flow,
  }) = _SubscriptionState;

  const SubscriptionState._();

  /// Whether premium is currently active (drives ad removal + unlocks).
  bool get isPremium => entitlement.isPremium;
}
