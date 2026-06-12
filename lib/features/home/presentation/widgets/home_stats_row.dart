import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_radii.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_stats.dart';

/// The three stat cards under the last-scan card (design `StatCard` row):
/// total scans, open rate (accent), and best score.
class HomeStatsRow extends StatelessWidget {
  /// Creates a [HomeStatsRow] for [stats].
  const HomeStatsRow({required this.stats, super.key});

  /// The aggregate stats to render.
  final ScanStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // IntrinsicHeight (three tiny children, negligible cost) + stretch keeps
    // the cards equal-height like the design's flex row, while staying finite
    // inside the home screen's unbounded-height scroll column.
    return IntrinsicHeight(
      child: Row(
        key: const ValueKey('home-stats'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              label: l10n.homeStatsTotalScans,
              value: '${stats.total}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: l10n.homeStatsOpenRate,
              value: '${stats.openRatePercent}%',
              accent: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: l10n.homeStatsBest,
              value: '${stats.best}',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.monoStyle(
              fontSize: 9.5,
              color: palette.muted,
              letterSpacing: 0.76, // ~0.08em at 9.5px
            ),
          ),
          const SizedBox(height: 6),
          // scaleDown: the mono value never overflows its third-width card,
          // even at textScale 2.0 on the smallest matrix size.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: AppTypography.monoStyle(
                fontSize: 22,
                color: accent ? palette.accent : palette.ink,
                letterSpacing: -0.44, // ~-0.02em at 22px
              ),
            ),
          ),
        ],
      ),
    );
  }
}
