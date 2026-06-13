import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/history/domain/entities/history_filter.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_counts.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_scan_counts.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_scans.dart';

part 'history_bloc.freezed.dart';
part 'history_event.dart';
part 'history_state.dart';

/// Screen-scoped bloc for the history screen: the filtered, paginated scan
/// list and the per-filter counts (chips). (Offline display is global now —
/// the shell-scoped `ConnectivityCubit` drives the shared banner.)
///
/// Pagination is page-window resubscription: `loadMoreRequested` grows the
/// watch limit by [HistoryBloc.pageSize] and resubscribes, so the single
/// stream stays live for inserts/sync updates across the whole window.
/// Holds two subscriptions, so [close] is overridden.
@injectable
class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  /// Creates a [HistoryBloc]; subscribe by adding [HistoryEvent.started].
  HistoryBloc(
    this._watchScans,
    this._watchCounts,
    this._logger,
  ) : super(const HistoryState()) {
    on<HistoryStarted>(_onStarted);
    on<HistoryFilterChanged>(_onFilterChanged);
    on<HistoryLoadMoreRequested>(
      _onLoadMoreRequested,
      transformer: droppable(),
    );
    on<HistoryRetryRequested>(_onRetryRequested);
    on<_HistoryScansEmitted>(_onScansEmitted);
    on<_HistoryCountsEmitted>(_onCountsEmitted);
    on<_HistoryStreamFailed>(_onStreamFailed);
  }

  /// Scans fetched per page window.
  static const int pageSize = 20;

  final WatchScans _watchScans;
  final WatchScanCounts _watchCounts;
  final AppLogger _logger;

  StreamSubscription<List<Scan>>? _scansSubscription;
  StreamSubscription<ScanCounts>? _countsSubscription;

  // First-arrival latches: the screen leaves `loading` only once both the
  // scans and the counts streams have delivered.
  bool _scansArrived = false;
  bool _countsArrived = false;

  void _onStarted(HistoryStarted event, Emitter<HistoryState> emit) {
    _subscribeAll();
  }

  void _onRetryRequested(
    HistoryRetryRequested event,
    Emitter<HistoryState> emit,
  ) {
    _scansArrived = false;
    _countsArrived = false;
    emit(state.copyWith(status: HistoryStatus.loading));
    _subscribeAll();
  }

  void _onFilterChanged(
    HistoryFilterChanged event,
    Emitter<HistoryState> emit,
  ) {
    if (event.filter == state.filter) return;
    emit(
      state.copyWith(
        filter: event.filter,
        pagesRequested: 1,
        hasMore: true,
        loadingMore: false,
      ),
    );
    _subscribeScans();
  }

  void _onLoadMoreRequested(
    HistoryLoadMoreRequested event,
    Emitter<HistoryState> emit,
  ) {
    if (!state.hasMore || state.loadingMore) return;
    emit(
      state.copyWith(
        loadingMore: true,
        pagesRequested: state.pagesRequested + 1,
      ),
    );
    _subscribeScans();
  }

  void _onScansEmitted(
    _HistoryScansEmitted event,
    Emitter<HistoryState> emit,
  ) {
    _scansArrived = true;
    emit(
      state.copyWith(
        scans: event.scans,
        hasMore: event.scans.length >= pageSize * state.pagesRequested,
        loadingMore: false,
        status: _readyOr(state.status),
      ),
    );
  }

  void _onCountsEmitted(
    _HistoryCountsEmitted event,
    Emitter<HistoryState> emit,
  ) {
    _countsArrived = true;
    emit(
      state.copyWith(counts: event.counts, status: _readyOr(state.status)),
    );
  }

  void _onStreamFailed(
    _HistoryStreamFailed event,
    Emitter<HistoryState> emit,
  ) {
    // Stop the surviving watchers so a late emission cannot flip a visible
    // failure screen back to ready behind the user; retry resubscribes.
    unawaited(_scansSubscription?.cancel());
    unawaited(_countsSubscription?.cancel());
    emit(state.copyWith(status: HistoryStatus.failure));
  }

  /// Leaves `loading` once both first arrivals landed; never resurrects a
  /// `failure` (only an explicit retry does).
  HistoryStatus _readyOr(HistoryStatus current) =>
      current == HistoryStatus.loading && _scansArrived && _countsArrived
      ? HistoryStatus.ready
      : current;

  void _subscribeAll() {
    _subscribeScans();
    unawaited(_countsSubscription?.cancel());
    _countsSubscription = _watchCounts().listen(
      (counts) {
        if (!isClosed) add(HistoryEvent._countsEmitted(counts));
      },
      onError: (Object error, StackTrace stackTrace) {
        _logger.error('History counts stream failed', error, stackTrace);
        if (!isClosed) add(const HistoryEvent._streamFailed());
      },
    );
  }

  void _subscribeScans() {
    unawaited(_scansSubscription?.cancel());
    _scansSubscription =
        _watchScans(
          filter: state.filter,
          limit: pageSize * state.pagesRequested,
        ).listen(
          (scans) {
            if (!isClosed) add(HistoryEvent._scansEmitted(scans));
          },
          onError: (Object error, StackTrace stackTrace) {
            _logger.error('History scans stream failed', error, stackTrace);
            if (!isClosed) add(const HistoryEvent._streamFailed());
          },
        );
  }

  @override
  Future<void> close() async {
    await _scansSubscription?.cancel();
    await _countsSubscription?.cancel();
    return super.close();
  }
}
