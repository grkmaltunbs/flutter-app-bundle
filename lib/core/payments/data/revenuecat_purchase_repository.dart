import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/payments/data/purchase_mapper.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/entitlement.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_offering.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';
import 'package:okey_acar_mi/core/payments/domain/repositories/purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/purchase_failure.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Production [PurchaseRepository] over `purchases_flutter` (RevenueCat).
///
/// Assumes `Purchases.configure(...)` already ran in `bootstrap` (prod only).
/// Bridges RevenueCat's customer-info listener onto a broadcast stream of
/// [Entitlement]; maps every SDK result/error through [PurchaseMapper] so the
/// SDK never leaks past this layer. Holds the listener + a controller, so it is
/// disposed via [dispose].
@Environment('prod')
@LazySingleton(
  as: PurchaseRepository,
  dispose: disposeRevenueCatPurchaseRepository,
)
class RevenueCatPurchaseRepository implements PurchaseRepository {
  /// Creates a [RevenueCatPurchaseRepository] and starts mirroring RevenueCat's
  /// customer-info updates onto [entitlementStream].
  RevenueCatPurchaseRepository() {
    _listener = (info) =>
        _controller.add(PurchaseMapper.entitlementFromCustomerInfo(info));
    Purchases.addCustomerInfoUpdateListener(_listener);
  }

  late final CustomerInfoUpdateListener _listener;

  final StreamController<Entitlement> _controller =
      StreamController<Entitlement>.broadcast();

  @override
  Stream<Entitlement> get entitlementStream => _controller.stream;

  @override
  Future<Entitlement> currentEntitlement() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return PurchaseMapper.entitlementFromCustomerInfo(info);
    } on Object catch (error) {
      throw PurchaseMapper.failureFrom(error);
    }
  }

  @override
  Future<SubscriptionOffering> offerings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return PurchaseMapper.offeringFromOfferings(offerings);
    } on Object catch (error) {
      throw PurchaseMapper.failureFrom(error);
    }
  }

  @override
  Future<Entitlement> purchase(SubscriptionPackage package) async {
    try {
      final offerings = await Purchases.getOfferings();
      final current =
          offerings.current ??
          (offerings.all.isEmpty ? null : offerings.all.values.first);
      final rcPackage = _packageById(current, package.id);
      if (rcPackage == null) throw const PurchaseFailure.unknown();
      final result = await Purchases.purchase(
        PurchaseParams.package(rcPackage),
      );
      return PurchaseMapper.entitlementFromCustomerInfo(result.customerInfo);
    } on Object catch (error) {
      throw PurchaseMapper.failureFrom(error);
    }
  }

  @override
  Future<Entitlement> restore() async {
    final Entitlement entitlement;
    try {
      final info = await Purchases.restorePurchases();
      entitlement = PurchaseMapper.entitlementFromCustomerInfo(info);
    } on Object catch (error) {
      throw PurchaseMapper.failureFrom(error);
    }
    if (!entitlement.isPremium) {
      throw const PurchaseFailure.restoreNothing();
    }
    return entitlement;
  }

  Package? _packageById(Offering? offering, String id) {
    if (offering == null) return null;
    for (final package in offering.availablePackages) {
      if (package.identifier == id) return package;
    }
    return null;
  }

  /// Removes the customer-info listener and closes the stream controller.
  Future<void> dispose() async {
    Purchases.removeCustomerInfoUpdateListener(_listener);
    await _controller.close();
  }
}

/// Disposes the [RevenueCatPurchaseRepository] when the DI container resets.
///
/// A top-level adapter (not `@disposeMethod`) because the repository is
/// registered as [PurchaseRepository] (the generated callback is typed against
/// that interface).
Future<void> disposeRevenueCatPurchaseRepository(
  PurchaseRepository instance,
) => (instance as RevenueCatPurchaseRepository).dispose();
