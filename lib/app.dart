import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// The application root.
///
/// Wires routing, theming, and localization. Felt theme + accent picker land in
/// Step 1, so `themeMode` is fixed to `system` for now.
class App extends StatelessWidget {
  /// Creates an [App].
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final router = getIt<AppRouter>();
    return MaterialApp.router(
      title: '101 Okey Açar Mı',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // themeMode defaults to ThemeMode.system; the felt theme + accent picker
      // override this in Step 1.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr'), Locale('en')],
      routerConfig: router.config,
    );
  }
}
