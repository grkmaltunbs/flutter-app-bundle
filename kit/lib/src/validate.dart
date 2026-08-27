/// Consistency checks. Errors make `kit validate` exit 1; warnings are
/// printed and tolerated. The rule for what is an error: anything a renderer
/// or the graph would silently mis-handle.
library;

import 'graph.dart';
import 'model.dart';

class Problem {
  const Problem(this.level, this.where, this.message);
  final String level; // 'error' | 'warning'
  final String where;
  final String message;

  bool get isError => level == 'error';

  @override
  String toString() => '$level  $where: $message';
}

List<Problem> validate(Plan plan) {
  final out = <Problem>[];
  final stepIds = plan.steps.map((s) => s.id).toSet();
  final needs = plan.manifest.needs;

  void err(String where, String msg) => out.add(Problem('error', where, msg));
  void warn(String where, String msg) => out.add(Problem('warning', where, msg));

  // Steps
  final seenRanks = <int, String>{};
  for (final s in plan.steps) {
    final w = 'steps/${s.id}';
    if (s.title.trim().isEmpty) err(w, 'has no title');
    for (final d in s.dependsOn) {
      if (!stepIds.contains(d)) err(w, 'depends_on names an unknown step "$d"');
      if (d == s.id) err(w, 'depends on itself');
    }
    if (seenRanks.containsKey(s.rank)) {
      warn(w, 'shares rank ${s.rank} with steps/${seenRanks[s.rank]} — order between them is undefined');
    }
    seenRanks[s.rank] = s.id;
    if (s.section('description') == null) warn(w, 'has no Description section');
    if (s.section('acceptance') == null && s.status != StepStatus.done) {
      warn(w, 'has no Acceptance section');
    }
    if (s.status == StepStatus.done) {
      final open = plan.blockersOf(s.id);
      if (open.isNotEmpty) {
        err(w, 'is done but ${open.length} open item(s) still block it: ${open.map((i) => i.id).join(', ')} — a step is not done while its human boxes are open');
      }
      for (final g in s.gates.values) {
        if (g.status != GateStatus.passed) {
          warn(w, 'is done but gate "${g.name}" is ${g.status.name}');
        }
      }
    }
  }

  // Cycles
  final visiting = <String>{};
  final visited = <String>{};
  void dfs(String id, List<String> path) {
    if (visited.contains(id)) return;
    if (!visiting.add(id)) {
      err('steps/$id', 'dependency cycle: ${[...path, id].join(' → ')}');
      return;
    }
    final s = plan.step(id);
    if (s != null) {
      for (final d in s.dependsOn) {
        dfs(d, [...path, id]);
      }
    }
    visiting.remove(id);
    visited.add(id);
  }

  for (final s in plan.steps) {
    dfs(s.id, []);
  }

  // Items
  for (final i in plan.items) {
    final w = 'items/${i.id}';
    if (i.title.trim().isEmpty) err(w, 'has no title');
    for (final b in i.blocks) {
      if (!stepIds.contains(b)) err(w, 'blocks an unknown step "$b"');
    }
    if (i.step != null && !stepIds.contains(i.step)) {
      warn(w, 'step "${i.step}" (provenance) is not in the plan');
    }
    for (final n in i.needs) {
      if (!needs.containsKey(n)) {
        err(w, 'needs "$n" is not a known kind (${needs.keys.join(', ')})');
      }
    }
    if (i.isOpen && i.needs.isEmpty) warn(w, 'is open but says nothing about what it needs — it will land in "unsorted"');
    // Imported history often has no date; the tool always stamps one.
    if (i.status == ItemStatus.done && i.doneAt == null && i.source == null) {
      warn(w, 'is done but has no done_at');
    }
    if (i.question != null) {
      final rec = i.question!.options.where((o) => o.recommended).length;
      if (i.question!.options.isNotEmpty && rec == 0) warn(w, 'question has options but none is recommended');
      if (rec > 1) err(w, 'question recommends more than one option');
      if (i.needs.isNotEmpty && !i.needs.contains('decision')) {
        warn(w, 'has a question but does not need a "decision"');
      }
    }
  }

  // Manifest
  final rs = plan.manifest.releaseStep;
  if (rs != null && !stepIds.contains(rs)) err('kit.yaml', 'release_step "$rs" is not a step');

  // Graph sanity
  final g = Graph(plan);
  for (final v in g.views()) {
    if (v.state == StepState.flippable) {
      warn('steps/${v.step.id}', 'every gate passed and nothing blocks it — run `kit step done ${v.step.id}`');
    }
  }
  return out;
}
