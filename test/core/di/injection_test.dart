import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/_template/data/fakes/fake_template_repository.dart';
import 'package:okey_acar_mi/features/_template/data/repositories/template_repository_impl.dart';
import 'package:okey_acar_mi/features/_template/domain/repositories/template_repository.dart';
import 'package:okey_acar_mi/features/_template/presentation/blocs/template_bloc.dart';

void main() {
  group('configureDependencies (demo environment)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    test('Clock resolves to the FakeClock with its seeded instant', () {
      final clock = getIt<Clock>();

      check(clock).isA<FakeClock>();
      // FakeClock is pinned to a fixed UTC instant so flows are reproducible.
      check(clock.now()).equals(DateTime.utc(2026));
    });

    test('ConnectivityService resolves to the always-online fake', () async {
      final connectivity = getIt<ConnectivityService>();

      check(connectivity).isA<FakeConnectivityService>();
      check(await connectivity.isOnline()).isTrue();
    });

    test('TemplateRepository resolves to the demo fake', () {
      final repository = getIt<TemplateRepository>();

      check(repository).isA<FakeTemplateRepository>();
    });

    test('TemplateBloc resolves with its demo-fake-backed dependency', () {
      // Factory registration: the graph wires GetTemplateItems to the fake.
      check(getIt.isRegistered<TemplateBloc>()).isTrue();
      addTearDown(getIt<TemplateBloc>().close);
    });
  });

  group('configureDependencies (prod environment)', () {
    setUp(() async => configureDependencies('prod'));
    tearDown(() async => getIt.reset());

    test('Clock resolves to the real SystemClock', () {
      check(getIt<Clock>()).isA<SystemClock>();
    });

    test('ConnectivityService resolves to the real impl', () {
      check(getIt<ConnectivityService>()).isA<ConnectivityServiceImpl>();
    });

    test('TemplateRepository resolves to the real impl', () {
      check(getIt<TemplateRepository>()).isA<TemplateRepositoryImpl>();
    });
  });
}
