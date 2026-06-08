import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';

void main() {
  group('SettingsCubit', () {
    test('initial state is (system, classic, sage, system, 101)', () {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);

      check(cubit.state.themeChoice).equals(ThemeChoice.system);
      check(cubit.state.tileStyle).equals(TileStyle.classic);
      check(cubit.state.accent).equals(AppAccent.sage);
      check(cubit.state.language).equals(AppLanguage.system);
      check(cubit.state.gameMode).equals(GameMode.oneZeroOne);
    });

    blocTest<SettingsCubit, SettingsState>(
      'setThemeChoice(felt) emits felt and preserves the rest',
      build: SettingsCubit.new,
      act: (cubit) => cubit.setThemeChoice(ThemeChoice.felt),
      expect: () => [
        SettingsState.initial().copyWith(themeChoice: ThemeChoice.felt),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setTileStyle(bold) emits bold and preserves the rest',
      build: SettingsCubit.new,
      act: (cubit) => cubit.setTileStyle(TileStyle.bold),
      expect: () => [
        SettingsState.initial().copyWith(tileStyle: TileStyle.bold),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setAccent(coral) emits coral and preserves the rest',
      build: SettingsCubit.new,
      act: (cubit) => cubit.setAccent(AppAccent.coral),
      expect: () => [SettingsState.initial().copyWith(accent: AppAccent.coral)],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setLanguage(english) emits english and preserves the rest',
      build: SettingsCubit.new,
      act: (cubit) => cubit.setLanguage(AppLanguage.english),
      expect: () => [
        SettingsState.initial().copyWith(language: AppLanguage.english),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setGameMode(okey) emits okey and preserves the rest',
      build: SettingsCubit.new,
      act: (cubit) => cubit.setGameMode(GameMode.okey),
      expect: () => [SettingsState.initial().copyWith(gameMode: GameMode.okey)],
    );

    blocTest<SettingsCubit, SettingsState>(
      'the five setters are independent and compose',
      build: SettingsCubit.new,
      act: (cubit) => cubit
        ..setThemeChoice(ThemeChoice.dark)
        ..setTileStyle(TileStyle.minimal)
        ..setAccent(AppAccent.indigo)
        ..setLanguage(AppLanguage.turkish)
        ..setGameMode(GameMode.okey),
      expect: () => [
        SettingsState.initial().copyWith(themeChoice: ThemeChoice.dark),
        SettingsState.initial().copyWith(
          themeChoice: ThemeChoice.dark,
          tileStyle: TileStyle.minimal,
        ),
        SettingsState.initial().copyWith(
          themeChoice: ThemeChoice.dark,
          tileStyle: TileStyle.minimal,
          accent: AppAccent.indigo,
        ),
        SettingsState.initial().copyWith(
          themeChoice: ThemeChoice.dark,
          tileStyle: TileStyle.minimal,
          accent: AppAccent.indigo,
          language: AppLanguage.turkish,
        ),
        SettingsState.initial().copyWith(
          themeChoice: ThemeChoice.dark,
          tileStyle: TileStyle.minimal,
          accent: AppAccent.indigo,
          language: AppLanguage.turkish,
          gameMode: GameMode.okey,
        ),
      ],
    );
  });

  group('AppLanguage.locale', () {
    test('maps system→null, turkish→tr, english→en', () {
      check(AppLanguage.system.locale).isNull();
      check(AppLanguage.turkish.locale?.languageCode).equals('tr');
      check(AppLanguage.english.locale?.languageCode).equals('en');
    });
  });
}
