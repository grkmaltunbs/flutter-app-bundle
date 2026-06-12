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
import 'package:okey_acar_mi/core/camera/viewfinder_service.dart' as _i381;
import 'package:okey_acar_mi/core/game/game_mode.dart' as _i970;
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
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart'
    as _i861;
import 'package:okey_acar_mi/features/auth/data/repositories/firebase_auth_repository.dart'
    as _i338;
import 'package:okey_acar_mi/features/auth/data/services/noop_guest_data_migrator.dart'
    as _i219;
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart'
    as _i611;
import 'package:okey_acar_mi/features/auth/domain/services/guest_data_migrator.dart'
    as _i574;
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_in_with_apple.dart'
    as _i1041;
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_in_with_email.dart'
    as _i457;
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_in_with_google.dart'
    as _i1047;
import 'package:okey_acar_mi/features/auth/domain/usecases/sign_up_with_email.dart'
    as _i186;
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart'
    as _i614;
import 'package:okey_acar_mi/features/auth/presentation/blocs/delete_account_cubit.dart'
    as _i131;
import 'package:okey_acar_mi/features/auth/presentation/blocs/login_bloc.dart'
    as _i790;
import 'package:okey_acar_mi/features/capture/data/capture_bindings.dart'
    as _i144;
import 'package:okey_acar_mi/features/capture/data/fakes/fake_capture_service.dart'
    as _i510;
import 'package:okey_acar_mi/features/capture/data/services/device_capture_service.dart'
    as _i804;
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart'
    as _i983;
import 'package:okey_acar_mi/features/capture/domain/repositories/capture_repository.dart'
    as _i910;
import 'package:okey_acar_mi/features/capture/domain/usecases/capture_photo.dart'
    as _i818;
import 'package:okey_acar_mi/features/capture/domain/usecases/capture_video_frames.dart'
    as _i601;
import 'package:okey_acar_mi/features/capture/domain/usecases/pick_from_gallery.dart'
    as _i729;
import 'package:okey_acar_mi/features/capture/presentation/blocs/camera_bloc.dart'
    as _i437;
import 'package:okey_acar_mi/features/detection/data/detection_bindings.dart'
    as _i386;
import 'package:okey_acar_mi/features/detection/data/fakes/fake_tile_detector.dart'
    as _i965;
import 'package:okey_acar_mi/features/detection/data/services/pipeline_tile_detector.dart'
    as _i457;
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart'
    as _i728;
import 'package:okey_acar_mi/features/detection/domain/services/tile_detector.dart'
    as _i58;
import 'package:okey_acar_mi/features/detection/domain/usecases/detect_tiles.dart'
    as _i437;
import 'package:okey_acar_mi/features/detection/presentation/blocs/detection_bloc.dart'
    as _i105;
import 'package:okey_acar_mi/features/result/presentation/blocs/result_bloc.dart'
    as _i120;
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart'
    as _i389;
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart'
    as _i739;
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart'
    as _i997;
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart'
    as _i641;
import 'package:okey_acar_mi/features/solver/domain/usecases/solve_rack.dart'
    as _i502;

const String _demo = 'demo';
const String _prod = 'prod';

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final captureBindings = _$CaptureBindings();
    final detectionBindings = _$DetectionBindings();
    gh.factory<_i997.SettingsCubit>(() => _i997.SettingsCubit());
    gh.lazySingleton<_i856.AppLogger>(() => _i856.AppLogger());
    gh.lazySingleton<_i574.GuestDataMigrator>(
      () => const _i219.NoopGuestDataMigrator(),
    );
    gh.lazySingleton<_i510.FakeCaptureService>(
      () => captureBindings.fakeCaptureService,
      registerFor: {_demo},
    );
    gh.lazySingleton<_i92.Clock>(
      () => const _i92.FakeClock(),
      registerFor: {_demo},
    );
    gh.lazySingleton<_i434.TemplateRepository>(
      () => _i766.FakeTemplateRepository(),
      registerFor: {_demo},
    );
    gh.lazySingleton<_i611.AuthRepository>(
      () => _i861.FakeAuthRepository(),
      registerFor: {_demo},
      dispose: _i861.disposeFakeAuthRepository,
    );
    gh.lazySingleton<_i854.ConnectivityService>(
      () => const _i854.FakeConnectivityService(),
      registerFor: {_demo},
    );
    gh.lazySingleton<_i641.SolverEngine>(() => const _i641.DpSolverEngine());
    gh.lazySingleton<_i910.CaptureRepository>(
      () =>
          captureBindings.demoCaptureRepository(gh<_i510.FakeCaptureService>()),
      registerFor: {_demo},
    );
    gh.lazySingleton<_i381.ViewfinderService>(
      () =>
          captureBindings.demoViewfinderService(gh<_i510.FakeCaptureService>()),
      registerFor: {_demo},
    );
    gh.factoryParam<_i739.ReviewBloc, _i728.DetectionResult, _i970.GameMode>(
      (result, gameMode) => _i739.ReviewBloc(result, gameMode),
    );
    gh.lazySingleton<_i804.DeviceCaptureService>(
      () => captureBindings.deviceCaptureService,
      registerFor: {_prod},
      dispose: _i144.disposeDeviceCaptureService,
    );
    gh.lazySingleton<_i434.TemplateRepository>(
      () => const _i604.TemplateRepositoryImpl(),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i92.Clock>(
      () => const _i92.SystemClock(),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i965.FakeTileDetector>(
      () => detectionBindings.fakeTileDetector(gh<_i92.Clock>()),
      registerFor: {_demo},
    );
    gh.lazySingleton<_i611.AuthRepository>(
      () => _i338.FirebaseAuthRepository(),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i910.CaptureRepository>(
      () => captureBindings.prodCaptureRepository(
        gh<_i804.DeviceCaptureService>(),
      ),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i381.ViewfinderService>(
      () => captureBindings.prodViewfinderService(
        gh<_i804.DeviceCaptureService>(),
      ),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i854.ConnectivityService>(
      () => _i854.ConnectivityServiceImpl(),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i58.TileDetector>(
      () => detectionBindings.demoTileDetector(gh<_i965.FakeTileDetector>()),
      registerFor: {_demo},
    );
    gh.factory<_i1041.SignInWithApple>(
      () => _i1041.SignInWithApple(
        gh<_i611.AuthRepository>(),
        gh<_i574.GuestDataMigrator>(),
      ),
    );
    gh.factory<_i457.SignInWithEmail>(
      () => _i457.SignInWithEmail(
        gh<_i611.AuthRepository>(),
        gh<_i574.GuestDataMigrator>(),
      ),
    );
    gh.factory<_i1047.SignInWithGoogle>(
      () => _i1047.SignInWithGoogle(
        gh<_i611.AuthRepository>(),
        gh<_i574.GuestDataMigrator>(),
      ),
    );
    gh.factory<_i186.SignUpWithEmail>(
      () => _i186.SignUpWithEmail(
        gh<_i611.AuthRepository>(),
        gh<_i574.GuestDataMigrator>(),
      ),
    );
    gh.factory<_i502.SolveRack>(
      () => _i502.SolveRack(gh<_i641.SolverEngine>()),
    );
    gh.factoryParam<_i120.ResultBloc, _i389.ReviewOutcome, dynamic>(
      (outcome, _) => _i120.ResultBloc(
        gh<_i502.SolveRack>(),
        gh<_i856.AppLogger>(),
        outcome,
      ),
    );
    gh.factory<_i1033.GetTemplateItems>(
      () => _i1033.GetTemplateItems(gh<_i434.TemplateRepository>()),
    );
    gh.factory<_i60.TemplateBloc>(
      () => _i60.TemplateBloc(gh<_i1033.GetTemplateItems>()),
    );
    gh.factory<_i790.LoginBloc>(
      () => _i790.LoginBloc(
        gh<_i457.SignInWithEmail>(),
        gh<_i186.SignUpWithEmail>(),
        gh<_i1047.SignInWithGoogle>(),
        gh<_i1041.SignInWithApple>(),
        gh<_i611.AuthRepository>(),
      ),
    );
    gh.lazySingleton<_i457.PipelineTileDetector>(
      () => detectionBindings.pipelineTileDetector(
        gh<_i92.Clock>(),
        gh<_i856.AppLogger>(),
      ),
      registerFor: {_prod},
      dispose: _i386.disposePipelineTileDetector,
    );
    gh.lazySingleton<_i614.AuthBloc>(
      () => _i614.AuthBloc(gh<_i611.AuthRepository>()),
    );
    gh.factory<_i131.DeleteAccountCubit>(
      () => _i131.DeleteAccountCubit(gh<_i611.AuthRepository>()),
    );
    gh.factory<_i818.CapturePhoto>(
      () => _i818.CapturePhoto(gh<_i910.CaptureRepository>(), gh<_i92.Clock>()),
    );
    gh.factory<_i601.CaptureVideoFrames>(
      () => _i601.CaptureVideoFrames(
        gh<_i910.CaptureRepository>(),
        gh<_i92.Clock>(),
      ),
    );
    gh.factory<_i729.PickFromGallery>(
      () => _i729.PickFromGallery(
        gh<_i910.CaptureRepository>(),
        gh<_i92.Clock>(),
      ),
    );
    gh.lazySingleton<_i126.AppRouter>(
      () => _i126.AppRouter(gh<_i614.AuthBloc>()),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i58.TileDetector>(
      () =>
          detectionBindings.prodTileDetector(gh<_i457.PipelineTileDetector>()),
      registerFor: {_prod},
    );
    gh.factory<_i437.CameraBloc>(
      () => _i437.CameraBloc(
        gh<_i910.CaptureRepository>(),
        gh<_i818.CapturePhoto>(),
        gh<_i601.CaptureVideoFrames>(),
        gh<_i729.PickFromGallery>(),
      ),
    );
    gh.factory<_i437.DetectTiles>(
      () => _i437.DetectTiles(gh<_i58.TileDetector>()),
    );
    gh.factoryParam<_i105.DetectionBloc, _i983.CapturePayload, dynamic>(
      (payload, _) => _i105.DetectionBloc(
        gh<_i437.DetectTiles>(),
        gh<_i856.AppLogger>(),
        payload,
      ),
    );
    return this;
  }
}

class _$CaptureBindings extends _i144.CaptureBindings {}

class _$DetectionBindings extends _i386.DetectionBindings {}
