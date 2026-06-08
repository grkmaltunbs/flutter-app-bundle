import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/features/onboarding/presentation/pages/splash_page.dart';

/// End-to-end boot smoke for the demo flavor.
///
/// Drives the real [App] (router + theme + l10n) against the seeded fakes, with
/// no Firebase and no camera, so it runs headlessly here and on the iOS/Android
/// simulators that flutter-qa targets. Run on a device with:
///
/// ```bash
/// flutter test integration_test/app_boot_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App boot end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    testWidgets('launches to the splash entry with no exceptions', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      check(tester.takeException()).isNull();
      check(find.byType(SplashPage).evaluate()).length.equals(1);
    });
  });
}
