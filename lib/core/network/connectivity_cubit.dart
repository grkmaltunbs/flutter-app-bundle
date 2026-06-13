import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';

/// Live reachability for the global offline banner: `true` = online.
///
/// Starts optimistically online, subscribes to the [ConnectivityService]
/// change stream, and fires an immediate [refresh] so the first real answer
/// lands without waiting for a transport change. Stream errors are logged and
/// the last state retained — connectivity is cosmetic and must never crash a
/// screen. Scoped to the app shell via `BlocProvider(create:)`.
@injectable
class ConnectivityCubit extends Cubit<bool> {
  /// Creates a [ConnectivityCubit] subscribed to the given service.
  ConnectivityCubit(this._connectivity, this._logger) : super(true) {
    _subscription = _connectivity.onlineStream.listen(
      (online) {
        if (!isClosed) emit(online);
      },
      onError: (Object error, StackTrace stackTrace) =>
          _logger.error('Connectivity stream failed', error, stackTrace),
    );
    unawaited(refresh());
  }

  final ConnectivityService _connectivity;
  final AppLogger _logger;
  late final StreamSubscription<bool> _subscription;

  /// Re-checks connectivity once (e.g. on app resume, where a transport
  /// change while backgrounded may not have reached the stream).
  Future<void> refresh() async {
    final bool online;
    try {
      online = await _connectivity.isOnline();
    } on Exception catch (error, stackTrace) {
      // A failed probe keeps the last known state; never crashes.
      _logger.error('Connectivity refresh failed', error, stackTrace);
      return;
    }
    if (!isClosed) emit(online);
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
