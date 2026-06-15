import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/payments/data/fakes/fake_purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';
import 'package:okey_acar_mi/core/payments/purchase_failure.dart';
import 'package:okey_acar_mi/core/time/clock.dart';

const _monthly = SubscriptionPackage(
  id: r'$rc_monthly',
  period: SubscriptionPeriod.monthly,
  priceString: '₺29,99/ay',
  hasTrial: true,
  trialDays: 7,
);

void main() {
  late FakePurchaseRepository repository;

  setUp(() => repository = FakePurchaseRepository(const FakeClock()));
  tearDown(() => repository.dispose());

  group('FakePurchaseRepository seeding', () {
    test('free by default: not premium, no expiry', () async {
      final entitlement = await repository.currentEntitlement();
      check(entitlement.isPremium).isFalse();
      check(entitlement.expiresAt).isNull();
    });

    test('premium mode: premium, renewing, future expiry', () async {
      repository.setMode(FakePurchaseMode.premium);
      final entitlement = await repository.currentEntitlement();
      check(entitlement.isPremium).isTrue();
      check(entitlement.willRenew).isTrue();
      check(entitlement.expiresAt).isNotNull();
      check(entitlement.expiresAt!.isAfter(FakeClock.seed)).isTrue();
    });

    test('expired mode: not premium, past expiry', () async {
      repository.setMode(FakePurchaseMode.expired);
      final entitlement = await repository.currentEntitlement();
      check(entitlement.isPremium).isFalse();
      check(entitlement.expiresAt).isNotNull();
      check(entitlement.expiresAt!.isBefore(FakeClock.seed)).isTrue();
    });

    test('seeds the monthly + annual offering, both with a 7-day trial',
        () async {
      final offering = await repository.offerings();
      check(offering.monthly).isNotNull();
      check(offering.annual).isNotNull();
      check(offering.monthly!.hasTrial).isTrue();
      check(offering.monthly!.trialDays).equals(7);
      check(offering.annual!.hasTrial).isTrue();
      check(offering.annual!.trialDays).equals(7);
    });
  });

  group('entitlementStream', () {
    test('replays the current entitlement to a new listener', () async {
      final events = <bool>[];
      final sub = repository.entitlementStream.listen(
        (e) => events.add(e.isPremium),
      );
      await pumpEventQueue();
      check(events).deepEquals([false]);
      await sub.cancel();
    });

    test('setMode(premium) re-emits premium on the live stream', () async {
      final events = <bool>[];
      final sub = repository.entitlementStream.listen(
        (e) => events.add(e.isPremium),
      );
      await pumpEventQueue();

      repository.setMode(FakePurchaseMode.premium);
      await pumpEventQueue();

      check(events).deepEquals([false, true]);
      await sub.cancel();
    });

    test('setMode with the unchanged mode does not re-emit', () async {
      final events = <bool>[];
      final sub = repository.entitlementStream.listen(
        (e) => events.add(e.isPremium),
      );
      await pumpEventQueue();

      repository.setMode(FakePurchaseMode.free);
      await pumpEventQueue();

      check(events).deepEquals([false]);
      await sub.cancel();
    });
  });

  group('purchase', () {
    test('flips the repo to premium and returns premium', () async {
      final entitlement = await repository.purchase(_monthly);
      check(entitlement.isPremium).isTrue();
      check((await repository.currentEntitlement()).isPremium).isTrue();
    });

    test('offline throws network', () async {
      repository.offline = true;
      await check(repository.purchase(_monthly))
          .throws<PurchaseNetwork>();
    });

    test('failNextPurchase throws paymentFailed once, then succeeds',
        () async {
      repository.failNextPurchase = true;
      await check(repository.purchase(_monthly))
          .throws<PurchasePaymentFailed>();
      // Auto-cleared: the next purchase succeeds.
      check((await repository.purchase(_monthly)).isPremium).isTrue();
    });

    test('failNextPurchaseWith throws the injected failure once', () async {
      repository.failNextPurchaseWith = const PurchaseFailure.cancelled();
      await check(repository.purchase(_monthly))
          .throws<PurchaseCancelled>();
      // Auto-cleared.
      check((await repository.purchase(_monthly)).isPremium).isTrue();
    });
  });

  group('restore', () {
    test('re-emits the current entitlement', () async {
      repository.setMode(FakePurchaseMode.premium);
      final entitlement = await repository.restore();
      check(entitlement.isPremium).isTrue();
    });

    test('offline throws network', () async {
      repository.offline = true;
      await check(repository.restore()).throws<PurchaseNetwork>();
    });

    test('nothingToRestore throws restoreNothing', () async {
      repository.nothingToRestore = true;
      await check(repository.restore())
          .throws<PurchaseRestoreNothing>();
    });
  });

  group('reset', () {
    test('restores free mode and clears every toggle', () async {
      repository
        ..setMode(FakePurchaseMode.premium)
        ..failNextPurchase = true
        ..failNextPurchaseWith = const PurchaseFailure.pending()
        ..offline = true
        ..nothingToRestore = true
        ..reset();

      check((await repository.currentEntitlement()).isPremium).isFalse();
      check(repository.failNextPurchase).isFalse();
      check(repository.failNextPurchaseWith).isNull();
      check(repository.offline).isFalse();
      check(repository.nothingToRestore).isFalse();
    });
  });
}
