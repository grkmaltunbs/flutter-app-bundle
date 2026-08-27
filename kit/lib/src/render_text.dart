/// Terminal renderings: `kit status`, `kit next`, `kit blocks`, `kit show`.
/// Plain text, no colour — the output is read by Claude as often as by a
/// person, and colour codes are noise to one of them.
library;

import 'graph.dart';
import 'model.dart';

String renderStatus(Plan plan) {
  final g = Graph(plan);
  final b = StringBuffer();
  final rows = <List<String>>[];
  for (final v in g.views()) {
    rows.add([
      v.step.number ?? '',
      v.step.id,
      _stateWord(v),
      _clip(v.step.dependsOn.isEmpty ? '—' : v.step.dependsOn.join(', '), 48, v.step.dependsOn.length),
      v.openBlockers.isEmpty ? '' : '${v.openBlockers.length} item(s)',
    ]);
  }
  final widths = List<int>.filled(5, 0);
  for (final r in [['#', 'id', 'state', 'depends on', 'human'], ...rows]) {
    for (var i = 0; i < r.length; i++) {
      if (r[i].length > widths[i]) widths[i] = r[i].length;
    }
  }
  String line(List<String> r) => [for (var i = 0; i < r.length; i++) r[i].padRight(widths[i])].join('  ').trimRight();
  b.writeln(line(['#', 'id', 'state', 'depends on', 'human']));
  b.writeln(line([for (final w in widths) '-' * w]));
  for (final r in rows) {
    b.writeln(line(r));
  }
  final done = plan.steps.where((s) => s.status == StepStatus.done).length;
  b.writeln();
  b.writeln('${plan.steps.length} steps, $done done. ${plan.items.where((i) => i.isOpen).length} open items.');
  final next = g.nextStep();
  b.writeln(next == null ? 'Nothing is startable.' : 'Next for Claude: ${next.step.id} (${next.step.title}) — ${_stateWord(next)}');
  return b.toString();
}

String _clip(String s, int width, int count) {
  if (s.length <= width) return s;
  final cut = s.substring(0, width).lastIndexOf(', ');
  final head = cut > 0 ? s.substring(0, cut) : s.substring(0, width);
  final shown = ', '.allMatches(head).length + 1;
  return '$head, +${count - shown} more';
}

String _stateWord(StepView v) {
  switch (v.state) {
    case StepState.done:
      return 'done';
    case StepState.blocked:
      return 'blocked';
    case StepState.ready:
      return 'ready';
    case StepState.active:
      return 'active';
    case StepState.codeComplete:
      return 'code complete';
    case StepState.flippable:
      return 'FLIP ME';
    case StepState.waiting:
      return 'waiting';
  }
}

/// What the human can do now, grouped into sittings, with the items that
/// would flip a step today called out first.
String renderNext(Plan plan) {
  final g = Graph(plan);
  final b = StringBuffer();
  final decisive = g.decisiveItemIds();
  final needs = plan.manifest.needs;

  final next = g.nextStep();
  b.writeln('CLAUDE');
  if (next == null) {
    b.writeln('  nothing is startable — every pending step is blocked');
  } else {
    b.writeln('  ${next.step.id}  (Step ${next.step.number ?? '?'} — ${next.step.title})  [${_stateWord(next)}]');
  }
  final cc = g.codeComplete();
  if (cc.isNotEmpty) {
    b.writeln('  code complete, waiting on you: ${cc.map((v) => v.step.id).join(', ')}');
  }
  b.writeln();

  if (decisive.isNotEmpty) {
    b.writeln('WOULD FLIP A STEP TODAY');
    for (final i in plan.items.where((i) => decisive.contains(i.id))) {
      b.writeln('  ${i.id}  ${i.title}');
      b.writeln('      needs ${i.needs.isEmpty ? '?' : i.needs.join(', ')} · unblocks ${i.blocks.join(', ')}');
    }
    b.writeln();
  }

  b.writeln('YOU');
  final sittings = g.sittings();
  if (sittings.isEmpty) b.writeln('  nothing open');
  for (final e in sittings.entries) {
    final kind = needs[e.key];
    b.writeln('  ${kind?.label ?? e.key}  (${e.value.length})');
    for (final i in e.value) {
      final flags = <String>[
        if (i.deadline != null) 'by ${i.deadline}',
        if (decisive.contains(i.id)) 'flips ${i.blocks.join(', ')}' else if (i.blocks.isNotEmpty) 'gates ${i.blocks.join(', ')}',
        if (i.question != null) 'question',
      ];
      b.writeln('    ${i.id}  ${i.title}${flags.isEmpty ? '' : '  [${flags.join(' · ')}]'}');
    }
  }
  return b.toString();
}

String renderBlocks(Plan plan, String stepId) {
  final g = Graph(plan);
  final r = g.blocks(stepId);
  final b = StringBuffer();
  final v = r.step;
  b.writeln('${v.step.id}  (Step ${v.step.number ?? '?'} — ${v.step.title})  [${_stateWord(v)}]');
  if (r.isClear) {
    b.writeln(v.step.status == StepStatus.done ? '  done' : '  nothing stands in the way');
    return b.toString();
  }
  if (v.missingDeps.isNotEmpty) {
    b.writeln('  dependencies not done:');
    for (final d in r.missingDeps) {
      b.writeln('    ${d.step.id}  [${_stateWord(d)}]');
      if (d.openBlockers.isNotEmpty) {
        for (final i in d.openBlockers) {
          b.writeln('        waiting on you: ${i.id}  ${i.title}');
        }
      }
      if (d.missingDeps.isNotEmpty) {
        b.writeln('        waiting on: ${d.missingDeps.map((x) => x.id).join(', ')}');
      }
    }
    for (final d in v.missingDeps.where((d) => d.rank < 0)) {
      b.writeln('    ${d.id}  (not in the plan!)');
    }
  }
  // Gates only matter once the step is being worked; on a pending step they
  // are all pending by definition and saying so is noise.
  if (v.pendingGates.isNotEmpty && v.step.status == StepStatus.active) {
    b.writeln('  gates not passed: ${v.pendingGates.map((g) => '${g.name} (${g.status.name})').join(', ')}');
  }
  if (v.openBlockers.isNotEmpty) {
    b.writeln('  human items open:');
    for (final i in v.openBlockers) {
      b.writeln('    ${i.id}  ${i.title}  [needs ${i.needs.isEmpty ? '?' : i.needs.join(', ')}]');
    }
  }
  return b.toString();
}

/// The step as markdown — what `/step` reads instead of the whole plan.
String renderStep(Plan plan, Step s) {
  final b = StringBuffer();
  final v = Graph(plan).view(s);
  b.writeln('# Step ${s.number ?? ''} — ${s.title}');
  b.writeln();
  b.writeln('- id: ${s.id}');
  b.writeln('- state: ${_stateWord(v)}');
  b.writeln('- depends_on: ${s.dependsOn.isEmpty ? 'none' : s.dependsOn.join(', ')}');
  for (final e in s.meta.entries) {
    b.writeln('- ${e.key}: ${e.value}');
  }
  if (s.gates.isNotEmpty) {
    b.writeln('- gates: ${s.gates.values.map((g) => '${g.name}=${g.status.name}').join(', ')}');
  }
  final items = [for (final i in plan.items) if (i.blocks.contains(s.id)) i];
  if (items.isNotEmpty) {
    b.writeln('- human items: ${items.map((i) => '${i.id} (${i.status.name})').join(', ')}');
  }
  for (final sec in s.sections) {
    b.writeln();
    b.writeln('## ${sec.title}');
    b.writeln();
    b.write(sec.body.endsWith('\n') || sec.body.isEmpty ? sec.body : '${sec.body}\n');
  }
  return b.toString();
}

String renderItem(Plan plan, Item i) {
  final b = StringBuffer();
  b.writeln('# ${i.title}');
  b.writeln();
  b.writeln('- id: ${i.id}');
  b.writeln('- status: ${i.status.name}${i.doneAt != null ? ' (${i.doneAt})' : ''}');
  b.writeln('- needs: ${i.needs.isEmpty ? '?' : i.needs.join(', ')}');
  b.writeln('- blocks: ${i.blocks.isEmpty ? 'nothing' : i.blocks.join(', ')}');
  if (i.step != null) b.writeln('- from step: ${i.step}');
  if (i.added != null) b.writeln('- added: ${i.added}');
  if (i.deadline != null) b.writeln('- deadline: ${i.deadline}');
  if (i.source != null) {
    b.writeln('- source: ${i.source!.file ?? ''}${i.source!.line != null ? ':${i.source!.line}' : ''}${i.source!.section != null ? ' (${i.source!.section})' : ''}');
  }
  if (i.body.isNotEmpty) {
    b.writeln();
    b.write(i.body.endsWith('\n') ? i.body : '${i.body}\n');
  }
  if (i.runbook.isNotEmpty) {
    b.writeln();
    b.writeln('## Runbook');
    var n = 0;
    for (final r in i.runbook) {
      n++;
      b.writeln();
      b.writeln('$n. ${r.doText}');
      if (r.expect != null) b.writeln('   - expect: ${r.expect}');
      if (r.ifFails != null) b.writeln('   - if not: ${r.ifFails}');
      if (r.verify != null) b.writeln('   - verify: `${r.verify}`');
    }
  }
  if (i.question != null) {
    final q = i.question!;
    b.writeln();
    b.writeln('## Question');
    b.writeln();
    b.writeln(q.ask);
    final opts = [...q.options]..sort((a, c) => (c.recommended ? 1 : 0) - (a.recommended ? 1 : 0));
    for (final o in opts) {
      b.writeln('- ${o.label}${o.recommended ? ' (recommended)' : ''}${o.why != null ? ' — ${o.why}' : ''}');
    }
    if (q.answer != null) b.writeln('\nAnswer: ${q.answer}');
  }
  if (i.note != null) {
    b.writeln();
    b.writeln('Note: ${i.note}');
  }
  return b.toString();
}
