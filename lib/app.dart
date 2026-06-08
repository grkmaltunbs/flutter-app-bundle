import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// The application root.
///
/// Wires routing, theming, and localization. The active theme (light / dark /
/// system / felt), tile style, and accent are driven by [SettingsCubit], which
/// is provided above [MaterialApp.router].
class App extends StatelessWidget {
  /// Creates an [App].
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsCubit>(
      create: (_) => getIt<SettingsCubit>(),
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final router = getIt<AppRouter>();
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final accent = settings.accent;
        final tileStyle = settings.tileStyle;
        final isFelt = settings.themeChoice == ThemeChoice.felt;

        final ThemeData theme;
        final ThemeData darkTheme;
        final ThemeMode themeMode;
        if (isFelt) {
          final felt = AppTheme.felt(accent, tileStyle);
          theme = felt;
          darkTheme = felt;
          themeMode = ThemeMode.light;
        } else {
          theme = AppTheme.light(accent, tileStyle);
          darkTheme = AppTheme.dark(accent, tileStyle);
          themeMode = switch (settings.themeChoice) {
            ThemeChoice.light => ThemeMode.light,
            ThemeChoice.dark => ThemeMode.dark,
            ThemeChoice.system => ThemeMode.system,
            ThemeChoice.felt => ThemeMode.light,
          };
        }

        return MaterialApp.router(
          title: '101 Okey Açar Mı',
          theme: theme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr'), Locale('en')],
          routerConfig: router.config,
        );
      },
    );
  }
}
