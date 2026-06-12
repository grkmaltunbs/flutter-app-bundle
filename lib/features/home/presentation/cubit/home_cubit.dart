import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_stats.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_last_scan.dart';
import 'package:okey_acar_mi/features/history/domain/usecases/watch_scan_stats.dart';

part 'home_cubit.freezed.dart';
part 'home_state.dart';

/// Screen-scoped cubit feeding the home dashboard: the last scan (recent
/// card) and the aggregate stats (stats strip), both live.
///
/// Home is non-critical decoration around the scan CTA, so stream errors are
/// logged and the last state stands — there is no failure state. Holds two
/// subscriptions, so [close] is overridden.
@injectable
class HomeCubit extends Cubit<HomeState> {
  /// Creates a [HomeCubit] and subscribes immediately.
  HomeCubit(
    WatchLastScan watchLastScan,
    WatchScanStats watchScanStats,
    this._logger,
  ) : super(const HomeState()) {
    _lastScanSubscription = watchLastScan().listen(
      _onLastScan,
      onError: (Object error, StackTrace stackTrace) =>
          _logger.error('Home last-scan stream failed', error, stackTrace),
    );
    _statsSubscription = watchScanStats().listen(
      _onStats,
      onError: (Object error, StackTrace stackTrace) =>
          _logger.error('Home stats stream failed', error, stackTrace),
    );
  }

  final AppLogger _logger;

  late final StreamSubscription<Scan?> _lastScanSubscription;
  late final StreamSubscription<ScanStats> _statsSubscription;

  // First-arrival latches: [HomeState.ready] flips once both streams have
  // delivered (a null last scan is a legitimate first delivery).
  bool _lastScanArrived = false;
  bool _statsArrived = false;

  void _onLastScan(Scan? scan) {
    if (isClosed) return;
    _lastScanArrived = true;
    emit(
      state.copyWith(
        lastScan: scan,
        ready: _lastScanArrived && _statsArrived,
      ),
    );
  }

  void _onStats(ScanStats stats) {
    if (isClosed) return;
    _statsArrived = true;
    emit(
      state.copyWith(stats: stats, ready: _lastScanArrived && _statsArrived),
    );
  }

  @override
  Future<void> close() async {
    await _lastScanSubscription.cancel();
    await _statsSubscription.cancel();
    return super.close();
  }
}
