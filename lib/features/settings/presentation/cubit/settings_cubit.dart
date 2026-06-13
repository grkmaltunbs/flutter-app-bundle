import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/storage/preferences_store.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_persistence.dart';

// `GameMode` moved to core/game so pure-Dart layers (review/solver domains)
// can use it without importing the settings feature; re-exported here so
// every existing `settings_cubit.dart` call site keeps compiling unchanged.
export 'package:okey_acar_mi/core/game/game_mode.dart';

part 'settings_cubit.freezed.dart';
part 'settings_state.dart';

/// Holds the user's app-wide settings: theme choice, tile style, accent,
/// language, and default game mode.
///
/// Hydrates synchronously from the [PreferencesStore] snapshot and persists
/// each change fire-and-forget (the store never throws). A null store (tests)
/// means defaults + no persistence. Constructed via `SettingsBindings`, the
/// DI module that wires the store in. Holds no subscriptions, so [close] is
/// not overridden.
class SettingsCubit extends Cubit<SettingsState> {
  /// Creates a [SettingsCubit] hydrated from [store] (or
  /// [SettingsState.initial] when [store] is null).
  SettingsCubit({PreferencesStore? store})
    : _store = store,
      super(SettingsStateCodec.read(store));

  final PreferencesStore? _store;

  /// Selects the [ThemeChoice].
  void setThemeChoice(ThemeChoice choice) {
    emit(state.copyWith(themeChoice: choice));
    _persist(SettingsPrefKeys.themeChoice, choice.name);
  }

  /// Selects the [TileStyle].
  void setTileStyle(TileStyle style) {
    emit(state.copyWith(tileStyle: style));
    _persist(SettingsPrefKeys.tileStyle, style.name);
  }

  /// Selects the [AppAccent].
  void setAccent(AppAccent accent) {
    emit(state.copyWith(accent: accent));
    _persist(SettingsPrefKeys.accent, accent.name);
  }

  /// Selects the [AppLanguage] (drives the active locale live).
  void setLanguage(AppLanguage language) {
    emit(state.copyWith(language: language));
    _persist(SettingsPrefKeys.language, language.name);
  }

  /// Selects the default [GameMode].
  void setGameMode(GameMode mode) {
    emit(state.copyWith(gameMode: mode));
    _persist(SettingsPrefKeys.gameMode, mode.name);
  }

  /// Fire-and-forget persistence: the store's write never throws (failures
  /// are logged inside it), so dropping the future is safe.
  void _persist(String key, String value) =>
      unawaited(_store?.write(key, value));
}
