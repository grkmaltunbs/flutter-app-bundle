import 'package:okey_acar_mi/core/storage/preferences_store.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';

/// The [PreferencesStore] keys under which each setting persists.
abstract final class SettingsPrefKeys {
  /// Key for [SettingsState.themeChoice].
  static const String themeChoice = 'settings.themeChoice';

  /// Key for [SettingsState.tileStyle].
  static const String tileStyle = 'settings.tileStyle';

  /// Key for [SettingsState.accent].
  static const String accent = 'settings.accent';

  /// Key for [SettingsState.language].
  static const String language = 'settings.language';

  /// Key for [SettingsState.gameMode].
  static const String gameMode = 'settings.gameMode';
}

/// Decodes a persisted [SettingsState] from a [PreferencesStore] snapshot.
abstract final class SettingsStateCodec {
  /// Reads the persisted settings, falling back to [SettingsState.initial]
  /// field-by-field.
  ///
  /// A null [store] (tests), a missing key, or an unknown enum name (e.g. a
  /// value written by a future version) all resolve to that field's default —
  /// this never throws.
  static SettingsState read(PreferencesStore? store) {
    final defaults = SettingsState.initial();
    if (store == null) return defaults;
    T decode<T extends Enum>(List<T> values, String key, T fallback) =>
        values.asNameMap()[store.read(key)] ?? fallback;
    return SettingsState(
      themeChoice: decode(
        ThemeChoice.values,
        SettingsPrefKeys.themeChoice,
        defaults.themeChoice,
      ),
      tileStyle: decode(
        TileStyle.values,
        SettingsPrefKeys.tileStyle,
        defaults.tileStyle,
      ),
      accent: decode(
        AppAccent.values,
        SettingsPrefKeys.accent,
        defaults.accent,
      ),
      language: decode(
        AppLanguage.values,
        SettingsPrefKeys.language,
        defaults.language,
      ),
      gameMode: decode(
        GameMode.values,
        SettingsPrefKeys.gameMode,
        defaults.gameMode,
      ),
    );
  }
}
