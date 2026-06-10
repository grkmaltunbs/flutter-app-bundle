import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/widgets/circle_icon_button.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// A route whose real screen is built in a later plan step.
///
/// Used by the router so every navigation target in the app shell is reachable
/// (and overflow-safe) before the owning feature exists. Each value maps to a
/// localized screen title; the body is a friendly "coming soon" placeholder.
enum PlaceholderScreen {
  /// Camera capture (Step 4).
  camera,

  /// Detection in progress (Step 5).
  analyzing,

  /// Review & correct + indicator (Step 6).
  review,

  /// Result / verdict (Step 8).
  result,

  /// Remove-ads paywall (Step 11).
  paywall,
}

/// A minimal, overflow-safe placeholder shown for not-yet-built routes.
class PlaceholderPage extends StatelessWidget {
  /// Creates a [PlaceholderPage] for [screen].
  const PlaceholderPage({required this.screen, super.key});

  /// Which not-yet-built screen this placeholder stands in for.
  final PlaceholderScreen screen;

  String _title(AppLocalizations l10n) => switch (screen) {
    PlaceholderScreen.camera => l10n.screenCameraTitle,
    PlaceholderScreen.analyzing => l10n.screenAnalyzingTitle,
    PlaceholderScreen.review => l10n.screenReviewTitle,
    PlaceholderScreen.result => l10n.screenResultTitle,
    PlaceholderScreen.paywall => l10n.screenPaywallTitle,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final canPop = context.canPop();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  // Always offer an escape: pop when there is a back stack
                  // (the normal push flow), otherwise route into the shell so a
                  // deep-linked / cold-start-restored placeholder can't strand
                  // the user (these routes sit outside the bottom-nav shell).
                  CircleIconButton(
                    icon: canPop ? Icons.arrow_back : Icons.home_outlined,
                    semanticLabel: canPop ? l10n.commonBack : l10n.navHome,
                    onPressed: () =>
                        canPop ? context.pop() : context.go(AppRoutes.home),
                  ),
                  Expanded(
                    child: Center(child: Eyebrow(_title(l10n))),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.construction_outlined,
                        size: 40,
                        color: palette.faint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.placeholderComingSoon,
                        textAlign: TextAlign.center,
                        style: context.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.placeholderBody,
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
