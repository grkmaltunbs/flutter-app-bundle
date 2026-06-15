import 'package:flutter/services.dart' show PlatformException;
import 'package:okey_acar_mi/core/env/revenuecat_config.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/entitlement.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_offering.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';
import 'package:okey_acar_mi/core/payments/purchase_failure.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Pure mapping helpers from `purchases_flutter` types to domain types.
///
/// Prod-only: this is the single file allowed to import `purchases_flutter`
/// alongside the repository impl, so the SDK never leaks past the data layer.
abstract final class PurchaseMapper {
  const PurchaseMapper._();

  /// Maps a RevenueCat [CustomerInfo] to an [Entitlement].
  ///
  /// Premium iff the configured entitlement id is in `entitlements.active`.
  static Entitlement entitlementFromCustomerInfo(CustomerInfo info) {
    final active =
        info.entitlements.active[RevenueCatConfig.premiumEntitlementId];
    if (active == null) {
      return Entitlement.free;
    }
    return Entitlement(
      isPremium: true,
      willRenew: active.willRenew,
      expiresAt: _parseDate(active.expirationDate),
    );
  }

  /// Maps a RevenueCat [Offerings] to a [SubscriptionOffering].
  ///
  /// Reads the current offering's monthly/annual packages and normalizes each
  /// into a [SubscriptionPackage].
  static SubscriptionOffering offeringFromOfferings(Offerings offerings) {
    final current =
        offerings.current ?? offerings.all[RevenueCatConfig.offeringId];
    if (current == null) return const SubscriptionOffering();
    return SubscriptionOffering(
      monthly: _packageFrom(current.monthly, SubscriptionPeriod.monthly),
      annual: _packageFrom(current.annual, SubscriptionPeriod.annual),
    );
  }

  static SubscriptionPackage? _packageFrom(
    Package? package,
    SubscriptionPeriod period,
  ) {
    if (package == null) return null;
    final intro = package.storeProduct.introductoryPrice;
    final hasTrial = intro != null && intro.price == 0;
    return SubscriptionPackage(
      id: package.identifier,
      period: period,
      priceString: package.storeProduct.priceString,
      hasTrial: hasTrial,
      trialDays: hasTrial ? _trialDays(intro) : 0,
    );
  }

  static int _trialDays(IntroductoryPrice intro) {
    final units = intro.periodNumberOfUnits * intro.cycles;
    return switch (intro.periodUnit) {
      PeriodUnit.day => units,
      PeriodUnit.week => units * 7,
      PeriodUnit.month => units * 30,
      PeriodUnit.year => units * 365,
      PeriodUnit.unknown => units,
    };
  }

  static DateTime? _parseDate(String? raw) =>
      raw == null ? null : DateTime.tryParse(raw);

  /// Maps an arbitrary SDK error (typically a [PlatformException]) to a
  /// typed [PurchaseFailure].
  static PurchaseFailure failureFrom(Object error) {
    if (error is PurchaseFailure) return error;
    if (error is! PlatformException) return const PurchaseFailure.unknown();
    final code = PurchasesErrorHelper.getErrorCode(error);
    return switch (code) {
      PurchasesErrorCode.purchaseCancelledError =>
        const PurchaseFailure.cancelled(),
      PurchasesErrorCode.networkError ||
      PurchasesErrorCode.offlineConnectionError =>
        const PurchaseFailure.network(),
      PurchasesErrorCode.paymentPendingError => const PurchaseFailure.pending(),
      PurchasesErrorCode.storeProblemError ||
      PurchasesErrorCode.purchaseNotAllowedError ||
      PurchasesErrorCode.purchaseInvalidError ||
      PurchasesErrorCode.productNotAvailableForPurchaseError =>
        PurchaseFailure.paymentFailed(error.message),
      _ => const PurchaseFailure.unknown(),
    };
  }
}
