import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';

void main() {
  group('SettingsCubit', () {
    test('initial state is (system, classic, sage)', () {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);

      check(cubit.state.themeChoice).equals(ThemeChoice.system);
      check(cubit.state.tileStyle).equals(TileStyle.classic);
      check(cubit.state.accent).equals(AppAccent.sage);
    });

    blocTest<SettingsCubit, SettingsState>(
      'setThemeChoice(felt) emits felt and preserves tileStyle + accent',
      build: SettingsCubit.new,
      act: (cubit) => cubit.setThemeChoice(ThemeChoice.felt),
      expect: () => const [
        SettingsState(
          themeChoice: ThemeChoice.felt,
          tileStyle: TileStyle.classic,
          accent: AppAccent.sage,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setTileStyle(bold) emits bold and preserves theme + accent',
      build: SettingsCubit.new,
      act: (cubit) => cubit.setTileStyle(TileStyle.bold),
      expect: () => const [
        SettingsState(
          themeChoice: ThemeChoice.system,
          tileStyle: TileStyle.bold,
          accent: AppAccent.sage,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setAccent(coral) emits coral and preserves theme + tileStyle',
      build: SettingsCubit.new,
      act: (cubit) => cubit.setAccent(AppAccent.coral),
      expect: () => const [
        SettingsState(
          themeChoice: ThemeChoice.system,
          tileStyle: TileStyle.classic,
          accent: AppAccent.coral,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'the three setters are independent and compose',
      build: SettingsCubit.new,
      act: (cubit) => cubit
        ..setThemeChoice(ThemeChoice.dark)
        ..setTileStyle(TileStyle.minimal)
        ..setAccent(AppAccent.indigo),
      expect: () => const [
        SettingsState(
          themeChoice: ThemeChoice.dark,
          tileStyle: TileStyle.classic,
          accent: AppAccent.sage,
        ),
        SettingsState(
          themeChoice: ThemeChoice.dark,
          tileStyle: TileStyle.minimal,
          accent: AppAccent.sage,
        ),
        SettingsState(
          themeChoice: ThemeChoice.dark,
          tileStyle: TileStyle.minimal,
          accent: AppAccent.indigo,
        ),
      ],
    );
  });
}
