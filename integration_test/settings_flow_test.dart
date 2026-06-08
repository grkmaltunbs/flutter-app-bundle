import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_palette.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';

/// End-to-end live settings switching on the demo flavor: theme, tile style,
/// accent, language (TR/EN re-render), and default game mode — each asserted
/// against the live [SettingsCubit], the active [AppPalette], and the resolved
/// locale read from the tree. Run with:
///
/// ```bash
/// flutter test integration_test/settings_flow_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings switching end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    BuildContext settingsContext(WidgetTester tester) =>
        tester.element(find.byType(SettingsPage));

    SettingsState settings(WidgetTester tester) =>
        settingsContext(tester).read<SettingsCubit>().state;

    AppPalette palette(WidgetTester tester) =>
        Theme.of(settingsContext(tester)).extension<AppPalette>()!;

    Future<void> tapKey(WidgetTester tester, String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('switches theme, tile style, accent, language, mode live', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Enter as guest, then open the Settings tab.
      await tester.tap(find.byKey(const ValueKey('splash-guest')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-nav-2')));
      await tester.pumpAndSettle();
      check(find.byType(SettingsPage).evaluate()).length.equals(1);

      // Theme → felt: cubit advances and the palette surface actually changes.
      final lightSurface = palette(tester).surface;
      await tapKey(tester, 'settings-theme-felt');
      check(settings(tester).themeChoice).equals(ThemeChoice.felt);
      check(palette(tester).surface).not((it) => it.equals(lightSurface));

      // Tile style → bold.
      await tapKey(tester, 'settings-tile-style-bold');
      check(settings(tester).tileStyle).equals(TileStyle.bold);
      check(palette(tester).tileStyle).equals(TileStyle.bold);

      // Accent → coral.
      await tapKey(tester, 'settings-accent-coral');
      check(settings(tester).accent).equals(AppAccent.coral);
      check(palette(tester).accent).equals(AppAccent.coral.seed);

      // Language → English then Turkish: the resolved locale follows live.
      await tapKey(tester, 'settings-language-english');
      check(settings(tester).language).equals(AppLanguage.english);
      check(
        Localizations.localeOf(settingsContext(tester)).languageCode,
      ).equals('en');

      await tapKey(tester, 'settings-language-turkish');
      check(settings(tester).language).equals(AppLanguage.turkish);
      check(
        Localizations.localeOf(settingsContext(tester)).languageCode,
      ).equals('tr');

      // Default game mode → Okey.
      await tapKey(tester, 'settings-mode-okey');
      check(settings(tester).gameMode).equals(GameMode.okey);

      check(tester.takeException()).isNull();
    });
  });
}
