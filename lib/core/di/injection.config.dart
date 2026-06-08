// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:okey_acar_mi/core/logging/app_logger.dart' as _i856;
import 'package:okey_acar_mi/core/network/connectivity_service.dart' as _i854;
import 'package:okey_acar_mi/core/router/app_router.dart' as _i126;
import 'package:okey_acar_mi/core/time/clock.dart' as _i92;
import 'package:okey_acar_mi/features/_template/data/fakes/fake_template_repository.dart'
    as _i766;
import 'package:okey_acar_mi/features/_template/data/repositories/template_repository_impl.dart'
    as _i604;
import 'package:okey_acar_mi/features/_template/domain/repositories/template_repository.dart'
    as _i434;
import 'package:okey_acar_mi/features/_template/domain/usecases/get_template_items.dart'
    as _i1033;
import 'package:okey_acar_mi/features/_template/presentation/blocs/template_bloc.dart'
    as _i60;
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart'
    as _i997;

const String _demo = 'demo';
const String _prod = 'prod';

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.factory<_i997.SettingsCubit>(() => _i997.SettingsCubit());
    gh.lazySingleton<_i856.AppLogger>(() => _i856.AppLogger());
    gh.lazySingleton<_i126.AppRouter>(() => _i126.AppRouter());
    gh.lazySingleton<_i92.Clock>(
      () => const _i92.FakeClock(),
      registerFor: {_demo},
    );
    gh.lazySingleton<_i434.TemplateRepository>(
      () => _i766.FakeTemplateRepository(),
      registerFor: {_demo},
    );
    gh.lazySingleton<_i854.ConnectivityService>(
      () => const _i854.FakeConnectivityService(),
      registerFor: {_demo},
    );
    gh.lazySingleton<_i434.TemplateRepository>(
      () => const _i604.TemplateRepositoryImpl(),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i92.Clock>(
      () => const _i92.SystemClock(),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i854.ConnectivityService>(
      () => _i854.ConnectivityServiceImpl(),
      registerFor: {_prod},
    );
    gh.factory<_i1033.GetTemplateItems>(
      () => _i1033.GetTemplateItems(gh<_i434.TemplateRepository>()),
    );
    gh.factory<_i60.TemplateBloc>(
      () => _i60.TemplateBloc(gh<_i1033.GetTemplateItems>()),
    );
    return this;
  }
}
