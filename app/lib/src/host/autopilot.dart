import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';

import 'bridge_session.dart';

/// How the loop waits — injected so a test can fire the wait itself.
typedef TimerFactory = Timer Function(Duration d, void Function() f);

/// Autopilot: `/step` after `/step` within a budget, on the host beside the
/// bridge. On the `result` of a turn it started, the loop reads the plan
/// on disk and sends the next `/step`, or stops with the reason. What
/// stops it is fixed: the budget; a step whose gate fails twice; a plan
/// where the human moves next; an error; Stop or INTERRUPT; the pool
/// running dry — unless **night shift** is on, in which case it waits
/// until the reset time plus a minute and sends again, resuming the
/// session on the same id if the process died meanwhile. An ask never
/// stops the loop: the turn waits on it, so the loop does too. Every
/// start, every step that finishes and every stop is one line on the
/// Turn ended channel and one note in the transcript, so the record is
/// whole.
class Autopilot extends ChangeNotifier {
  Autopilot({required this.bridge, required this.loadPlan, this.push, DateTime Function()? now, TimerFactory? timer})
      : _now = now ?? DateTime.now,
        _timer = timer ?? Timer.new;

  final BridgeSession bridge;

  /// The plan as it is on disk now — re-read after every turn, since the
  /// turn is what edits it. Null when it cannot be read.
  final Plan? Function() loadPlan;

  /// One line to the phone, on the Turn ended channel.
  final void Function(String line)? push;
  final DateTime Function() _now;
  final TimerFactory _timer;

  bool on = false;
  int budget = 3;
  bool nightShift = false;

  /// `/step`s sent this run, and steps those finished.
  int sent = 0;
  int done = 0;
  Step? _step;
  DateTime? waitingUntil;
  String? stoppedFor;
  DateTime? startedAt;

  /// The row of the `/step` in flight; the failed-gate count of its step
  /// when it went, so two more stops the loop.
  DeckMessage? _row;
  int _failBase = 0;
  Timer? _wait;
  ResultEvent? _seen;
  bool _bringingUp = false;

  AutopilotState get state => AutopilotState(
        on: on,
        budget: budget,
        sent: sent,
        done: done,
        nightShift: nightShift,
        step: _step?.id,
        stepNumber: _step?.number,
        waitingUntil: waitingUntil,
        stoppedFor: stoppedFor,
        startedAt: startedAt,
      );

  /// The turn that last ended was the loop's — the host holds its plain
  /// Done push, since the loop's own line says more.
  bool get ownsLastTurn => _row != null && bridge.transcript.lastTurnRowId == _row!.id;

  /// Starts a run: the session first if none runs (resumed where it can
  /// be), then the first `/step`. Returns the one line to toast.
  Future<String> start({int? budget, bool? nightShift}) async {
    if (on) return 'autopilot is already on';
    this.budget = (budget ?? this.budget).clamp(1, 10);
    this.nightShift = nightShift ?? this.nightShift;
    sent = 0;
    done = 0;
    stoppedFor = null;
    waitingUntil = null;
    _step = null;
    _row = null;
    _seen = bridge.transcript.lastResult;
    on = true;
    startedAt = _now();
    notifyListeners();
    if (!bridge.running && !await _bringUp()) return _stop('the session did not start${bridge.error == null ? '' : ' — ${bridge.error}'}');
    final shift = this.nightShift ? 'on' : 'off';
    bridge.note('Autopilot on · budget ${this.budget} · night shift $shift');
    push?.call('Started · budget ${this.budget} · night shift $shift');
    return _next();
  }

  /// Resume, else fresh; false when neither came up.
  Future<bool> _bringUp() async {
    _bringingUp = true;
    try {
      if (bridge.previous()?.sessionId != null) {
        await bridge.start(resume: true);
        if (await bridge.awaitReady()) return true;
      }
      await bridge.start();
      return await bridge.awaitReady();
    } finally {
      _bringingUp = false;
    }
  }

  /// Stopped by hand — the toggle, Stop, INTERRUPT. No push: the person
  /// who did it is holding the phone.
  String stop({String by = 'you'}) {
    if (!on) return 'autopilot is off';
    return _stop('stopped by $by', quiet: true);
  }

  String _stop(String reason, {String? line, bool quiet = false}) {
    on = false;
    stoppedFor = reason;
    waitingUntil = null;
    _wait?.cancel();
    _wait = null;
    bridge.note('Autopilot stopped · $reason${line == null ? '' : ' · $line'}');
    if (!quiet) push?.call('Stopped · $reason${line == null ? '' : ' · $line'}');
    notifyListeners();
    return 'autopilot stopped · $reason';
  }

  /// The next `/step`, or the reason there is none.
  Future<String> _next() async {
    if (!on) return 'autopilot is off';
    if (sent >= budget) return _stop('budget reached');
    if (!bridge.running) return _stop('the session is not running');
    final pool = bridge.transcript.pool;
    final at = _resetAt(pool);
    if (pool != null && pool.exhausted && at != null && at.isAfter(_now())) return _waitOrStop(at);
    final plan = loadPlan();
    if (plan == null) return _stop('the plan could not be read');
    switch (nextMove(plan)) {
      case StopMove(:final reason):
        return _stop(reason);
      case StepMove(:final step):
        _step = step;
        _failBase = failedGateCount(step);
        final queued = bridge.send('/step ${step.id}', by: 'autopilot');
        _row = bridge.lastSent;
        sent++;
        notifyListeners();
        return '${queued ? 'queued' : 'sent'} /step ${step.id} · $sent of $budget';
    }
  }

  DateTime? _resetAt(RateLimitEvent? p) => p?.fiveHour?.resetsAt ?? p?.resetsAt;

  /// The pool refused: night shift waits until the reset plus a minute;
  /// otherwise the run ends here.
  String _waitOrStop(DateTime at) {
    if (!nightShift) return _stop('the pool is empty until ${hmLabel(at)}');
    final until = at.add(const Duration(minutes: 1));
    waitingUntil = until;
    _wait?.cancel();
    _wait = _timer(until.difference(_now()), _wake);
    bridge.note('Autopilot · waiting for the pool until ${hmLabel(until)}');
    notifyListeners();
    return 'waiting for the pool until ${hmLabel(until)}';
  }

  Future<void> _wake() async {
    _wait = null;
    if (!on) return;
    waitingUntil = null;
    notifyListeners();
    if (!bridge.running && !await _bringUp()) {
      _stop('the session did not come back after the pool reset${bridge.error == null ? '' : ' — ${bridge.error}'}');
      return;
    }
    bridge.note('Autopilot · the pool reset — carrying on');
    await _next();
  }

  /// The host calls this on every change of the bridge: a turn ended, the
  /// process died, an ask opened. Pure bookkeeping; nothing here waits.
  void check() {
    if (!on) return;
    final t = bridge.transcript;
    if (!bridge.running && !_bringingUp) {
      if (waitingUntil != null) return; // expected: it comes back at the reset
      final at = _resetAt(t.pool);
      if (t.pool?.exhausted == true && at != null && at.isAfter(_now())) {
        // The process died on a refused pool, before any result: that
        // send did not run.
        if (_row != null && t.lastTurnRowId != _row!.id && sent > 0) sent--;
        _waitOrStop(at);
        return;
      }
      _stop(bridge.state == BridgeState.failed ? 'the session failed${bridge.error == null ? '' : ' — ${bridge.error}'}' : 'the session stopped');
      return;
    }
    final r = t.lastResult;
    if (r == null || identical(r, _seen)) return;
    _seen = r;
    if (!ownsLastTurn) return;
    _turnEnded(r);
  }

  void _turnEnded(ResultEvent r) {
    if (bridge.lastTurnInterrupted) {
      _stop('interrupted');
      return;
    }
    final pool = bridge.transcript.pool;
    final at = _resetAt(pool);
    if (pool != null && pool.exhausted && at != null && at.isAfter(_now())) {
      sent--; // that send did not run
      _waitOrStop(at);
      return;
    }
    if (r.isError) {
      final text = r.text.trim();
      _stop('the turn ended in an error${text.isEmpty ? '' : ' — ${text.length > 120 ? '${text.substring(0, 119)}…' : text}'}');
      return;
    }
    // A folder without the kit's commands answers "Unknown command: /step"
    // as a plain reply — the budget must not go on that.
    if (r.text.contains('Unknown command: /step')) {
      _stop('/step is not a command in this folder — the kit\'s commands are not installed here');
      return;
    }
    final plan = loadPlan();
    final s = _step == null ? null : plan?.step(_step!.id);
    if (plan == null || s == null) {
      _stop('the plan could not be read');
      return;
    }
    final num = s.number ?? s.id;
    if (failedGateCount(s) - _failBase >= 2) {
      _stop('step $num failed a gate twice');
      return;
    }
    String? line;
    if (s.status == StepStatus.done) {
      done++;
      line = 'Step $num done · $sent of $budget';
    } else if (Graph(plan).view(s) case final v when v.state == StepState.codeComplete) {
      done++;
      line = 'Step $num built · waiting on you: ${v.openBlockers.map((i) => i.title).join(', ')} · $sent of $budget';
    }
    if (line != null) {
      if (sent >= budget) {
        _stop('budget reached', line: line);
        return;
      }
      bridge.note('Autopilot · $line');
      push?.call(line);
    }
    unawaited(_next());
  }

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }
}
