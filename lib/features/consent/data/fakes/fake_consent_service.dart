import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/consent/domain/entities/consent_status.dart';
import 'package:okey_acar_mi/features/consent/domain/repositories/consent_service.dart';

/// Restores the [FakeConsentService] to seeded defaults when the DI container
/// resets (`getIt.reset()`), so consecutive test configs never leak toggles.
void disposeFakeConsentService(ConsentService instance) =>
    (instance as FakeConsentService).reset();

/// Demo [ConsentService]: grants consent with **zero native prompts**.
///
/// [ensureRequested] just records that it was asked. Default is fully granted;
/// the [declined] toggle flips personalized ads + analytics off so the
/// non-personalized path is testable on a simulator.
@Environment('demo')
@LazySingleton(as: ConsentService, dispose: disposeFakeConsentService)
class FakeConsentService implements ConsentService {
  /// Creates a [FakeConsentService] (granted by default).
  FakeConsentService();

  /// Whether the user declined consent. Drives [status] / [personalizedAdsAllowed].
  bool declined = false;

  /// Whether [ensureRequested] has been called (test seam).
  bool asked = false;

  @override
  Future<void> ensureRequested() async {
    asked = true;
  }

  @override
  ConsentStatus get status =>
      declined ? ConsentStatus.denied : ConsentStatus.granted;

  @override
  bool get personalizedAdsAllowed => !declined;

  /// Restores seeded defaults (granted, not asked).
  void reset() {
    declined = false;
    asked = false;
  }
}
