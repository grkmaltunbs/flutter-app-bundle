import 'package:flutter/material.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Ergonomic accessors on [BuildContext] for theme, localizations, and size.
extension ContextExtensions on BuildContext {
  /// The active [ColorScheme].
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// The active [TextTheme].
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// The localized strings for the current locale.
  ///
  /// Non-null because [AppLocalizations.localizationsDelegates] are registered
  /// at the [MaterialApp] root, so the lookup always resolves below it.
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// The screen size.
  ///
  /// Uses `MediaQuery.sizeOf` (subscribes only to size changes) per project
  /// hard rules — never `MediaQuery.of`.
  Size get mq => MediaQuery.sizeOf(this);
}
