part of 'history_bloc.dart';

/// The load phase of the history screen.
enum HistoryStatus {
  /// First subscription round-trip still in flight.
  loading,

  /// Streams are live; the list/empty/no-results body renders.
  ready,

  /// A watch stream errored; the retry view renders.
  failure,
}

/// The history screen state: load status, the active filter, the visible
/// scan window, chip counts, pagination, and the offline flag.
///
/// Has eight fields — consumers must scope rebuilds with `BlocSelector` /
/// `buildWhen` per the project performance rules.
@freezed
abstract class HistoryState with _$HistoryState {
  /// Creates a [HistoryState].
  const factory HistoryState({
    /// The load phase.
    @Default(HistoryStatus.loading) HistoryStatus status,

    /// The active verdict filter.
    @Default(HistoryFilter.all) HistoryFilter filter,

    /// The visible scans (newest first, capped at the page window).
    @Default(<Scan>[]) List<Scan> scans,

    /// Per-filter row counts for the chips.
    @Default(ScanCounts(all: 0, opened: 0, closed: 0)) ScanCounts counts,

    /// How many [HistoryBloc.pageSize] pages the window spans.
    @Default(1) int pagesRequested,

    /// Whether another page may exist beyond the window.
    @Default(true) bool hasMore,

    /// Whether a grow-the-window request is in flight.
    @Default(false) bool loadingMore,

    /// Whether the device is online (offline shows the local-history banner).
    @Default(true) bool online,
  }) = _HistoryState;

  const HistoryState._();

  /// True when the owner has no scans at all (the inviting empty state).
  bool get isEmpty => status == HistoryStatus.ready && counts.all == 0;

  /// True when scans exist but none match the active filter.
  bool get isNoResults =>
      status == HistoryStatus.ready && scans.isEmpty && counts.all > 0;
}
