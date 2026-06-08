import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/widgets/placeholder_page.dart';
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

  /// Login / sign-up (placeholder until Step 3).
  static const String login = '/login';

  /// How-it-works tutorial.
  static const String tutorial = '/tutorial';

  /// Home tab.
  static const String home = '/home';

  /// History tab.
  static const String history = '/history';

  /// Settings tab.
  static const String settings = '/settings';

  /// Camera capture (placeholder until Step 4).
  static const String camera = '/camera';

  /// Detection in progress (placeholder until Step 5).
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
/// [AppShell]. State restoration is enabled so a cold start can rebuild a deep
/// location without crashing.
@lazySingleton
class AppRouter {
  /// Creates the singleton [AppRouter] and builds its [config].
  AppRouter() : config = _build();

  /// The [GoRouter] configuration consumed by `MaterialApp.router`.
  final GoRouter config;

  static final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );

  static GoRouter _build() {
    return GoRouter(
      initialLocation: AppRoutes.splash,
      navigatorKey: _rootKey,
      restorationScopeId: 'router',
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) =>
              const PlaceholderPage(screen: PlaceholderScreen.login),
        ),
        GoRoute(
          path: AppRoutes.tutorial,
          builder: (context, state) => const TutorialPage(),
        ),
        GoRoute(
          path: AppRoutes.camera,
          builder: (context, state) =>
              const PlaceholderPage(screen: PlaceholderScreen.camera),
        ),
        GoRoute(
          path: AppRoutes.analyzing,
          builder: (context, state) =>
              const PlaceholderPage(screen: PlaceholderScreen.analyzing),
        ),
        GoRoute(
          path: AppRoutes.review,
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
