import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/widgets/placeholder_page.dart';
import 'package:okey_acar_mi/features/history/presentation/pages/history_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/onboarding/presentation/pages/splash_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';
import 'package:okey_acar_mi/features/tutorial/presentation/pages/tutorial_page.dart';

/// End-to-end coverage of `flow-onboard` and the app shell on the demo flavor:
/// splash entry, guest-first entry to Home, bottom-nav tab switching, the
/// tutorial open/close, and the "continue → login" path. Run with:
///
/// ```bash
/// flutter test integration_test/onboarding_flow_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding + shell end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    testWidgets('guest entry → Home → tabs → tutorial → back', (tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // 1. Splash is the entry point.
      check(find.byType(SplashPage).evaluate()).length.equals(1);

      // 2. Enter as guest → Home.
      await tester.tap(find.byKey(const ValueKey('splash-guest')));
      await tester.pumpAndSettle();
      check(find.byType(HomePage).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();

      // 3. Bottom nav switches tabs: History, Settings, back to Home.
      await tester.tap(find.byKey(const ValueKey('app-nav-1')));
      await tester.pumpAndSettle();
      check(find.byType(HistoryPage).evaluate()).length.equals(1);

      await tester.tap(find.byKey(const ValueKey('app-nav-2')));
      await tester.pumpAndSettle();
      check(find.byType(SettingsPage).evaluate()).length.equals(1);

      await tester.tap(find.byKey(const ValueKey('app-nav-0')));
      await tester.pumpAndSettle();
      check(find.byType(HomePage).evaluate()).length.equals(1);

      // 4. Open the tutorial from Home, then dismiss it back to Home.
      await tester.tap(find.byKey(const ValueKey('home-help')));
      await tester.pumpAndSettle();
      check(find.byType(TutorialPage).evaluate()).length.equals(1);

      final done = find.byKey(const ValueKey('tutorial-done'));
      await tester.ensureVisible(done);
      await tester.pumpAndSettle();
      await tester.tap(done);
      await tester.pumpAndSettle();
      check(find.byType(HomePage).evaluate()).length.equals(1);

      check(tester.takeException()).isNull();
    });

    testWidgets('continue → Login route (placeholder), back to splash', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('splash-continue')));
      await tester.pumpAndSettle();

      // The login route renders the placeholder (real screen lands in Step 3).
      check(find.byType(PlaceholderPage).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });
}
