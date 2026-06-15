import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/features/consent/data/fakes/fake_consent_service.dart';
import 'package:okey_acar_mi/features/consent/domain/entities/consent_status.dart';

void main() {
  late FakeConsentService service;

  setUp(() => service = FakeConsentService());

  group('FakeConsentService', () {
    test('granted by default: personalized ads allowed, status granted', () {
      check(service.personalizedAdsAllowed).isTrue();
      check(service.status).equals(ConsentStatus.granted);
    });

    test('ensureRequested no-ops but records that it was asked', () async {
      check(service.asked).isFalse();
      await service.ensureRequested();
      check(service.asked).isTrue();
      // Idempotent: a second call still leaves it asked, no throw.
      await service.ensureRequested();
      check(service.asked).isTrue();
    });

    test('declined flips to the non-personalized / denied path', () {
      service.declined = true;
      check(service.personalizedAdsAllowed).isFalse();
      check(service.status).equals(ConsentStatus.denied);
    });

    test('reset restores granted defaults and clears asked', () async {
      service
        ..declined = true
        ..asked = true
        ..reset();
      check(service.declined).isFalse();
      check(service.asked).isFalse();
      check(service.personalizedAdsAllowed).isTrue();
    });
  });
}
