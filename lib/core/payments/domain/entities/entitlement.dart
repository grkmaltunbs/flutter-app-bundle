import 'package:freezed_annotation/freezed_annotation.dart';

part 'entitlement.freezed.dart';

/// The user's premium-entitlement snapshot.
///
/// Pure Dart (no SDK types): repository impls map RevenueCat's `CustomerInfo`
/// into this so the domain and presentation layers never see infra types.
/// [isPremium] is the single source of truth for ad-removal / unlocked
/// reasoning; [expiresAt]/[willRenew] drive the settings copy.
@freezed
abstract class Entitlement with _$Entitlement {
  /// Creates an [Entitlement].
  const factory Entitlement({
    required bool isPremium,
    DateTime? expiresAt,
    @Default(false) bool willRenew,
  }) = _Entitlement;

  const Entitlement._();

  /// The default, un-entitled state (free user, no expiry).
  static const Entitlement free = _Entitlement(isPremium: false);
}
