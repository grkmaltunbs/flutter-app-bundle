import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_persistence.dart';

import '../../helpers/in_memory_preferences_store.dart';

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

  group('SettingsCubit persistence', () {
    test('hydrates the initial state from a seeded store', () {
      final store = InMemoryPreferencesStore({
        SettingsPrefKeys.themeChoice: 'felt',
        SettingsPrefKeys.tileStyle: 'minimal',
        SettingsPrefKeys.accent: 'amber',
        SettingsPrefKeys.language: 'turkish',
        SettingsPrefKeys.gameMode: 'okey',
      });

      final cubit = SettingsCubit(store: store);
      addTearDown(cubit.close);

      check(cubit.state).equals(
        SettingsState.initial().copyWith(
          themeChoice: ThemeChoice.felt,
          tileStyle: TileStyle.minimal,
          accent: AppAccent.amber,
          language: AppLanguage.turkish,
          gameMode: GameMode.okey,
        ),
      );
      // Hydration is read-only: nothing is written back at construction.
      check(store.writes).isEmpty();
    });

    test('a partially-seeded store hydrates seeded fields and defaults the '
        'rest', () {
      final store = InMemoryPreferencesStore({
        SettingsPrefKeys.accent: 'indigo',
      });

      final cubit = SettingsCubit(store: store);
      addTearDown(cubit.close);

      check(
        cubit.state,
      ).equals(SettingsState.initial().copyWith(accent: AppAccent.indigo));
    });

    test('every setter persists its enum name under its SettingsPrefKeys '
        'key', () {
      final store = InMemoryPreferencesStore();
      final cubit = SettingsCubit(store: store)
        ..setThemeChoice(ThemeChoice.dark)
        ..setTileStyle(TileStyle.flat)
        ..setAccent(AppAccent.indigo)
        ..setLanguage(AppLanguage.english)
        ..setGameMode(GameMode.okey);
      addTearDown(cubit.close);

      check(store.values).deepEquals({
        SettingsPrefKeys.themeChoice: 'dark',
        SettingsPrefKeys.tileStyle: 'flat',
        SettingsPrefKeys.accent: 'indigo',
        SettingsPrefKeys.language: 'english',
        SettingsPrefKeys.gameMode: 'okey',
      });
    });

    test('re-selecting a setting overwrites the persisted value', () {
      final store = InMemoryPreferencesStore();
      final cubit = SettingsCubit(store: store)
        ..setThemeChoice(ThemeChoice.dark)
        ..setThemeChoice(ThemeChoice.light);
      addTearDown(cubit.close);

      check(store.read(SettingsPrefKeys.themeChoice)).equals('light');
      check(store.writes).deepEquals([
        (SettingsPrefKeys.themeChoice, 'dark'),
        (SettingsPrefKeys.themeChoice, 'light'),
      ]);
    });

    blocTest<SettingsCubit, SettingsState>(
      'a failing store write never disturbs the emitted states',
      build: () =>
          SettingsCubit(store: InMemoryPreferencesStore()..failWrites = true),
      act: (cubit) => cubit
        ..setAccent(AppAccent.coral)
        ..setGameMode(GameMode.okey),
      expect: () => [
        SettingsState.initial().copyWith(accent: AppAccent.coral),
        SettingsState.initial().copyWith(
          accent: AppAccent.coral,
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
