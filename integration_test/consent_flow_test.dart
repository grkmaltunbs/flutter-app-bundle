import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/features/consent/data/fakes/fake_consent_service.dart';
import 'package:okey_acar_mi/features/consent/domain/repositories/consent_service.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';

FakeConsentService fakeConsent() =>
    getIt<ConsentService>() as FakeConsentService;

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> goHomeAsGuest(WidgetTester tester) async {
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
  await tapKey(tester, 'splash-guest');
  check(find.byType(HomePage).evaluate()).length.equals(1);
}

/// End-to-end consent gating on the demo flavor: the first Home arrival asks
/// for consent with ZERO native prompts, and the app stays usable whether
/// consent is granted (default) or declined. Run with:
///
/// ```bash
/// flutter test integration_test/consent_flow_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Consent flow end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async {
      fakeConsent().reset();
      await getIt.reset();
    });

    testWidgets('first Home arrival requests consent (no native prompt) and '
        'the app stays usable', (tester) async {
      check(fakeConsent().asked).isFalse();

      await goHomeAsGuest(tester);

      // The first post-frame on Home asked for consent — but the fake no-ops
      // (no native UMP/ATT sheet blocks the UI).
      check(fakeConsent().asked).isTrue();
      check(fakeConsent().personalizedAdsAllowed).isTrue();

      // The app is fully usable: tabs switch.
      await tapKey(tester, 'app-nav-2');
      check(find.byType(SettingsPage).evaluate()).length.equals(1);
      await tapKey(tester, 'app-nav-0');
      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('declined consent: the app still works and reports the '
        'non-personalized path', (tester) async {
      fakeConsent().declined = true;

      await goHomeAsGuest(tester);

      check(fakeConsent().asked).isTrue();
      check(fakeConsent().personalizedAdsAllowed).isFalse();

      // Still usable end-to-end.
      await tapKey(tester, 'app-nav-1');
      await tapKey(tester, 'app-nav-0');
      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });
}
