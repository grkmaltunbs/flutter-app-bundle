import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/router/go_router_refresh_stream.dart';
import 'package:okey_acar_mi/core/widgets/placeholder_page.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/pages/login_page.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/capture/presentation/pages/camera_page.dart';
import 'package:okey_acar_mi/features/detection/presentation/pages/analyzing_page.dart';
import 'package:okey_acar_mi/features/history/presentation/pages/history_page.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/onboarding/presentation/pages/splash_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';
import 'package:okey_acar_mi/features/shell/presentation/pages/app_shell.dart';
import 'package:okey_acar_mi/features/tutorial/presentation/pages/tutorial_page.dart';

/// Canonical route locations for the app. Centralized so screens never hardcode
/// path strings.
abstract final class AppRoutes {
  /// Splash / brand entry (the initial location).
  static const String splash = '/splash';

  /// Login / sign-up.
  static const String login = '/login';

  /// How-it-works tutorial.
  static const String tutorial = '/tutorial';

  /// Home tab.
  static const String home = '/home';

  /// History tab.
  static const String history = '/history';

  /// Settings tab.
  static const String settings = '/settings';

  /// Camera capture.
  static const String camera = '/camera';

  /// Detection in progress (`extra` must be a `CapturePayload`).
  static const String analyzing = '/analyzing';

  /// Review & correct + indicator (placeholder until Step 6).
  static const String review = '/review';

  /// Result / verdict (placeholder until Step 8).
  static const String result = '/result';

  /// Remove-ads paywall (placeholder until Step 11).
  static const String paywall = '/paywall';
}

/// Declarative application router.
///
/// A splash entry plus standalone routes (login, tutorial, capture→result,
/// paywall) sit alongside a [StatefulShellRoute.indexedStack] that hosts the
/// three persistent tabs (Home / History / Settings) under a shared
/// [AppShell]. The router listens to [AuthBloc] and redirects authenticated
/// users away from splash/login (guard v1, D8); nothing else is guarded.
/// State restoration is enabled so a cold start can rebuild a deep location
/// without crashing.
@lazySingleton
class AppRouter {
  /// Creates the singleton [AppRouter] and builds its [config].
  AppRouter(AuthBloc authBloc)
    : _authBloc = authBloc,
      _refresh = GoRouterRefreshStream(authBloc.stream) {
    config = _build();
  }

  final AuthBloc _authBloc;
  final GoRouterRefreshStream _refresh;

  /// The [GoRouter] configuration consumed by `MaterialApp.router`.
  late final GoRouter config;

  static final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );

  /// Tears down the auth listener and the router when the container resets.
  @disposeMethod
  void dispose() {
    _refresh.dispose();
    config.dispose();
  }

  /// Guard v1 (D8): authenticated users never see splash or login. Login
  /// screens never navigate on success — this redirect does.
  String? _redirect(BuildContext context, GoRouterState state) {
    final authenticated = _authBloc.state is AuthAuthenticated;
    final location = state.matchedLocation;
    if (authenticated &&
        (location == AppRoutes.splash || location == AppRoutes.login)) {
      return AppRoutes.home;
    }
    return null;
  }

  GoRouter _build() {
    return GoRouter(
      initialLocation: AppRoutes.splash,
      navigatorKey: _rootKey,
      restorationScopeId: 'router',
      refreshListenable: _refresh,
      redirect: _redirect,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: AppRoutes.tutorial,
          builder: (context, state) => const TutorialPage(),
        ),
        GoRoute(
          path: AppRoutes.camera,
          builder: (context, state) => const CameraPage(),
        ),
        GoRoute(
          path: AppRoutes.analyzing,
          // The screen is meaningless without a capture: anything that lands
          // here without one (deep link, cold-start restoration — `extra` is
          // not restored) bounces to the camera.
          redirect: (context, state) =>
              state.extra is CapturePayload ? null : AppRoutes.camera,
          builder: (context, state) =>
              AnalyzingPage(payload: state.extra! as CapturePayload),
        ),
        GoRoute(
          path: AppRoutes.review,
          // `extra` is the `DetectionResult` handed off by the analyzing
          // screen; the review feature (Step 6) consumes it.
          builder: (context, state) =>
              const PlaceholderPage(screen: PlaceholderScreen.review),
        ),
        GoRoute(
          path: AppRoutes.result,
          builder: (context, state) =>
              const PlaceholderPage(screen: PlaceholderScreen.result),
        ),
        GoRoute(
          path: AppRoutes.paywall,
          builder: (context, state) =>
              const PlaceholderPage(screen: PlaceholderScreen.paywall),
        ),
        StatefulShellRoute.indexedStack(
          restorationScopeId: 'shell',
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              restorationScopeId: 'home',
              routes: <RouteBase>[
                GoRoute(
                  path: AppRoutes.home,
                  builder: (context, state) => const HomePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              restorationScopeId: 'history',
              routes: <RouteBase>[
                GoRoute(
                  path: AppRoutes.history,
                  builder: (context, state) => const HistoryPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              restorationScopeId: 'settings',
              routes: <RouteBase>[
                GoRoute(
                  path: AppRoutes.settings,
                  builder: (context, state) => const SettingsPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
