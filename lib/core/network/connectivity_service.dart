import 'dart:async';

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

/// Closes the [FakeConnectivityService]'s stream controller when the DI
/// container resets (`getIt.reset()`).
///
/// A top-level adapter (instead of `@disposeMethod`) because the fake is
/// registered as [ConnectivityService], and the generated dispose callback is
/// typed against that interface.
void disposeFakeConnectivityService(ConnectivityService instance) =>
    (instance as FakeConnectivityService).dispose();

/// Demo [ConnectivityService]: stateful, in-memory, online by default.
///
/// [setOnline] is the demo/integration-test hook for driving offline → online
/// transitions on a simulator without touching real radios. [onlineStream]
/// replays the current state to every new listener, then every change
/// (mirroring `FakeAuthRepository`'s gap-free `Stream.multi` pattern).
@Environment('demo')
@LazySingleton(as: ConnectivityService, dispose: disposeFakeConnectivityService)
class FakeConnectivityService implements ConnectivityService {
  /// Creates a [FakeConnectivityService] in the online state.
  FakeConnectivityService();

  bool _online = true;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get onlineStream {
    // Gap-free replay: `async*` would yield the current value and only then
    // subscribe to the broadcast controller, dropping any emission landing in
    // that microtask window. Stream.multi subscribes synchronously on listen.
    return Stream<bool>.multi((listener) {
      listener
        ..add(_online)
        ..addStream(_controller.stream).ignore();
    });
  }

  @override
  Future<bool> isOnline() async => _online;

  /// Demo hook: drives the fake [online] or offline, emitting on every
  /// change (no-op when the state is unchanged, like the real transport).
  ///
  /// Deliberately a plain public member — the demo flavor's integration
  /// tests flip it at runtime to exercise offline banners and sync retries.
  void setOnline({required bool online}) {
    if (_online == online) return;
    _online = online;
    _controller.add(online);
  }

  /// Test seam: rewrites the state WITHOUT emitting on [onlineStream] —
  /// models a transport change the change stream never delivered (e.g. while
  /// the app was backgrounded), so the resume-time `ConnectivityCubit.refresh`
  /// probe is testable in isolation from the stream path.
  @visibleForTesting
  // A method (not a setter): mirrors setOnline's named-bool call-site shape.
  // ignore: use_setters_to_change_properties
  void setOnlineSilently({required bool online}) => _online = online;

  /// Restores the fake to its default online state.
  void reset() => setOnline(online: true);

  /// Closes the change controller; called via
  /// [disposeFakeConnectivityService] when the DI container resets.
  void dispose() => _controller.close();
}
