import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/app_card.dart';
import 'package:okey_acar_mi/core/widgets/circle_icon_button.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/core/widgets/meld.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/core/widgets/tile_data.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// How-it-works tutorial: a serif title, three numbered step cards, a worked
/// example built from real [Meld] widgets, and a dismiss CTA.
class TutorialPage extends StatelessWidget {
  /// Creates a [TutorialPage].
  const TutorialPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = <(String, String, String)>[
      ('01', l10n.tutorialStep1Title, l10n.tutorialStep1Body),
      ('02', l10n.tutorialStep2Title, l10n.tutorialStep2Body),
      ('03', l10n.tutorialStep3Title, l10n.tutorialStep3Body),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    semanticLabel: l10n.commonBack,
                    onPressed: () => context.pop(),
                  ),
                  Expanded(child: Center(child: Eyebrow(l10n.tutorialEyebrow))),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        l10n.tutorialTitle,
                        style: context.textTheme.displaySmall,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final (n, title, body) in steps) ...[
                      _StepCard(number: n, title: title, body: body),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    Eyebrow(l10n.tutorialExampleEyebrow),
                    const SizedBox(height: 12),
                    _ExampleCard(l10n: l10n),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      key: const ValueKey('tutorial-done'),
                      label: l10n.tutorialDone,
                      fullWidth: true,
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              number,
              style: AppTypography.monoStyle(
                fontSize: 13,
                color: palette.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tutorialExampleIntro,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.palette.muted,
            ),
          ),
          const SizedBox(height: 12),
          Meld(
            label: l10n.tutorialMeldSetLabel,
            score: 28,
            tiles: const [
              TileData(color: TileColor.red, number: 7),
              TileData(color: TileColor.black, number: 7),
              TileData(color: TileColor.yellow, number: 7),
              TileData(color: TileColor.blue, number: 7),
            ],
          ),
          const SizedBox(height: 12),
          Meld(
            label: l10n.tutorialMeldRunLabel,
            score: 55,
            tiles: const [
              TileData(color: TileColor.blue, number: 9),
              TileData(color: TileColor.blue, number: 10),
              TileData(color: TileColor.blue, number: 11),
              TileData(color: TileColor.blue, number: 12),
              TileData(color: TileColor.blue, number: 13),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: context.palette.line, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Eyebrow(l10n.tutorialTotalLabel)),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    l10n.tutorialTotalValue,
                    style: AppTypography.monoStyle(
                      fontSize: 16,
                      color: context.palette.good,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
