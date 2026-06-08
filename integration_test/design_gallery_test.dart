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
import 'package:okey_acar_mi/core/widgets/rack.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';

/// End-to-end design-gallery switching for the demo flavor.
///
/// Drives the real [App] (router + theme + l10n) against the seeded fakes and
/// exercises the Step 1 live gallery on `/`: switching Theme (Light / Dark /
/// System / Felt), Tile style (Classic / Flat / Minimal / Bold), and Accent
/// (Sage / Coral / Indigo / Amber), all bound to [SettingsCubit]. Each switch
/// is asserted against the actual cubit state read from the tree, plus a
/// rendered signal for the felt theme, and the whole run must produce zero
/// exceptions. Run on a device with:
///
/// ```bash
/// flutter test integration_test/design_gallery_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Design gallery switching end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    /// Reads the live [SettingsCubit] provided above `MaterialApp.router`.
    SettingsCubit settingsCubit(WidgetTester tester) =>
        tester.element(find.byType(Rack).first).read<SettingsCubit>();

    /// Reads the active [AppPalette] from the gallery subtree.
    AppPalette palette(WidgetTester tester) {
      final context = tester.element(find.byType(Rack).first);
      return Theme.of(context).extension<AppPalette>()!;
    }

    testWidgets('boots to gallery, then switches theme/style/accent', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // 1. Gallery is up: title + at least one Rack, no exceptions.
      check(tester.takeException()).isNull();
      check(find.text('101 Okey Açar Mı').evaluate()).length.equals(1);
      check(find.byType(Rack).evaluate()).isNotEmpty();

      // 2. Theme switch — tap each choice; assert the cubit advanced and (for
      // felt) the rendered palette surface actually changed vs. light.
      late Color lightSurface;
      for (final choice in ThemeChoice.values) {
        await tester.tap(find.byKey(ValueKey('gallery-theme-${choice.name}')));
        await tester.pumpAndSettle();

        check(tester.takeException()).isNull();
        check(settingsCubit(tester).state.themeChoice).equals(choice);

        if (choice == ThemeChoice.light) {
          lightSurface = palette(tester).surface;
        }
        if (choice == ThemeChoice.felt) {
          // Felt must be reachable AND applied: its surface differs from light.
          check(palette(tester).surface).not((it) => it.equals(lightSurface));
        }
      }

      // 3. Tile style switch — tap each; the Rack rebuilds, cubit updates.
      for (final style in TileStyle.values) {
        await tester.tap(
          find.byKey(ValueKey('gallery-tile-style-${style.name}')),
        );
        await tester.pumpAndSettle();

        check(tester.takeException()).isNull();
        check(settingsCubit(tester).state.tileStyle).equals(style);
        check(palette(tester).tileStyle).equals(style);
      }

      // 4. Accent switch — tap each swatch; cubit + palette accent update.
      for (final accent in AppAccent.values) {
        await tester.tap(find.byKey(ValueKey('gallery-accent-${accent.name}')));
        await tester.pumpAndSettle();

        check(tester.takeException()).isNull();
        check(settingsCubit(tester).state.accent).equals(accent);
        check(palette(tester).accent).equals(accent.seed);
      }

      // 5. Zero exceptions across the whole run; the rack is still onscreen.
      check(tester.takeException()).isNull();
      check(find.byType(Rack).evaluate()).isNotEmpty();
    });
  });
}
