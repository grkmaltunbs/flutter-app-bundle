import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Reports network reachability.
///
/// Consumers observe [onlineStream] for live changes and call [isOnline] for a
/// one-shot check. `true` means at least one active transport is available.
abstract class ConnectivityService {
  /// Emits `true` when online and `false` when offline, on every change.
  Stream<bool> get onlineStream;

  /// Resolves the current connectivity state once.
  Future<bool> isOnline();
}

/// Production [ConnectivityService] backed by `connectivity_plus`.
@Environment('prod')
@LazySingleton(as: ConnectivityService)
class ConnectivityServiceImpl implements ConnectivityService {
  /// Creates a [ConnectivityServiceImpl] (injectable: no parameters).
  ConnectivityServiceImpl() : _connectivity = Connectivity();

  /// Creates a [ConnectivityServiceImpl] with an injected connectivity client,
  /// for tests.
  @visibleForTesting
  ConnectivityServiceImpl.withConnectivity(this._connectivity);

  final Connectivity _connectivity;

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  @override
  Stream<bool> get onlineStream =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  @override
  Future<bool> isOnline() async =>
      _isOnline(await _connectivity.checkConnectivity());
}

/// Demo [ConnectivityService] that is always online.
@Environment('demo')
@LazySingleton(as: ConnectivityService)
class FakeConnectivityService implements ConnectivityService {
  /// Creates a [FakeConnectivityService].
  const FakeConnectivityService();

  @override
  Stream<bool> get onlineStream => Stream<bool>.value(true);

  @override
  Future<bool> isOnline() async => true;
}
