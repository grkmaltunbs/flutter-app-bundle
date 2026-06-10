import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/camera/viewfinder_service.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/placeholder_page.dart';
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/delete_account_cubit.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/login_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/pages/login_page.dart';
import 'package:okey_acar_mi/features/auth/presentation/widgets/delete_account_sheet.dart';
import 'package:okey_acar_mi/features/auth/presentation/widgets/forgot_password_sheet.dart';
import 'package:okey_acar_mi/features/auth/presentation/widgets/session_expired_banner.dart';
import 'package:okey_acar_mi/features/capture/data/fakes/fake_capture_service.dart';
import 'package:okey_acar_mi/features/capture/presentation/blocs/camera_bloc.dart';
import 'package:okey_acar_mi/features/capture/presentation/pages/camera_page.dart';
import 'package:okey_acar_mi/features/history/presentation/pages/history_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/onboarding/presentation/pages/splash_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';
import 'package:okey_acar_mi/features/shell/presentation/widgets/app_bottom_nav.dart';
import 'package:okey_acar_mi/features/tutorial/presentation/pages/tutorial_page.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Responsive size matrix from `CLAUDE.md`: smallest phone, typical phone,
/// largest phone, tablet. A `RenderFlex` overflow throws in debug, so pumping
/// each size at text scales 1.0 and 2.0 and asserting no exception catches an
/// overflow deterministically.
const _matrix = <Size>[
  Size(320, 568),
  Size(393, 852),
  Size(430, 932),
  Size(834, 1194),
];

const _textScales = <double>[1, 2];

/// Both supported locales — Turkish strings are often longer than English, so
/// the longer TR labels must also be asserted overflow-free.
const _locales = <Locale>[Locale('tr'), Locale('en')];

/// The blocs every screen may read: [SettingsCubit] plus the app-scoped
/// [AuthBloc] (Settings' account section, the shell banner).
MultiBlocProvider _withProviders(Widget child) => MultiBlocProvider(
  providers: [
    BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
    BlocProvider<AuthBloc>(
      create: (_) => getIt<AuthBloc>()..add(const AuthEvent.started()),
    ),
  ],
  child: child,
);

/// Wraps [child] with the theme + localization + the bloc providers and the
/// matrix [size]/[textScale]/[locale], without a fixed-size `MaterialApp`
/// view that could mask an overflow.
Widget _harness({
  required Size size,
  required double textScale,
  required Locale locale,
  required Widget child,
}) {
  return MaterialApp(
    theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('tr'), Locale('en')],
    home: _withProviders(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );
}

/// A router-backed harness for screens that read go_router at build time
/// (e.g. [PlaceholderPage.build] and `LoginPage` call `context.canPop()`).
Widget _routerHarness({
  required Size size,
  required double textScale,
  required Locale locale,
  required Widget child,
}) {
  final router = GoRouter(
    initialLocation: '/x',
    routes: [GoRoute(path: '/x', builder: (context, state) => child)],
  );
  return MaterialApp.router(
    theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('tr'), Locale('en')],
    routerConfig: router,
    builder: (context, child) => _withProviders(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  );
}

void _matrixTest(
  String name,
  Widget Function() build, {
  bool router = false,
  void Function()? prepare,
}) {
  group('$name overflow guard', () {
    for (final locale in _locales) {
      for (final size in _matrix) {
        for (final textScale in _textScales) {
          testWidgets(
            '$name no overflow @ ${locale.languageCode} $size x$textScale',
            (tester) async {
              prepare?.call();
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1.0;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);

              await tester.pumpWidget(
                router
                    ? _routerHarness(
                        size: size,
                        textScale: textScale,
                        locale: locale,
                        child: build(),
                      )
                    : _harness(
                        size: size,
                        textScale: textScale,
                        locale: locale,
                        child: build(),
                      ),
              );
              await tester.pumpAndSettle();

              check(tester.takeException()).isNull();
            },
          );
        }
      }
    }
  });
}

void main() {
  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  _matrixTest('SplashPage', () => const SplashPage());
  _matrixTest('HomePage', () => const HomePage());
  _matrixTest('TutorialPage', () => const TutorialPage());
  _matrixTest('HistoryPage', () => const HistoryPage());
  _matrixTest('SettingsPage', () => const SettingsPage());
  _matrixTest(
    'SettingsPage (signed-in)',
    () => const SettingsPage(),
    prepare: () => _fakeAuth().mode = FakeAuthMode.seededSignedIn,
  );
  _matrixTest(
    'SettingsPage (unverified)',
    () => const SettingsPage(),
    prepare: () => _fakeAuth().mode = FakeAuthMode.seededUnverified,
  );
  _matrixTest('LoginPage', () => const LoginPage(), router: true);

  // The session-expired banner above the tab content (the AppShell layout).
  _matrixTest(
    'SessionExpiredBanner shell',
    _sessionExpiredSample,
    prepare: () => _fakeAuth().mode = FakeAuthMode.sessionExpired,
  );

  // Bottom-sheet bodies, pumped inside a plain Scaffold.
  _matrixTest(
    'DeleteAccountSheet (confirm)',
    () => _deleteSheetSample(const DeleteAccountState.confirm()),
    prepare: () => _fakeAuth().mode = FakeAuthMode.seededSignedIn,
  );
  _matrixTest(
    'DeleteAccountSheet (reauth, wrong password)',
    () => _deleteSheetSample(
      const DeleteAccountState.reauth(wrongPassword: true),
    ),
    prepare: () => _fakeAuth().mode = FakeAuthMode.seededSignedIn,
  );
  _matrixTest(
    'ForgotPasswordSheet (form)',
    () => _forgotSheetSample(const LoginState()),
  );
  _matrixTest(
    'ForgotPasswordSheet (sent)',
    () => _forgotSheetSample(const LoginState(resetEmailSent: true)),
  );

  // The capture screen, across its blocked/live states. The real demo-DI
  // CameraPage is driven through the FakeCaptureService mode (the page's own
  // started event lands each state); the recording frame is pinned directly
  // on the bloc because the fake's instant burst never rests there.
  _matrixTest('CameraPage (ready)', () => const CameraPage(), router: true);
  _matrixTest(
    'CameraPage (camera denied)',
    () => const CameraPage(),
    router: true,
    prepare: () => _fakeCapture().mode = FakeCaptureMode.cameraDenied,
  );
  _matrixTest(
    'CameraPage (camera permanently denied)',
    () => const CameraPage(),
    router: true,
    prepare: () =>
        _fakeCapture().mode = FakeCaptureMode.cameraPermanentlyDenied,
  );
  _matrixTest(
    'CameraPage (unavailable)',
    () => const CameraPage(),
    router: true,
    prepare: () => _fakeCapture().mode = FakeCaptureMode.noCamera,
  );
  _matrixTest('CameraView (recording)', _cameraRecordingSample, router: true);

  // Placeholder routes (analyzing/.../paywall) must also be overflow-safe.
  for (final screen in PlaceholderScreen.values) {
    _matrixTest(
      'PlaceholderPage(${screen.name})',
      () => PlaceholderPage(screen: screen),
      router: true,
    );
  }

  // The bottom nav must survive textScale 2.0 (custom bar, no fixed height).
  _matrixTest('AppBottomNav', _bottomNavSample);
}

FakeAuthRepository _fakeAuth() => getIt<AuthRepository>() as FakeAuthRepository;

FakeCaptureService _fakeCapture() => getIt<FakeCaptureService>();

/// The capture screen pinned mid-burst (frame 2 of 5) — the longest top-bar
/// pill content.
Widget _cameraRecordingSample() {
  return BlocProvider<CameraBloc>(
    create: (_) => getIt<CameraBloc>()
      ..emit(const CameraState.recording(framesCaptured: 2, frameTarget: 5)),
    child: CameraView(viewfinder: getIt<ViewfinderService>()),
  );
}

/// The AppShell body layout when the session-expired banner is visible.
Widget _sessionExpiredSample() {
  return const Scaffold(
    body: Column(
      children: [
        SessionExpiredBanner(),
        Expanded(child: SizedBox.shrink()),
      ],
    ),
  );
}

/// The delete-account sheet body in [state], inside a plain Scaffold.
Widget _deleteSheetSample(DeleteAccountState state) {
  return BlocProvider<DeleteAccountCubit>(
    create: (_) => getIt<DeleteAccountCubit>()..emit(state),
    child: const Scaffold(body: DeleteAccountSheet()),
  );
}

/// The forgot-password sheet body driven by [state], inside a plain Scaffold.
Widget _forgotSheetSample(LoginState state) {
  return BlocProvider<LoginBloc>(
    create: (_) => getIt<LoginBloc>()..emit(state),
    child: const Scaffold(
      body: ForgotPasswordSheet(initialEmail: 'oyuncu@demo.app'),
    ),
  );
}

Widget _bottomNavSample() {
  return Builder(
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return Scaffold(
        bottomNavigationBar: AppBottomNav(
          currentIndex: 2,
          onTap: (_) {},
          destinations: [
            AppNavDestination(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: l10n.navHome,
            ),
            AppNavDestination(
              icon: Icons.history_outlined,
              activeIcon: Icons.history,
              label: l10n.navHistory,
            ),
            AppNavDestination(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: l10n.navSettings,
            ),
          ],
        ),
      );
    },
  );
}
