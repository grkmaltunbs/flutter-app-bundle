import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../presence.dart';

/// The Mac's heartbeat: `hosts/{hostId}` every half minute while the app
/// runs — seen at (server time), the name, the app and CLI versions, the
/// open projects and which of them has a session — and once more with
/// `stopping: true` on a clean quit, so the phone says "Mac stopped" at
/// once instead of "unreachable" ninety seconds later.
class HostPresence extends ChangeNotifier {
  HostPresence({required this.db, required this.machine, required this.sessions, this.period = const Duration(seconds: 30), DateTime Function()? now}) : _now = now ?? DateTime.now;

  final FirebaseFirestore db;
  final String machine;

  /// The open projects and whether a session runs in each — read at every beat.
  final Map<String, bool> Function() sessions;
  final Duration period;
  final DateTime Function() _now;

  String appVersion = '';
  String? cli;
  Timer? _timer;
  DateTime? lastBeat;
  String? error;
  int beats = 0;

  String get hostId => hostIdFor(machine);
  DocumentReference<Map<String, dynamic>> get ref => db.collection('hosts').doc(hostId);
  bool get running => _timer != null;

  Map<String, Object?> doc() {
    final s = sessions();
    return {'name': machine, 'appVersion': appVersion, if (cli != null) 'cli': cli, 'projects': s.keys.toList(), 'sessions': s};
  }

  /// Beats now and every [period]. Idempotent.
  void start() {
    if (running) return;
    _timer = Timer.periodic(period, (_) => beat());
    unawaited(beat());
  }

  Future<void> beat() async {
    try {
      await ref.set({...doc(), 'seenAt': FieldValue.serverTimestamp(), 'stopping': false}, SetOptions(merge: true));
      lastBeat = _now();
      beats++;
      error = null;
    } on Object catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  /// A clean quit. Waits a few seconds at most — a quit must not hang on
  /// the network.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    try {
      await ref.set({'stopping': true, 'seenAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    } on Object catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  /// One line for the Session tab.
  String get status {
    if (error != null) return 'Heartbeat failed: $error';
    if (lastBeat == null) return 'Heartbeat: not yet — the phone cannot tell this Mac is up.';
    final ago = agoShort(_now().difference(lastBeat!));
    return 'Heartbeat every ${period.inSeconds} s as hosts/$hostId · last $ago ago · the phone says "unreachable" after ${hostStaleAfter.inSeconds} s without one.';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
