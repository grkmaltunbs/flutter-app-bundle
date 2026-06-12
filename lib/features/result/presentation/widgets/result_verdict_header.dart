import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

/// The verdict moment: eyebrow, the big serif verdict, the score (or
/// tiles-to-win) row, and the path caption — switched on [SolveVerdict]
/// exclusively. Scale-in entrance, rendered directly under reduce-motion.
class ResultVerdictHeader extends StatelessWidget {
  /// Creates a [ResultVerdictHeader] for [verdict].
  const ResultVerdictHeader({required this.verdict, super.key});

  /// The solver's sealed answer.
  final SolveVerdict verdict;

  @override
  Widget build(BuildContext context) {
    return _ScaleIn(
      child: switch (verdict) {
        Opens101(:final score, :final via) => _Verdict101(
          opens: true,
          score: score,
          caption: via == OpenPath.pairs
              ? context.l10n.resultOpensViaPairs
              : null,
        ),
        DoesNotOpen101(:final score, :final pointsShort) => _Verdict101(
          opens: false,
          score: score,
          caption: context.l10n.resultPointsShort(pointsShort),
        ),
        OkeyOutcome(:final tilesToWin, :final via) => _VerdictOkey(
          tilesToWin: tilesToWin,
          caption: via == OkeyPath.sevenPairs
              ? context.l10n.resultOkeyViaSevenPairs
              : null,
        ),
      },
    );
  }
}

/// The 101-mode verdict: Açar / Açmaz with the score against 101.
class _Verdict101 extends StatelessWidget {
  const _Verdict101({
    required this.opens,
    required this.score,
    this.caption,
  });

  final bool opens;
  final int score;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(
          opens ? l10n.resultOpensEyebrow : l10n.resultClosesEyebrow,
          color: opens ? palette.good : palette.warn,
        ),
        const SizedBox(height: 6),
        _BigVerdictText(
          text: opens ? l10n.resultOpensVerdict : l10n.resultClosesVerdict,
          color: opens ? palette.ink : palette.muted,
        ),
        const SizedBox(height: 14),
        _MonoFigureRow(
          label: l10n.resultScoreLabel,
          value: '$score',
          valueColor: opens ? palette.good : palette.bad,
          suffix: l10n.resultScoreOutOf,
        ),
        if (caption != null) _VerdictCaption(text: caption!),
      ],
    );
  }
}

/// The okey-mode verdict: best hand + tiles-to-win (never Açar/Açmaz).
class _VerdictOkey extends StatelessWidget {
  const _VerdictOkey({required this.tilesToWin, this.caption});

  final int tilesToWin;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final wins = tilesToWin == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(
          l10n.resultOkeyEyebrow,
          color: wins ? palette.good : palette.muted,
        ),
        const SizedBox(height: 6),
        _BigVerdictText(
          text: wins
              ? l10n.resultOkeyWin
              : l10n.resultOkeyTilesToWinHeadline(tilesToWin),
          color: palette.ink,
        ),
        const SizedBox(height: 14),
        _MonoFigureRow(
          label: l10n.resultOkeyTilesToWinLabel,
          value: '$tilesToWin',
          valueColor: wins ? palette.good : palette.ink,
        ),
        if (caption != null) _VerdictCaption(text: caption!),
      ],
    );
  }
}

/// The big serif italic verdict line.
///
/// Display art: rendered with [TextScaler.noScaling] (the eyebrow, figures,
/// and captions still scale) inside a width-bounded `FittedBox(scaleDown)`,
/// so it can shrink but never overflow.
class _BigVerdictText extends StatelessWidget {
  const _BigVerdictText({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          textScaler: TextScaler.noScaling,
          style: AppTypography.serifStyle(
            fontSize: 88,
            height: 0.9,
            letterSpacing: -3.52, // −0.04em at 88px.
            fontStyle: FontStyle.italic,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// The mono figure row: label, big value, optional faint suffix — baseline
/// aligned, shrunk as one unit if it would overflow.
class _MonoFigureRow extends StatelessWidget {
  const _MonoFigureRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.suffix,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              label,
              style: AppTypography.monoStyle(
                color: palette.muted,
                letterSpacing: 0.28, // 0.02em at 14px.
              ),
            ),
            const SizedBox(width: 14),
            Text(
              value,
              style: AppTypography.monoStyle(
                fontSize: 32,
                color: valueColor,
                letterSpacing: -0.64, // −0.02em at 32px.
              ),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 14),
              Text(
                suffix!,
                style: AppTypography.monoStyle(color: palette.faint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Muted caption under the figure row (points short / via pairs / via
/// seven pairs).
class _VerdictCaption extends StatelessWidget {
  const _VerdictCaption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.palette.muted,
        ),
      ),
    );
  }
}

/// Scale-in (0.96 → 1) + fade entrance over ~250ms; renders the child
/// directly when animations are disabled (reduce-motion).
class _ScaleIn extends StatelessWidget {
  const _ScaleIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
      ),
    );
  }
}
