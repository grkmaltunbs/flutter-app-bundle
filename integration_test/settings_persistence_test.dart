import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/db/app_database.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/features/settings/presentation/pages/settings_page.dart';

// ---------------------------------------------------------------------------
// Robot helpers
// ---------------------------------------------------------------------------

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Splash → guest entry → Home → Settings tab.
Future<void> openSettingsAsGuest(WidgetTester tester) async {
  await tapKey(tester, 'splash-guest');
  check(find.byType(HomePage).evaluate()).length.equals(1);
  await tapKey(tester, 'app-nav-2');
  check(find.byType(SettingsPage).evaluate()).length.equals(1);
}

BuildContext settingsContext(WidgetTester tester) =>
    tester.element(find.byType(SettingsPage));

SettingsState settings(WidgetTester tester) =>
    settingsContext(tester).read<SettingsCubit>().state;

// ---------------------------------------------------------------------------
// Scenario
// ---------------------------------------------------------------------------

/// End-to-end settings persistence on the demo flavor: all five preferences
/// changed live, then a DI-level "restart" (fresh container reopening the
/// real on-device drift file) must rehydrate every one of them. Run with:
///
/// ```bash
/// flutter test integration_test/settings_persistence_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings persistence end-to-end (demo flavor)', () {
    setUp(() async {
      // Two-phase boot: the preferences snapshot preloads DURING
      // `configureDependencies`, so rows left by a crashed previous run must
      // be wiped and the container rebuilt for the store to start clean.
      await configureDependencies('demo');
      await getIt<AppDatabase>().wipePreferencesForTest();
      await getIt.reset();
      await configureDependencies('demo');
    });

    tearDown(() async {
      // Wipe the persisted rows BEFORE the container reset closes the db, so
      // settings state never leaks into other integration tests.
      await getIt<AppDatabase>().wipePreferencesForTest();
      await getIt.reset();
    });

    testWidgets('all five preferences survive an app restart (fresh DI '
        'container over the same drift file)', (tester) async {
      await pumpApp(tester);
      await openSettingsAsGuest(tester);

      // Change every preference away from its default.
      await tapKey(tester, 'settings-theme-dark');
      await tapKey(tester, 'settings-tile-style-bold');
      await tapKey(tester, 'settings-accent-coral');
      await tapKey(tester, 'settings-language-english');
      await tapKey(tester, 'settings-mode-okey');

      // Sanity: the live cubit carries all five before the restart.
      final before = settings(tester);
      check(before.themeChoice).equals(ThemeChoice.dark);
      check(before.tileStyle).equals(TileStyle.bold);
      check(before.accent).equals(AppAccent.coral);
      check(before.language).equals(AppLanguage.english);
      check(before.gameMode).equals(GameMode.okey);

      // "Restart": unmount the app so no widget holds a bloc from the old
      // container, give the fire-and-forget writes a beat, then reset DI
      // (closing the db flushes its serialized executor) and boot fresh —
      // the new container's store snapshot reloads from the file.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await getIt.reset();
      await configureDependencies('demo');
      await pumpApp(tester);
      await openSettingsAsGuest(tester);

      // The rehydrated cubit carries all five.
      final restored = settings(tester);
      check(restored.themeChoice).equals(ThemeChoice.dark);
      check(restored.tileStyle).equals(TileStyle.bold);
      check(restored.accent).equals(AppAccent.coral);
      check(restored.language).equals(AppLanguage.english);
      check(restored.gameMode).equals(GameMode.okey);

      // And the visible effects survived too: dark theme + resolved EN
      // locale.
      check(
        Theme.of(settingsContext(tester)).brightness,
      ).equals(Brightness.dark);
      check(
        Localizations.localeOf(settingsContext(tester)).languageCode,
      ).equals('en');

      check(tester.takeException()).isNull();
    });
  });
}
