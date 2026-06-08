import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';

/// Placeholder landing screen for Step 0 (boot-to-blank).
///
/// Shows the app title in the Instrument Serif display style. Overflow-safe at
/// any size and text scale: centered, padded, and scaled via [FittedBox] with
/// no fixed dimensions. The real Home screen arrives in Step 2.
class HomeStubPage extends StatelessWidget {
  /// Creates a [HomeStubPage].
  const HomeStubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                context.l10n.appTitle,
                textAlign: TextAlign.center,
                style: context.textTheme.displayMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
