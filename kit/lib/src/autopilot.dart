/// Autopilot — the host keeps sending `/step` within a budget. The
/// decisions live here, pure, so a test and both devices agree on them;
/// the loop itself (the bridge, the clock, the pushes) is the host's
/// (`app/lib/src/host/autopilot.dart`).
library;

import 'graph.dart';
import 'model.dart';

/// What the loop does next, read off the plan on disk after every turn.
sealed class AutopilotMove {
  const AutopilotMove();
}

/// Send `/step <id>`.
class StepMove extends AutopilotMove {
  const StepMove(this.step);
  final Step step;
}

/// Stop, and say why.
class StopMove extends AutopilotMove {
  const StopMove(this.reason);
  final String reason;
}

/// The step Claude should work — what `kit next --step` prints — or why
/// there is none: the plan is done, or it is the human's move (an open
/// item gates every pending step, or a dependency is not done).
AutopilotMove nextMove(Plan plan) {
  final g = Graph(plan);
  final n = g.nextStep();
  if (n != null) return StepMove(n.step);
  final pending = {for (final s in plan.steps) if (s.status != StepStatus.done) s.id};
  if (pending.isEmpty) return const StopMove('the plan is done');
  final yours = [for (final i in plan.items) if (i.isOpen && i.blocks.any(pending.contains)) i];
  if (yours.isNotEmpty) {
    final more = yours.length - 1;
    return StopMove('needs you: ${yours.first.title}${more > 0 ? ' (+$more)' : ''}');
  }
  return const StopMove('nothing is startable — every pending step is blocked');
}

/// How many times a gate on [s] was recorded failed, over its whole
/// history — the loop stops when the step it drives adds two.
int failedGateCount(Step s) => s.history.where((h) => h.event.startsWith('gate ') && h.event.endsWith(' failed')).length;

/// `0:42:10` — a countdown, the hours always shown.
String countdownLabel(Duration d) {
  final s = d.inSeconds.clamp(0, 359999);
  return '${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// `01:30` — a clock time, local.
String hmLabel(DateTime at) {
  final l = at.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// The loop as both devices see it: `session.autopilot`. [budget] is how
/// many `/step`s the run may send, [sent] how many it has, [done] how
/// many steps those finished (flipped, or built and waiting on a person).
/// [waitingUntil] is set while night shift waits out the pool;
/// [stoppedFor] is why the last run ended, kept until the next start.
class AutopilotState {
  const AutopilotState({this.on = false, this.budget = 3, this.sent = 0, this.done = 0, this.nightShift = false, this.step, this.stepNumber, this.waitingUntil, this.stoppedFor, this.startedAt});

  factory AutopilotState.fromMap(Map<String, Object?> m) => AutopilotState(
        on: m['on'] == true,
        budget: (m['budget'] as num?)?.toInt() ?? 3,
        sent: (m['sent'] as num?)?.toInt() ?? 0,
        done: (m['done'] as num?)?.toInt() ?? 0,
        nightShift: m['nightShift'] == true,
        step: _text(m['step']),
        stepNumber: _text(m['stepNumber']),
        waitingUntil: DateTime.tryParse(m['waitingUntil']?.toString() ?? ''),
        stoppedFor: _text(m['stoppedFor']),
        startedAt: DateTime.tryParse(m['startedAt']?.toString() ?? ''),
      );

  final bool on;
  final int budget;
  final int sent;
  final int done;
  final bool nightShift;
  final String? step;
  final String? stepNumber;
  final DateTime? waitingUntil;
  final String? stoppedFor;
  final DateTime? startedAt;

  /// Night shift is waiting for the pool to reset.
  bool get waiting => on && waitingUntil != null;

  /// The step as the lines name it — its number, else its id.
  String? get stepLabel => step == null ? null : (stepNumber ?? step);

  /// Every key, null when unset: the host merges the session document,
  /// so a key left out would keep its last value on the phone — a
  /// `waitingUntil` from a wait that ended, a `stoppedFor` from the run
  /// before.
  Map<String, Object?> toMap() => {
        'on': on,
        'budget': budget,
        'sent': sent,
        'done': done,
        'nightShift': nightShift,
        'step': step,
        'stepNumber': stepNumber,
        'waitingUntil': waitingUntil?.toUtc().toIso8601String(),
        'stoppedFor': stoppedFor,
        'startedAt': startedAt?.toUtc().toIso8601String(),
      };

  static String? _text(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }
}

/// The one line under the facts while the loop runs — null when it is
/// off. [needsYou]: the session waits on an ask, so the loop does too.
String? autopilotLine(AutopilotState a, {DateTime? now, bool needsYou = false}) {
  if (!a.on) return null;
  final until = a.waitingUntil;
  if (until != null) return 'Autopilot · waiting for the pool · ${countdownLabel(until.difference(now ?? DateTime.now()))}';
  final where = a.step == null ? 'starting' : 'step ${a.stepLabel}';
  return 'Autopilot · $where · ${a.sent} of ${a.budget}${needsYou ? ' · needs you' : ''}';
}

/// What the pill in the fold reads.
String autopilotPill(AutopilotState a) {
  if (!a.on) return 'AUTOPILOT · OFF';
  if (a.waitingUntil != null) return 'AUTOPILOT · WAITING';
  return 'AUTOPILOT · ${a.sent} OF ${a.budget}';
}
