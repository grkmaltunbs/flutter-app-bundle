import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';

/// Splash / brand entry — the 1-0-1 wordmark, the "Açar mı?" headline, and the
/// two entry CTAs (continue → login, or enter as guest → home).
class SplashPage extends StatelessWidget {
  /// Creates a [SplashPage].
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Eyebrow(l10n.splashEyebrow),
                      const SizedBox(height: 20),
                      const _Wordmark(),
                      const SizedBox(height: 28),
                      // FittedBox keeps the editorial serif from overflowing on
                      // the smallest screen at textScale 2.0.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.splashHeadline,
                              style: AppTypography.serifStyle(
                                fontSize: 60,
                                color: palette.ink,
                                fontStyle: FontStyle.italic,
                                letterSpacing: -1.5,
                              ),
                            ),
                            Text(
                              l10n.splashSubhead,
                              style: AppTypography.serifStyle(
                                fontSize: 42,
                                color: palette.muted,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.splashBody,
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: palette.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                key: const ValueKey('splash-continue'),
                label: l10n.splashContinue,
                icon: Icons.arrow_forward,
                fullWidth: true,
                onPressed: () => context.push(AppRoutes.login),
              ),
              const SizedBox(height: 10),
              GhostButton(
                key: const ValueKey('splash-guest'),
                label: l10n.splashGuest,
                fullWidth: true,
                onPressed: () => context.go(AppRoutes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 1-0-1 wordmark rendered as three cream letter tiles.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LetterTile(char: '1', color: TileColor.red),
        SizedBox(width: 4),
        _LetterTile(char: '0', color: TileColor.black),
        SizedBox(width: 4),
        _LetterTile(char: '1', color: TileColor.blue),
      ],
    );
  }
}

/// A single cream tile face carrying a serif glyph (used for the wordmark).
class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.char, required this.color});

  final String char;
  final TileColor color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final glyphColor = switch (color) {
      TileColor.red => palette.tileRed,
      TileColor.black => palette.tileBlack,
      TileColor.yellow => palette.tileYellow,
      TileColor.blue => palette.tileBlue,
      TileColor.joker => palette.tileBlack,
    };
    // Fixed-size physical object; never scale the glyph with the OS text scale.
    return MediaQuery.withNoTextScaling(
      child: Container(
        width: 48,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.tileFace, palette.tileFaceEdge],
          ),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          char,
          style: AppTypography.serifStyle(fontSize: 34, color: glyphColor),
        ),
      ),
    );
  }
}
