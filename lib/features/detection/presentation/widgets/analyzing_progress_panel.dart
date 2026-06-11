import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_stage.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// The analyzing screen's bottom panel: localized stage label, determinate
/// progress bar, and the mono "7/21" tile counter.
class AnalyzingProgressPanel extends StatelessWidget {
  /// Creates an [AnalyzingProgressPanel].
  const AnalyzingProgressPanel({
    required this.stage,
    required this.revealedCount,
    this.totalTiles,
    this.completed = false,
    super.key,
  });

  /// The pipeline's current stage.
  final DetectionStage stage;

  /// How many tiles have been revealed so far.
  final int revealedCount;

  /// The located tile count, once known (drives the counter + progress).
  final int? totalTiles;

  /// Pins the bar at 100% for the success frame before navigation.
  final bool completed;

  /// Determinate progress: a stage floor, lifted by the tile reveal.
  double get _fraction {
    if (completed) return 1;
    final base = switch (stage) {
      DetectionStage.preparing => 0.05,
      DetectionStage.locatingRack => 0.15,
      DetectionStage.readingTiles => 0.2,
      DetectionStage.aggregatingFrames => 0.25,
      DetectionStage.finalizing => 0.95,
    };
    final total = totalTiles;
    if (total == null || total == 0) return base;
    final reveal = 0.2 + 0.7 * (revealedCount / total).clamp(0.0, 1.0);
    return reveal > base ? reveal : base;
  }

  String _stageLabel(AppLocalizations l10n) => switch (stage) {
    DetectionStage.preparing => l10n.analyzingStagePreparing,
    DetectionStage.locatingRack => l10n.analyzingStageLocatingRack,
    DetectionStage.readingTiles => l10n.analyzingStageReadingTiles,
    DetectionStage.aggregatingFrames => l10n.analyzingStageAggregatingFrames,
    DetectionStage.finalizing => l10n.analyzingStageFinalizing,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = context.palette.accent;
    final total = totalTiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The serif stage moment from the design; scaleDown keeps the longest
        // Turkish label on one line at textScale 2.0 on the smallest matrix
        // size instead of overflowing.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            _stageLabel(l10n),
            maxLines: 1,
            style: AppTypography.serifStyle(
              fontSize: 26,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: _fraction,
            minHeight: 3,
            color: accent,
            backgroundColor: Colors.white12,
          ),
        ),
        if (total != null) ...[
          const SizedBox(height: 10),
          Text(
            l10n.analyzingTileProgress(revealedCount, total),
            style: AppTypography.monoStyle(
              fontSize: 11,
              color: Colors.white54,
              letterSpacing: 0.88,
            ),
          ),
        ],
      ],
    );
  }
}
