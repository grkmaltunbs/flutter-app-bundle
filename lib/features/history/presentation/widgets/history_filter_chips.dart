import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/features/history/domain/entities/history_filter.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_counts.dart';
import 'package:okey_acar_mi/features/history/presentation/blocs/history_bloc.dart';

/// The three verdict filter chips (All / Opened / Closed) with live counts,
/// ported from the design bundle's history chips.
///
/// Horizontally scrollable so long Turkish labels at textScale 2.0 shrink
/// nothing and overflow nowhere.
class HistoryFilterChips extends StatelessWidget {
  /// Creates a [HistoryFilterChips].
  const HistoryFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<HistoryBloc, HistoryState, (HistoryFilter, ScanCounts)>(
      selector: (state) => (state.filter, state.counts),
      builder: (context, data) {
        final (selected, counts) = data;
        final l10n = context.l10n;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                key: const ValueKey('history-filter-all'),
                label: l10n.historyFilterAll,
                count: counts.all,
                selected: selected == HistoryFilter.all,
                filter: HistoryFilter.all,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                key: const ValueKey('history-filter-opened'),
                label: l10n.historyFilterOpened,
                count: counts.opened,
                selected: selected == HistoryFilter.opened,
                filter: HistoryFilter.opened,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                key: const ValueKey('history-filter-closed'),
                label: l10n.historyFilterClosed,
                count: counts.closed,
                selected: selected == HistoryFilter.closed,
                filter: HistoryFilter.closed,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.filter,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final HistoryFilter filter;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bg = selected ? palette.ink : palette.surface;
    final fg = selected ? palette.surface : palette.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label $count',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.read<HistoryBloc>().add(
            HistoryEvent.filterChanged(filter),
          ),
          borderRadius: BorderRadius.circular(100),
          // The visual pill is compact (design: 8/12 padding); the
          // ConstrainedBox keeps the tap target >= 48dp around it.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: selected ? palette.ink : palette.line,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: context.textTheme.bodySmall?.copyWith(color: fg),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: AppTypography.monoStyle(
                        fontSize: 10,
                        color: fg.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
