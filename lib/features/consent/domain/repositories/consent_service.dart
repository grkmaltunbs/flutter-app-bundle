import 'package:okey_acar_mi/features/consent/domain/entities/consent_status.dart';

/// The seam over consent collection (UMP + ATT in prod, a fake in demo).
///
/// Pure Dart — no SDK imports. The prod impl talks to AdMob's UMP and (iOS)
/// App Tracking Transparency; the demo fake grants consent without any native
/// prompt so simulator runs stay deterministic.
abstract class ConsentService {
  /// Requests consent once (UMP form + iOS ATT). Idempotent — safe to call on
  /// every launch; subsequent calls are no-ops once asked.
  Future<void> ensureRequested();

  /// The resolved consent snapshot (defaults before [ensureRequested] runs).
  ConsentStatus get status;

  /// Whether personalized ads are allowed (the AdMob request flag).
  bool get personalizedAdsAllowed;
}
