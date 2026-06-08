import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';

part 'settings_cubit.freezed.dart';
part 'settings_state.dart';

/// Holds the user's appearance settings: theme choice, tile style, and accent.
///
/// Pure in-memory for now; persistence (e.g. via a settings repository) lands
/// in Step 10. Registered in both envs since it has no backend dependency.
/// Holds no subscriptions, so [close] is not overridden.
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
}
