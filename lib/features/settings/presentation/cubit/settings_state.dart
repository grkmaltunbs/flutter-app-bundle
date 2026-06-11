part of 'settings_cubit.dart';

/// The theme mode the user has selected.
enum ThemeChoice {
  /// Always light.
  light,

  /// Always dark.
  dark,

  /// Follow the platform brightness.
  system,

  /// The felt (green-table) theme.
  felt,
}

/// The app language the user has selected, or follow the platform.
enum AppLanguage {
  /// Follow the device locale (resolved against the supported locales).
  system,

  /// Force Turkish.
  turkish,

  /// Force English.
  english
  ;

  /// The [Locale] to force on `MaterialApp`, or null to follow the platform.
  Locale? get locale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.turkish => const Locale('tr'),
    AppLanguage.english => const Locale('en'),
  };
}

/// Immutable settings state driving theming, the tile kit, language, and mode.
@freezed
abstract class SettingsState with _$SettingsState {
  /// Creates a [SettingsState].
  const factory SettingsState({
    required ThemeChoice themeChoice,
    required TileStyle tileStyle,
    required AppAccent accent,
    required AppLanguage language,
    required GameMode gameMode,
  }) = _SettingsState;

  /// The initial settings: follow the system theme + language, classic tiles,
  /// sage accent, 101 mode.
  factory SettingsState.initial() => const SettingsState(
    themeChoice: ThemeChoice.system,
    tileStyle: TileStyle.classic,
    accent: AppAccent.sage,
    language: AppLanguage.system,
    gameMode: GameMode.oneZeroOne,
  );
}
