import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/entitlement.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_offering.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';
import 'package:okey_acar_mi/core/payments/domain/repositories/purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/purchase_failure.dart';
import 'package:okey_acar_mi/core/time/clock.dart';

/// Which entitlement the [FakePurchaseRepository] seeds at startup.
enum FakePurchaseMode {
  /// Free user (default): no premium, paywall reachable.
  free,

  /// Active premium subscriber (ads removed, reasoning unlocked).
  premium,

  /// Lapsed subscriber whose entitlement has expired (back to free behavior,
  /// but with a past [Entitlement.expiresAt]).
  expired,
}

/// Restores the [FakePurchaseRepository] to seeded defaults and closes its
/// controller when the DI container resets (`getIt.reset()`).
///
/// A top-level adapter (not `@disposeMethod`) because the fake is registered
/// as [PurchaseRepository]; the generated dispose callback is typed against
/// that interface (mirrors `disposeFakeConnectivityService`).
void disposeFakePurchaseRepository(PurchaseRepository instance) =>
    (instance as FakePurchaseRepository).dispose();

/// Demo [PurchaseRepository]: in-memory, seeded, deterministic, offline.
///
/// Seeds a monthly + annual offering (both with a 7-day trial) and an
/// entitlement driven by [setMode]. [entitlementStream] replays the current
/// entitlement gap-free (Stream.multi), then every change. Public toggles let
/// integration tests exercise failure/edge paths with zero native SDK calls.
@Environment('demo')
@LazySingleton(as: PurchaseRepository, dispose: disposeFakePurchaseRepository)
class FakePurchaseRepository implements PurchaseRepository {
  /// Creates a [FakePurchaseRepository] (defaults to [FakePurchaseMode.free]).
  FakePurchaseRepository(this._clock);

  final Clock _clock;

  static const SubscriptionOffering _seededOffering = SubscriptionOffering(
    monthly: SubscriptionPackage(
      id: r'$rc_monthly',
      period: SubscriptionPeriod.monthly,
      priceString: '₺29,99/ay',
      hasTrial: true,
      trialDays: 7,
    ),
    annual: SubscriptionPackage(
      id: r'$rc_annual',
      period: SubscriptionPeriod.annual,
      priceString: '₺199,99/yıl',
      hasTrial: true,
      trialDays: 7,
    ),
  );

  FakePurchaseMode _mode = FakePurchaseMode.free;

  /// When set, the next [purchase] throws `paymentFailed` (then auto-clears).
  bool failNextPurchase = false;

  /// When set, the next [purchase] throws THIS exact [PurchaseFailure] (then
  /// auto-clears). Lets tests exercise the non-`paymentFailed` purchase
  /// branches (e.g. `cancelled`, `pending`) the simpler [failNextPurchase]
  /// toggle cannot reach.
  PurchaseFailure? failNextPurchaseWith;

  /// When set, [purchase]/[restore]/[offerings] throw `network`.
  bool offline = false;

  /// When set, [restore] throws `restoreNothing` instead of re-emitting.
  bool nothingToRestore = false;

  final StreamController<Entitlement> _controller =
      StreamController<Entitlement>.broadcast();

  Entitlement _entitlementFor(FakePurchaseMode mode) => switch (mode) {
    FakePurchaseMode.free => Entitlement.free,
    FakePurchaseMode.premium => Entitlement(
      isPremium: true,
      willRenew: true,
      expiresAt: _clock.now().add(const Duration(days: 30)),
    ),
    FakePurchaseMode.expired => Entitlement(
      isPremium: false,
      expiresAt: _clock.now().subtract(const Duration(days: 1)),
    ),
  };

  Entitlement get _current => _entitlementFor(_mode);

  @override
  Stream<Entitlement> get entitlementStream {
    // Gap-free replay: Stream.multi subscribes synchronously on listen, so an
    // emission landing in the microtask after the replay is never dropped
    // (mirrors FakeConnectivityService).
    return Stream<Entitlement>.multi((listener) {
      listener
        ..add(_current)
        ..addStream(_controller.stream).ignore();
    });
  }

  @override
  Future<Entitlement> currentEntitlement() async => _current;

  @override
  Future<SubscriptionOffering> offerings() async {
    if (offline) throw const PurchaseFailure.network();
    return _seededOffering;
  }

  @override
  Future<Entitlement> purchase(SubscriptionPackage package) async {
    if (offline) throw const PurchaseFailure.network();
    final injected = failNextPurchaseWith;
    if (injected != null) {
      failNextPurchaseWith = null;
      throw injected;
    }
    if (failNextPurchase) {
      failNextPurchase = false;
      throw const PurchaseFailure.paymentFailed('fake payment failure');
    }
    _mode = FakePurchaseMode.premium;
    final entitlement = _current;
    _controller.add(entitlement);
    return entitlement;
  }

  @override
  Future<Entitlement> restore() async {
    if (offline) throw const PurchaseFailure.network();
    if (nothingToRestore) throw const PurchaseFailure.restoreNothing();
    final entitlement = _current;
    _controller.add(entitlement);
    return entitlement;
  }

  /// Demo/integration-test hook: drives the seeded [mode] and re-emits.
  void setMode(FakePurchaseMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _controller.add(_current);
  }

  /// Restores seeded defaults (mode = free, all toggles off). Does NOT emit;
  /// called between test configurations so no toggle/entitlement leaks.
  void reset() {
    _mode = FakePurchaseMode.free;
    failNextPurchase = false;
    failNextPurchaseWith = null;
    offline = false;
    nothingToRestore = false;
  }

  /// Closes the change controller; called via [disposeFakePurchaseRepository]
  /// when the DI container resets.
  @visibleForTesting
  void dispose() {
    reset();
    unawaited(_controller.close());
  }
}
