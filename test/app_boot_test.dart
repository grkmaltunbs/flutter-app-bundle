import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/env/app_env.dart';

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

    testWidgets('boots to the home stub showing the app title', (tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      check(tester.takeException()).isNull();
      check(find.text('101 Okey Açar Mı').evaluate()).length.equals(1);
    });
  });
}
