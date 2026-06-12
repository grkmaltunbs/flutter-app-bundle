import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';

/// Shown when scans exist but none match the active filter chip — distinct
/// from the no-scans-at-all empty state.
class HistoryNoResultsView extends StatelessWidget {
  /// Creates a [HistoryNoResultsView].
  const HistoryNoResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        children: [
          Icon(Icons.filter_alt_off_outlined, size: 44, color: palette.faint),
          const SizedBox(height: 16),
          Text(
            l10n.historyNoResultsTitle,
            textAlign: TextAlign.center,
            style: context.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.historyNoResultsBody,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}
