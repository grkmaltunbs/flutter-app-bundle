import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/env/app_env.dart';
import 'package:okey_acar_mi/features/onboarding/presentation/pages/splash_page.dart';

void main() {
  group('AppEnv', () {
    test('defaults to demo and exposes injectable-matching names', () {
      check(AppEnv.current).equals(AppEnv.demo);
      check(AppEnv.demo.name).equals('demo');
      check(AppEnv.prod.name).equals('prod');
    });
  });

  group('App boot (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    testWidgets('boots to the splash entry with no exceptions', (tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      check(tester.takeException()).isNull();
      // Boots to the splash brand entry (initialLocation) rather than crashing.
      check(find.byType(SplashPage).evaluate()).length.equals(1);
    });
  });
}
