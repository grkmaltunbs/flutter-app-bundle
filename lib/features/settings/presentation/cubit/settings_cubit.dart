import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';

part 'settings_cubit.freezed.dart';
part 'settings_state.dart';

/// Holds the user's app-wide settings: theme choice, tile style, accent,
/// language, and default game mode.
///
/// Pure in-memory for now; persistence (via a settings repository / drift)
/// lands in Step 10. Registered in both envs since it has no backend
/// dependency. Holds no subscriptions, so [close] is not overridden.
@injectable
class SettingsCubit extends Cubit<SettingsState> {
  /// Creates a [SettingsCubit] seeded with [SettingsState.initial].
  SettingsCubit() : super(SettingsState.initial());

  /// Selects the [ThemeChoice].
  void setThemeChoice(ThemeChoice choice) =>
      emit(state.copyWith(themeChoice: choice));

  /// Selects the [TileStyle].
  void setTileStyle(TileStyle style) => emit(state.copyWith(tileStyle: style));

  /// Selects the [AppAccent].
  void setAccent(AppAccent accent) => emit(state.copyWith(accent: accent));

  /// Selects the [AppLanguage] (drives the active locale live).
  void setLanguage(AppLanguage language) =>
      emit(state.copyWith(language: language));

  /// Selects the default [GameMode].
  void setGameMode(GameMode mode) => emit(state.copyWith(gameMode: mode));
}
