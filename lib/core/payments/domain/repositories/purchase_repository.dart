import 'package:okey_acar_mi/core/payments/domain/entities/entitlement.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_offering.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';
import 'package:okey_acar_mi/core/payments/purchase_failure.dart';

/// The seam over the purchase backend (RevenueCat in prod, a fake in demo).
///
/// All methods THROW a [PurchaseFailure] on failure (never return error codes).
/// Pure Dart — no `purchases_flutter` import — so the domain stays infra-free.
abstract class PurchaseRepository {
  /// Emits the current [Entitlement] on subscribe, then on every change
  /// (store renewal, restore, expiry). Gap-free: replays the current value to
  /// each new listener.
  Stream<Entitlement> get entitlementStream;

  /// Resolves the current [Entitlement] once.
  Future<Entitlement> currentEntitlement();

  /// Fetches the active [SubscriptionOffering] (the plans to render).
  ///
  /// Throws [PurchaseFailure] (e.g. `network`) on failure.
  Future<SubscriptionOffering> offerings();

  /// Purchases [package] and returns the resulting [Entitlement].
  ///
  /// Throws [PurchaseFailure] — `cancelled` when the user dismisses the sheet,
  /// `network`/`pending`/`paymentFailed`/`unknown` otherwise.
  Future<Entitlement> purchase(SubscriptionPackage package);

  /// Restores prior purchases and returns the resulting [Entitlement].
  ///
  /// Throws [PurchaseFailure.restoreNothing] when nothing is restorable, or
  /// `network` when offline.
  Future<Entitlement> restore();
}
