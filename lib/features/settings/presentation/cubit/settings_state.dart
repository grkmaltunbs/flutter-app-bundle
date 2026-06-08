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

/// Immutable settings state driving theming and the tile kit.
@freezed
abstract class SettingsState with _$SettingsState {
  /// Creates a [SettingsState].
  const factory SettingsState({
    required ThemeChoice themeChoice,
    required TileStyle tileStyle,
    required AppAccent accent,
  }) = _SettingsState;

  /// The initial settings: follow the system theme, classic tiles, sage accent.
  factory SettingsState.initial() => const SettingsState(
    themeChoice: ThemeChoice.system,
    tileStyle: TileStyle.classic,
    accent: AppAccent.sage,
  );
}
