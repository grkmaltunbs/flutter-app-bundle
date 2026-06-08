import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/placeholder_page.dart';
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

/// Wraps [child] with the theme + localization + a [SettingsCubit] and the
/// matrix [size]/[textScale]/[locale], without a fixed-size `MaterialApp` view
/// that could mask an overflow.
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
    home: BlocProvider<SettingsCubit>(
      create: (_) => SettingsCubit(),
      child: MediaQuery(
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
/// (e.g. [PlaceholderPage.build] calls `context.canPop()`).
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
    builder: (context, child) => MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
  );
}

void _matrixTest(
  String name,
  Widget Function() build, {
  bool router = false,
}) {
  group('$name overflow guard', () {
    for (final locale in _locales) {
      for (final size in _matrix) {
        for (final textScale in _textScales) {
          testWidgets(
            '$name no overflow @ ${locale.languageCode} $size x$textScale',
            (tester) async {
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
  _matrixTest('SplashPage', () => const SplashPage());
  _matrixTest('HomePage', () => const HomePage());
  _matrixTest('TutorialPage', () => const TutorialPage());
  _matrixTest('HistoryPage', () => const HistoryPage());
  _matrixTest('SettingsPage', () => const SettingsPage());

  // Placeholder routes (login/camera/.../paywall) must also be overflow-safe.
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
