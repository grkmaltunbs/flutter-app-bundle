import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// The application root.
///
/// Wires routing, theming, and localization. The active theme (light / dark /
/// system / felt), tile style, and accent are driven by [SettingsCubit]; the
/// session is driven by the app-scoped [AuthBloc] (eagerly created so the
/// session restore starts immediately). Both are provided above
/// [MaterialApp.router].
class App extends StatelessWidget {
  /// Creates an [App].
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(create: (_) => getIt<SettingsCubit>()),
        BlocProvider<AuthBloc>(
          lazy: false,
          create: (_) => getIt<AuthBloc>()..add(const AuthEvent.started()),
        ),
        BlocProvider<SubscriptionBloc>(
          lazy: false,
          create: (_) =>
              getIt<SubscriptionBloc>()..add(const SubscriptionEvent.started()),
        ),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Re-read the entitlement when the app regains the foreground: a renewal,
    // restore, or cancellation may have happened while backgrounded (e.g. via
    // the system subscription-management sheet) without the live stream
    // delivering it.
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<SubscriptionBloc>().add(
        const SubscriptionEvent.refreshRequested(),
      ),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = getIt<AppRouter>();
    return BlocBuilder<SettingsCubit, SettingsState>(
      // gameMode affects neither theme nor locale; rebuilding (and recomputing
      // every ThemeData) on a mode toggle is wasted work. Per the >3-field
      // rule, scope rebuilds to the fields this builder actually reads.
      buildWhen: (a, b) =>
          a.themeChoice != b.themeChoice ||
          a.tileStyle != b.tileStyle ||
          a.accent != b.accent ||
          a.language != b.language,
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
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          restorationScopeId: 'app',
          theme: theme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          // null ⇒ follow the platform locale (resolved vs supportedLocales).
          locale: settings.language.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr'), Locale('en')],
          routerConfig: router.config,
        );
      },
    );
  }
}
