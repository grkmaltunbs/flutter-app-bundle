import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

typedef HoldStarter = Future<Process> Function(String executable, List<String> args);

/// A power assertion while something runs: `caffeinate -is -w <pid>` — no
/// idle sleep, no system sleep on power — held per process and released
/// when it ends, by hand or by `-w` noticing the pid is gone. A closed
/// lid still sleeps a MacBook without an external display; the
/// `lid-closed-sleep` item says so.
class PowerHold extends ChangeNotifier {
  PowerHold({HoldStarter? starter}) : _starter = starter ?? ((e, a) => Process.start(e, a));

  final HoldStarter _starter;
  final Map<int, Process> _holds = {};
  final Set<int> _starting = {};
  String? error;

  bool get holding => _holds.isNotEmpty;
  int get count => _holds.length;
  Set<int> get pids => _holds.keys.toSet();

  Future<void> hold(int pid) async {
    if (_holds.containsKey(pid) || _starting.contains(pid)) return;
    _starting.add(pid);
    try {
      final p = await _starter('caffeinate', ['-is', '-w', '$pid']);
      _holds[pid] = p;
      unawaited(p.exitCode.then((_) {
        if (identical(_holds[pid], p)) {
          _holds.remove(pid);
          notifyListeners();
        }
      }));
      error = null;
    } on Object catch (e) {
      error = 'Could not hold the Mac awake: $e';
    } finally {
      _starting.remove(pid);
    }
    notifyListeners();
  }

  void release(int pid) {
    final p = _holds.remove(pid);
    if (p == null) return;
    p.kill();
    notifyListeners();
  }

  void releaseAll() {
    for (final p in _holds.values) {
      p.kill();
    }
    _holds.clear();
    notifyListeners();
  }

  /// One line for the Session tab.
  String get status {
    if (error != null) return error!;
    if (!holding) return 'Not holding the Mac awake — nothing runs.';
    return 'Holding the Mac awake (caffeinate) for $count process${count == 1 ? '' : 'es'} — no idle sleep while a session runs.';
  }

  @override
  void dispose() {
    releaseAll();
    super.dispose();
  }
}
