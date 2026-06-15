import 'package:freezed_annotation/freezed_annotation.dart';

part 'consent_status.freezed.dart';

/// The iOS App Tracking Transparency authorization state.
///
/// [unavailable] folds restricted/not-supported (e.g. the simulator) into a
/// single "we can't track, treat as denied" case.
enum AttStatus {
  /// The user granted tracking authorization.
  authorized,

  /// The user denied tracking authorization.
  denied,

  /// The system has not yet asked.
  notDetermined,

  /// ATT is unavailable on this device (restricted / simulator / Android).
  unavailable,
}

/// The resolved consent snapshot used to gate personalized ads + analytics.
///
/// Pure Dart. [personalizedAds] drives the AdMob non-personalized flag;
/// [analytics] gates analytics collection; [att] records the iOS ATT outcome.
@freezed
abstract class ConsentStatus with _$ConsentStatus {
  /// Creates a [ConsentStatus].
  const factory ConsentStatus({
    required bool personalizedAds,
    required bool analytics,
    required AttStatus att,
  }) = _ConsentStatus;

  const ConsentStatus._();

  /// Full consent (personalized ads + analytics allowed, ATT authorized).
  static const ConsentStatus granted = _ConsentStatus(
    personalizedAds: true,
    analytics: true,
    att: AttStatus.authorized,
  );

  /// No consent (non-personalized ads only, analytics off, ATT denied).
  static const ConsentStatus denied = _ConsentStatus(
    personalizedAds: false,
    analytics: false,
    att: AttStatus.denied,
  );
}
