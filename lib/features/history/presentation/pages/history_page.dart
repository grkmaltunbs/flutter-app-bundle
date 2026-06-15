import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/ads/ad_placement.dart';
import 'package:okey_acar_mi/core/ads/presentation/ad_banner.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/format/scan_timestamp.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/core/widgets/scan_card.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/presentation/blocs/history_bloc.dart';
import 'package:okey_acar_mi/features/history/presentation/scan_card_mapping.dart';
import 'package:okey_acar_mi/features/history/presentation/widgets/history_filter_chips.dart';
import 'package:okey_acar_mi/features/history/presentation/widgets/history_no_results_view.dart';
import 'package:okey_acar_mi/features/result/domain/entities/result_args.dart';

/// History tab — the owner's past scans: filter chips, the paginated card
/// list, and tap-to-replay onto the result screen.
class HistoryPage extends StatelessWidget {
  /// Creates a [HistoryPage].
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HistoryBloc>(
      create: (_) => getIt<HistoryBloc>()..add(const HistoryEvent.started()),
      child: const HistoryView(),
    );
  }
}

/// The history screen view (assumes a [HistoryBloc] is provided above it):
/// eyebrow + serif header, then the status-switched body.
class HistoryView extends StatelessWidget {
  /// Creates a [HistoryView].
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Eyebrow(l10n.historyEyebrow),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                l10n.historyTitle,
                style: context.textTheme.displaySmall,
              ),
            ),
            Expanded(
              child:
                  BlocSelector<
                    HistoryBloc,
                    HistoryState,
                    (HistoryStatus, bool)
                  >(
                    selector: (state) => (state.status, state.isEmpty),
                    builder: (context, data) {
                      final (status, isEmpty) = data;
                      return switch (status) {
                        HistoryStatus.loading => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        HistoryStatus.failure => const _HistoryErrorView(),
                        HistoryStatus.ready =>
                          isEmpty
                              ? const _HistoryEmptyView()
                              : const _HistoryList(),
                      };
                    },
                  ),
            ),
            // Banner self-hides for premium and reserves a fixed height, so it
            // never overlaps the list above.
            const SafeArea(
              top: false,
              child: AdBanner(placement: AdPlacement.history),
            ),
          ],
        ),
      ),
    );
  }
}

/// The live list body: chips, then the scan cards (or the no-results view),
/// with near-end pagination.
class _HistoryList extends StatelessWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistoryBloc, HistoryState>(
      buildWhen: (a, b) =>
          a.scans != b.scans ||
          a.loadingMore != b.loadingMore ||
          a.isNoResults != b.isNoResults,
      builder: (context, state) {
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            final metrics = notification.metrics;
            if (metrics.maxScrollExtent > 0 &&
                metrics.pixels > 0.8 * metrics.maxScrollExtent) {
              context.read<HistoryBloc>().add(
                const HistoryEvent.loadMoreRequested(),
              );
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(child: HistoryFilterChips()),
              ),
              if (state.isNoResults)
                const SliverToBoxAdapter(child: HistoryNoResultsView())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  sliver: SliverList.builder(
                    itemCount: state.scans.length + (state.loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.scans.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HistoryScanCard(scan: state.scans[index]),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One scan row: maps the domain [Scan] to the primitives-only [ScanCard]
/// (bare time today per the design — no "Bugün" prefix in the list).
class _HistoryScanCard extends StatelessWidget {
  const _HistoryScanCard({required this.scan});

  final Scan scan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (pillLabel, tone) = scanVerdictPill(l10n, scan.summary);
    final timestamp = formatScanTimestamp(
      at: scan.createdAt,
      now: getIt<Clock>().now(),
      localeName: l10n.localeName,
      yesterdayLabel: l10n.timeYesterday,
    );
    final modeLabel = scan.gameMode == GameMode.oneZeroOne
        ? l10n.gameMode101Title
        : l10n.gameModeOkeyTitle;
    return ScanCard(
      key: ValueKey('scan-card-${scan.id}'),
      timestamp: timestamp,
      modeLabel: modeLabel,
      pillLabel: pillLabel,
      tone: tone,
      tiles: scanCardTiles(scan),
      semanticsLabel: l10n.scanCardSemantics(timestamp, pillLabel),
      onTap: () =>
          context.push(AppRoutes.result, extra: ResultArgs.replay(scan)),
    );
  }
}

/// The no-scans-at-all empty state (kept from the pre-Step-9 screen).
class _HistoryEmptyView extends StatelessWidget {
  const _HistoryEmptyView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Icon(Icons.history_outlined, size: 44, color: palette.faint),
          const SizedBox(height: 16),
          Text(
            l10n.historyEmptyTitle,
            textAlign: TextAlign.center,
            style: context.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.historyEmptyBody,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.historyEmptyCta,
            icon: Icons.photo_camera_outlined,
            onPressed: () => context.push(AppRoutes.camera),
          ),
        ],
      ),
    );
  }
}

/// The stream-failure view with its retry escape.
class _HistoryErrorView extends StatelessWidget {
  const _HistoryErrorView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 44,
            color: context.palette.bad,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.historyLoadFailedTitle,
            textAlign: TextAlign.center,
            style: context.textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            key: const ValueKey('history-retry'),
            label: l10n.historyRetry,
            icon: Icons.refresh,
            onPressed: () => context.read<HistoryBloc>().add(
              const HistoryEvent.retryRequested(),
            ),
          ),
        ],
      ),
    );
  }
}
