import 'package:freezed_annotation/freezed_annotation.dart';

part 'purchase_failure.freezed.dart';

/// A sealed, typed purchase/restore error.
///
/// Repository impls map RevenueCat error codes (and SDK exceptions) into one of
/// these so the `SubscriptionBloc` and paywall never see infra types. Methods
/// on `PurchaseRepository` THROW these (mirrors the throw-based `Failure`
/// contract). Pure Dart — no `purchases_flutter` import.
@freezed
sealed class PurchaseFailure with _$PurchaseFailure implements Exception {
  /// The user dismissed the purchase sheet. Not an error to surface — the
  /// bloc returns to idle silently.
  const factory PurchaseFailure.cancelled() = PurchaseCancelled;

  /// A connectivity/transport failure reaching the store or RevenueCat.
  const factory PurchaseFailure.network() = PurchaseNetwork;

  /// The purchase is pending external approval (e.g. Ask to Buy, SCA).
  const factory PurchaseFailure.pending() = PurchasePending;

  /// The store declined or could not complete the payment; [message] carries
  /// the diagnostic code when available.
  const factory PurchaseFailure.paymentFailed([String? message]) =
      PurchasePaymentFailed;

  /// A restore completed but found no prior purchases to restore.
  const factory PurchaseFailure.restoreNothing() = PurchaseRestoreNothing;

  /// An unexpected, unclassified failure.
  const factory PurchaseFailure.unknown() = PurchaseUnknown;
}
