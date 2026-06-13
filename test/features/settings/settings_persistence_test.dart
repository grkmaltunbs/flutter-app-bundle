import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_persistence.dart';

import '../../helpers/in_memory_preferences_store.dart';

void main() {
  group('SettingsPrefKeys', () {
    test('the key strings are pinned — renaming one orphans stored prefs', () {
      check(SettingsPrefKeys.themeChoice).equals('settings.themeChoice');
      check(SettingsPrefKeys.tileStyle).equals('settings.tileStyle');
      check(SettingsPrefKeys.accent).equals('settings.accent');
      check(SettingsPrefKeys.language).equals('settings.language');
      check(SettingsPrefKeys.gameMode).equals('settings.gameMode');
    });
  });

  group('SettingsStateCodec.read', () {
    test('a null store yields the initial defaults', () {
      check(SettingsStateCodec.read(null)).equals(SettingsState.initial());
    });

    test('an empty store yields the initial defaults', () {
      check(
        SettingsStateCodec.read(InMemoryPreferencesStore()),
      ).equals(SettingsState.initial());
    });

    test('every value of all five enums round-trips through its name', () {
      void roundTrip<T extends Enum>(
        List<T> values,
        String key,
        T Function(SettingsState) select,
      ) {
        for (final value in values) {
          final state = SettingsStateCodec.read(
            InMemoryPreferencesStore({key: value.name}),
          );
          check(
            because: '$key=${value.name} must decode to $value',
            select(state),
          ).equals(value);
        }
      }

      roundTrip(
        ThemeChoice.values,
        SettingsPrefKeys.themeChoice,
        (s) => s.themeChoice,
      );
      roundTrip(
        TileStyle.values,
        SettingsPrefKeys.tileStyle,
        (s) => s.tileStyle,
      );
      roundTrip(AppAccent.values, SettingsPrefKeys.accent, (s) => s.accent);
      roundTrip(
        AppLanguage.values,
        SettingsPrefKeys.language,
        (s) => s.language,
      );
      roundTrip(GameMode.values, SettingsPrefKeys.gameMode, (s) => s.gameMode);
    });

    test('a fully-seeded store reconstructs the exact state', () {
      final store = InMemoryPreferencesStore({
        SettingsPrefKeys.themeChoice: 'felt',
        SettingsPrefKeys.tileStyle: 'minimal',
        SettingsPrefKeys.accent: 'amber',
        SettingsPrefKeys.language: 'turkish',
        SettingsPrefKeys.gameMode: 'okey',
      });

      check(SettingsStateCodec.read(store)).equals(
        SettingsState.initial().copyWith(
          themeChoice: ThemeChoice.felt,
          tileStyle: TileStyle.minimal,
          accent: AppAccent.amber,
          language: AppLanguage.turkish,
          gameMode: GameMode.okey,
        ),
      );
    });

    test('unknown names (a future version, wrong case, garbage) fall back '
        'per-field without disturbing valid keys', () {
      final store = InMemoryPreferencesStore({
        SettingsPrefKeys.themeChoice: 'purple', // unknown value
        SettingsPrefKeys.tileStyle: '', // empty string
        SettingsPrefKeys.accent: 'CORAL', // names are case-sensitive
        SettingsPrefKeys.language: 'türkçe', // garbage
        SettingsPrefKeys.gameMode: 'okey', // valid — must survive
      });

      check(SettingsStateCodec.read(store)).equals(
        SettingsState.initial().copyWith(gameMode: GameMode.okey),
      );
    });

    test('cubit writes round-trip through the codec (the host-side restart '
        'loop)', () {
      final store = InMemoryPreferencesStore();
      final cubit = SettingsCubit(store: store)
        ..setThemeChoice(ThemeChoice.dark)
        ..setTileStyle(TileStyle.bold)
        ..setAccent(AppAccent.coral)
        ..setLanguage(AppLanguage.english)
        ..setGameMode(GameMode.okey);
      addTearDown(cubit.close);

      check(SettingsStateCodec.read(store)).equals(cubit.state);
    });
  });
}
