import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/storage/preferences_store.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';

/// DI bindings for the settings feature.
///
/// Lives in `presentation/` deliberately: the module constructs
/// [SettingsCubit] (a presentation type), and a `data/` placement would
/// require an illegal data→presentation import.
@module
abstract class SettingsBindings {
  /// A [SettingsCubit] hydrated from (and persisting to) [store].
  @injectable
  SettingsCubit settingsCubit(PreferencesStore store) =>
      SettingsCubit(store: store);
}
