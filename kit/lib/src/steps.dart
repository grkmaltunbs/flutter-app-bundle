/// Step moves that need no model: start, done, and a new place in the
/// order. One implementation behind `kit step …`, the inbox and the
/// host's `step_done`, so a refusal reads the same whichever door it came
/// through.
library;

import 'graph.dart';
import 'model.dart';
import 'store.dart';

/// `kit step` said no; [message] is the line it prints.
class StepRefused implements Exception {
  const StepRefused(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What a move came to: the line, the steps it made ready, the files it
/// touched.
class StepChange {
  const StepChange(this.message, {this.nowReady = const [], this.files = const []});
  final String message;

  /// Steps that were blocked before and are ready now.
  final List<String> nowReady;
  final List<String> files;

  /// The message with the newly ready steps under it — what the CLI prints.
  String get lines => [message, for (final id in nowReady) '  $id is now ready to start.'].join('\n');
}

/// `kit step start`: pending → active, refused while a dependency is not
/// done unless [force].
StepChange stepStart(PlanStore store, String id, {bool force = false, String? note, required String today}) {
  final plan = store.load();
  final s = plan.step(id);
  if (s == null) throw StepRefused('No step "$id"');
  final v = Graph(plan).view(s);
  if (v.state == StepState.blocked && !force) {
    throw StepRefused('$id is blocked by ${v.missingDeps.map((d) => d.id).join(', ')}. Finish those first, or --force.');
  }
  if (s.status == StepStatus.done) throw StepRefused('$id is already done.');
  final file = store.stepPath(id);
  store.patch(file, ['status'], 'active');
  store.appendTo(file, ['history'], {'at': today, 'event': 'started', if (note != null) 'note': note});
  return StepChange('$id: active.', files: [file]);
}

/// Why `kit step done` would refuse [id] right now, or null when it would
/// flip. The same words the CLI prints.
String? stepDoneRefusal(Plan plan, String id) {
  final s = plan.step(id);
  if (s == null) return 'No step "$id"';
  if (s.status == StepStatus.done) return '$id is already done.';
  final v = Graph(plan).view(s);
  if (v.pendingGates.isNotEmpty) {
    return '$id: gates not passed: ${v.pendingGates.map((g) => g.name).join(', ')}. Record them with `kit gate`, or --force.';
  }
  if (v.openBlockers.isNotEmpty) {
    return '$id: ${v.openBlockers.length} human item(s) still open: ${v.openBlockers.map((i) => i.id).join(', ')}. A step is not done while its boxes are open. Close them with `kit done`, or --force.';
  }
  if (v.missingDeps.isNotEmpty) return '$id: dependencies not done: ${v.missingDeps.map((d) => d.id).join(', ')}.';
  return null;
}

/// `kit step done`: active → done once every gate passed and every box
/// closed; [force] skips the checks (never the "no such step" one).
StepChange stepDone(PlanStore store, String id, {bool force = false, String? note, required String today}) {
  final plan = store.load();
  final s = plan.step(id);
  if (s == null) throw StepRefused('No step "$id"');
  if (s.status == StepStatus.done) throw StepRefused('$id is already done.');
  if (!force) {
    final why = stepDoneRefusal(plan, id);
    if (why != null) throw StepRefused(why);
  }
  final file = store.stepPath(id);
  store.patch(file, ['status'], 'done');
  store.appendTo(file, ['history'], {'at': today, 'event': force ? 'done (forced)' : 'done', if (note != null) 'note': note});
  return StepChange('$id: done.', nowReady: nowReady(store.load(), before: plan), files: [file]);
}

/// Steps that were blocked in [before] and are ready in [after].
List<String> nowReady(Plan after, {required Plan before}) {
  final gb = Graph(before);
  final ga = Graph(after);
  return [
    for (final s in after.steps)
      if (before.step(s.id) case final was? when gb.view(was).state == StepState.blocked && ga.view(s).state == StepState.ready) s.id,
  ];
}

/// One bubble dragged past another: [id] goes just before [before], or to
/// the end when [before] is null.
class StepPlace {
  const StepPlace(this.id, this.before);
  final String id;
  final String? before;

  Map<String, Object?> toMap() => {'id': id, 'before': before};

  @override
  bool operator ==(Object other) => other is StepPlace && other.id == id && other.before == before;

  @override
  int get hashCode => Object.hash(id, before);
}

/// [steps] with [move] applied, ranks changed as little as possible: the
/// moved step takes the middle of the gap it lands in; only when there is
/// no gap do the steps after it shift up by one until the order is strict
/// again. Numbers do not change — headings move, ids and numbers do not.
List<Step> reorderedSteps(List<Step> steps, StepPlace move) {
  final order = [...steps]..sort((a, b) => a.rank.compareTo(b.rank));
  final moving = order.where((s) => s.id == move.id).firstOrNull;
  if (moving == null) throw ArgumentError('Unknown step "${move.id}"');
  final before = move.before;
  if (before != null && !order.any((s) => s.id == before)) throw ArgumentError('Unknown step "$before"');
  if (before == move.id) throw ArgumentError('${move.id} cannot go before itself');
  order.remove(moving);
  final at = before == null ? order.length : order.indexWhere((s) => s.id == before);
  order.insert(at, moving);
  final ranks = {for (final s in steps) s.id: s.rank};
  final prev = at == 0 ? null : order[at - 1];
  final next = at == order.length - 1 ? null : order[at + 1];
  int r;
  if (prev == null && next == null) {
    r = moving.rank;
  } else if (prev == null) {
    r = next!.rank - 10;
  } else if (next == null) {
    r = prev.rank + 10;
  } else if (next.rank - prev.rank >= 2) {
    r = prev.rank + (next.rank - prev.rank) ~/ 2;
  } else {
    r = prev.rank + 1;
  }
  ranks[move.id] = r < 0 ? 0 : r;
  for (var i = 1; i < order.length; i++) {
    final a = order[i - 1].id;
    final b = order[i].id;
    if (ranks[b]! <= ranks[a]!) ranks[b] = ranks[a]! + 1;
  }
  return [for (final s in order) ranks[s.id] == s.rank ? s : _withRank(s, ranks[s.id]!)];
}

Step _withRank(Step s, int rank) => Step(
      id: s.id,
      title: s.title,
      number: s.number,
      rank: rank,
      status: s.status,
      dependsOn: s.dependsOn,
      meta: s.meta,
      gates: s.gates,
      sections: s.sections,
      history: s.history,
    );

/// [plan] as it would read after [moves] — what the phone draws while a
/// drag waits for Apply. Nothing is written.
Plan planWithMoves(Plan plan, List<StepPlace> moves) {
  var steps = plan.steps;
  for (final m in moves) {
    try {
      steps = reorderedSteps(steps, m);
    } on ArgumentError {
      // A move naming a step that is gone: nothing to draw.
    }
  }
  return Plan(manifest: plan.manifest, steps: steps, items: plan.items);
}

/// The line a reorder reports, from the ranks before and after.
String _moveLine(StepPlace move, List<Step> before, List<Step> after) {
  final was = {for (final s in before) s.id: s.rank};
  final now = {for (final s in after) s.id: s.rank};
  final shifted = [for (final s in after) if (s.id != move.id && now[s.id] != was[s.id]) s.id];
  final where = move.before == null ? 'to the end' : 'before ${move.before}';
  return 'moved $where (rank ${was[move.id]} → ${now[move.id]})${shifted.isEmpty ? '' : '; ${shifted.length} other rank${shifted.length == 1 ? '' : 's'} shifted: ${shifted.join(', ')}'}';
}

/// Applies [move] to `plan/`: every rank that changed is patched in place,
/// and the moved step's history says where it went.
StepChange reorderStep(PlanStore store, StepPlace move, {required String today}) {
  final plan = store.load();
  final List<Step> after;
  try {
    after = reorderedSteps(plan.steps, move);
  } on ArgumentError catch (e) {
    throw StepRefused(e.message.toString());
  }
  final was = {for (final s in plan.steps) s.id: s.rank};
  final files = <String>[];
  for (final s in after) {
    if (s.rank == was[s.id]) continue;
    final f = store.stepPath(s.id);
    store.patch(f, ['rank'], s.rank);
    files.add(f);
  }
  final line = _moveLine(move, plan.steps, after);
  if (files.isNotEmpty) {
    store.appendTo(store.stepPath(move.id), ['history'], {'at': today, 'event': 'moved', 'note': move.before == null ? 'to the end' : 'before ${move.before}'});
  }
  return StepChange('${move.id}: ${files.isEmpty ? 'already there' : line}', files: files);
}

/// What a reorder would do, without writing — the dry run's line.
String reorderPreview(Plan plan, StepPlace move) {
  final after = reorderedSteps(plan.steps, move);
  return _moveLine(move, plan.steps, after);
}

/// True when every entry of an inbox [batch] is something the host does by
/// itself — a reorder or a step done — so the phone's button reads Apply,
/// not Send to Claude.
bool hostOnlyBatch(Map<String, Object?> batch) {
  final entries = batch['entries'];
  if (entries is! List || entries.isEmpty) return false;
  return entries.every((e) => e is Map && (e['kind'] == 'reorder' || e['kind'] == 'step_done'));
}
