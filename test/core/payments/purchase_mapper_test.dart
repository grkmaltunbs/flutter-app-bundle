import 'package:checks/checks.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/payments/data/purchase_mapper.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';
import 'package:okey_acar_mi/core/payments/purchase_failure.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// A bare `CustomerInfo` JSON with no active entitlements (free user).
Map<String, dynamic> _customerInfoJson({
  Map<String, dynamic> activeEntitlements = const {},
}) => {
  'originalAppUserId': 'demo',
  'entitlements': {
    'all': activeEntitlements,
    'active': activeEntitlements,
    'verification': 'NOT_REQUESTED',
  },
  'activeSubscriptions': <String>[],
  'latestExpirationDate': null,
  'allExpirationDates': <String, dynamic>{},
  'allPurchasedProductIdentifiers': <String>[],
  'firstSeen': '2026-01-01T00:00:00.000Z',
  'requestDate': '2026-01-01T00:00:00.000Z',
  'allPurchaseDates': <String, dynamic>{},
  'originalApplicationVersion': '1.0.0',
  'nonSubscriptionTransactions': <dynamic>[],
};

/// An active "premium" entitlement JSON, expiring in the future and renewing.
Map<String, dynamic> _premiumEntitlementJson() => {
  'premium': {
    'identifier': 'premium',
    'isActive': true,
    'willRenew': true,
    'latestPurchaseDate': '2026-06-01T00:00:00.000Z',
    'originalPurchaseDate': '2026-06-01T00:00:00.000Z',
    'productIdentifier': r'$rc_monthly',
    'isSandbox': true,
    'ownershipType': 'PURCHASED',
    'store': 'APP_STORE',
    'periodType': 'NORMAL',
    'expirationDate': '2026-07-01T00:00:00.000Z',
    'verification': 'NOT_REQUESTED',
  },
};

/// Builds a [StoreProduct] with an optional free [trialDays] intro period.
StoreProduct _product(
  String id,
  String priceString, {
  int trialDays = 0,
  PeriodUnit periodUnit = PeriodUnit.day,
}) => StoreProduct(
  id,
  'desc',
  'title',
  trialDays > 0 ? 29.99 : 29.99,
  priceString,
  'TRY',
  introductoryPrice: trialDays > 0
      ? IntroductoryPrice(
          0,
          'Free',
          'P${trialDays}D',
          1,
          periodUnit,
          trialDays,
        )
      : null,
);

Package _package(String id, PackageType type, StoreProduct product) => Package(
  id,
  type,
  product,
  const PresentedOfferingContext('default', null, null),
);

Offerings _offeringsWith({Package? monthly, Package? annual}) {
  final offering = Offering(
    'default',
    'desc',
    const {},
    [?monthly, ?annual],
    monthly: monthly,
    annual: annual,
  );
  return Offerings({'default': offering}, current: offering);
}

void main() {
  group('entitlementFromCustomerInfo', () {
    test('no active entitlement → free', () {
      final info = CustomerInfo.fromJson(_customerInfoJson());
      final entitlement = PurchaseMapper.entitlementFromCustomerInfo(info);
      check(entitlement.isPremium).isFalse();
      check(entitlement.expiresAt).isNull();
    });

    test('active premium entitlement → premium, renewing, parsed expiry', () {
      final info = CustomerInfo.fromJson(
        _customerInfoJson(activeEntitlements: _premiumEntitlementJson()),
      );
      final entitlement = PurchaseMapper.entitlementFromCustomerInfo(info);
      check(entitlement.isPremium).isTrue();
      check(entitlement.willRenew).isTrue();
      check(entitlement.expiresAt)
          .equals(DateTime.parse('2026-07-01T00:00:00.000Z'));
    });
  });

  group('offeringFromOfferings', () {
    test('empty offerings → both plans null', () {
      final offering =
          PurchaseMapper.offeringFromOfferings(const Offerings({}));
      check(offering.monthly).isNull();
      check(offering.annual).isNull();
    });

    test('maps monthly + annual price strings and the free-trial intro', () {
      final offerings = _offeringsWith(
        monthly: _package(
          r'$rc_monthly',
          PackageType.monthly,
          _product(r'$rc_monthly', '₺29,99', trialDays: 7),
        ),
        annual: _package(
          r'$rc_annual',
          PackageType.annual,
          _product(r'$rc_annual', '₺199,99'),
        ),
      );

      final result = PurchaseMapper.offeringFromOfferings(offerings);

      check(result.monthly).isNotNull();
      check(result.monthly!.period).equals(SubscriptionPeriod.monthly);
      check(result.monthly!.priceString).equals('₺29,99');
      check(result.monthly!.hasTrial).isTrue();
      check(result.monthly!.trialDays).equals(7);

      check(result.annual).isNotNull();
      check(result.annual!.period).equals(SubscriptionPeriod.annual);
      check(result.annual!.priceString).equals('₺199,99');
      check(result.annual!.hasTrial).isFalse();
      check(result.annual!.trialDays).equals(0);
    });
  });

  group('failureFrom', () {
    /// A [PlatformException] whose numeric code is RevenueCat error [code]'s
    /// index (the SDK's getErrorCode parses e.code as that index).
    PlatformException platformError(
      PurchasesErrorCode code, [
      String? message,
    ]) => PlatformException(code: code.index.toString(), message: message);

    test('a PurchaseFailure passes through unchanged', () {
      const failure = PurchaseFailure.restoreNothing();
      check(PurchaseMapper.failureFrom(failure))
          .equals(const PurchaseFailure.restoreNothing());
    });

    test('a non-PlatformException error → unknown', () {
      check(PurchaseMapper.failureFrom(StateError('boom')))
          .equals(const PurchaseFailure.unknown());
    });

    test('cancelled error → cancelled', () {
      check(
        PurchaseMapper.failureFrom(
          platformError(PurchasesErrorCode.purchaseCancelledError),
        ),
      ).equals(const PurchaseFailure.cancelled());
    });

    test('network error → network', () {
      check(
        PurchaseMapper.failureFrom(
          platformError(PurchasesErrorCode.networkError),
        ),
      ).equals(const PurchaseFailure.network());
    });

    test('offline connection error → network', () {
      check(
        PurchaseMapper.failureFrom(
          platformError(PurchasesErrorCode.offlineConnectionError),
        ),
      ).equals(const PurchaseFailure.network());
    });

    test('payment pending error → pending', () {
      check(
        PurchaseMapper.failureFrom(
          platformError(PurchasesErrorCode.paymentPendingError),
        ),
      ).equals(const PurchaseFailure.pending());
    });

    test('store problem error → paymentFailed (carries the message)', () {
      final failure = PurchaseMapper.failureFrom(
        platformError(PurchasesErrorCode.storeProblemError, 'store down'),
      );
      check(failure).isA<PurchasePaymentFailed>()
          .has((f) => f.message, 'message')
          .equals('store down');
    });

    test('an unmapped RevenueCat code → unknown', () {
      check(
        PurchaseMapper.failureFrom(
          platformError(PurchasesErrorCode.configurationError),
        ),
      ).equals(const PurchaseFailure.unknown());
    });
  });
}
