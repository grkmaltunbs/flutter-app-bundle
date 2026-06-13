import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/app_info/app_info.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/network/connectivity_cubit.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';
import 'package:okey_acar_mi/core/storage/drift_preferences_store.dart';
import 'package:okey_acar_mi/core/storage/preferences_store.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/_template/data/fakes/fake_template_repository.dart';
import 'package:okey_acar_mi/features/_template/data/repositories/template_repository_impl.dart';
import 'package:okey_acar_mi/features/_template/domain/repositories/template_repository.dart';
import 'package:okey_acar_mi/features/_template/presentation/blocs/template_bloc.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart';
import 'package:okey_acar_mi/features/solver/domain/usecases/solve_rack.dart';

void main() {
  // configureDependencies pre-resolves AppInfo (a platform channel): without
  // a binding the channel access throws an Error before the module's
  // host-test fallback can catch the MissingPluginException.
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('SolverEngine resolves to the DP engine (no environment split)', () {
      check(getIt<SolverEngine>()).isA<DpSolverEngine>();
    });

    test('SolveRack resolves with the engine wired in', () {
      check(getIt.isRegistered<SolveRack>()).isTrue();
      check(getIt<SolveRack>()).isA<SolveRack>();
    });

    test('PreferencesStore resolves to the drift-backed store', () {
      check(getIt<PreferencesStore>()).isA<DriftPreferencesStore>();
    });

    test('ConnectivityCubit resolves online over the fake service', () {
      final cubit = getIt<ConnectivityCubit>();
      addTearDown(cubit.close);

      check(cubit.state).isTrue();
    });

    test('SettingsCubit resolves hydrated to the defaults (fresh store)', () {
      final cubit = getIt<SettingsCubit>();
      addTearDown(cubit.close);

      check(cubit.state).equals(SettingsState.initial());
    });

    test('AppInfo pre-resolves (host fallback without platform channel)', () {
      check(getIt<AppInfo>().label).isNotEmpty();
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

    test('SolverEngine resolves to the DP engine (no environment split)', () {
      check(getIt<SolverEngine>()).isA<DpSolverEngine>();
    });

    test('SolveRack resolves with the engine wired in', () {
      check(getIt.isRegistered<SolveRack>()).isTrue();
      check(getIt<SolveRack>()).isA<SolveRack>();
    });

    test('PreferencesStore resolves to the drift-backed store', () {
      check(getIt<PreferencesStore>()).isA<DriftPreferencesStore>();
    });

    test('ConnectivityCubit is registered', () {
      // Registration only: instantiating would subscribe the REAL
      // connectivity plugin, which has no platform channel on the host.
      check(getIt.isRegistered<ConnectivityCubit>()).isTrue();
    });

    test('SettingsCubit resolves hydrated to the defaults (fresh store)', () {
      final cubit = getIt<SettingsCubit>();
      addTearDown(cubit.close);

      check(cubit.state).equals(SettingsState.initial());
    });

    test('AppInfo pre-resolves (host fallback without platform channel)', () {
      check(getIt<AppInfo>().label).isNotEmpty();
    });
  });
}
