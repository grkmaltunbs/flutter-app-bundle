part of 'history_bloc.dart';

/// Intent events for [HistoryBloc] (past-tense, no `BuildContext`).
///
/// The underscore-named cases are internal stream-relay events: only the
/// bloc's own subscriptions add them. The legacy `when`/`map` helpers are
/// disabled — they cannot be generated for private case names (their named
/// parameters would start with `_`), and this codebase pattern-matches
/// instead.
@Freezed(map: FreezedMapOptions.none, when: FreezedWhenOptions.none)
sealed class HistoryEvent with _$HistoryEvent {
  /// The screen opened — subscribe scans and counts.
  const factory HistoryEvent.started() = HistoryStarted;

  /// The user picked a verdict filter chip.
  const factory HistoryEvent.filterChanged(HistoryFilter filter) =
      HistoryFilterChanged;

  /// The list scrolled near its end — grow the page window.
  const factory HistoryEvent.loadMoreRequested() = HistoryLoadMoreRequested;

  /// The failure view's retry action — resubscribe everything.
  const factory HistoryEvent.retryRequested() = HistoryRetryRequested;

  /// Internal: the scans stream delivered the current window.
  const factory HistoryEvent._scansEmitted(List<Scan> scans) =
      _HistoryScansEmitted;

  /// Internal: the counts stream delivered fresh per-filter counts.
  const factory HistoryEvent._countsEmitted(ScanCounts counts) =
      _HistoryCountsEmitted;

  /// Internal: a watch stream errored.
  const factory HistoryEvent._streamFailed() = _HistoryStreamFailed;
}
