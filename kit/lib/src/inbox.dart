/// Applies a batch the board or the phone sent — ticks, chosen answers and
/// notes — to `plan/`. One implementation, shared by `kit inbox` and the
/// host app, so a batch means the same thing whichever door it came through.
///
/// Batch shape (the board's `#kit-outbox` and the app's Firestore inbox are
/// both this):
///
/// ```json
/// {"sentAt": "2026-08-28T09:00:00Z",
///  "entries": [
///    {"kind": "item", "id": "…", "action": "done|drop|null", "answer": "…|null", "note": "…|null"},
///    {"kind": "step", "id": "…", "note": "…"}
///  ]}
/// ```
library;

import 'graph.dart';
import 'store.dart';

class InboxLine {
  const InboxLine(this.kind, this.id, this.text, {this.skipped = false});
  final String kind;
  final String id;
  final String text;
  final bool skipped;

  @override
  String toString() => '${skipped ? 'skip ' : ''}$kind $id: $text';
}

class InboxResult {
  InboxResult({required this.lines, required this.applied, required this.skipped, required this.flippable, required this.dryRun});
  final List<InboxLine> lines;
  final int applied;
  final int skipped;

  /// Steps with nothing left in the way after the batch — `kit step done`
  /// candidates.
  final List<String> flippable;
  final bool dryRun;

  String get summary => '$applied applied, $skipped skipped${dryRun ? ' (dry run — nothing written)' : ''}.';
}

/// Applies [batch] to the plan in [store]. [today] is the `done_at` stamp
/// (YYYY-MM-DD). With [dryRun] nothing is written and the lines say what
/// would happen.
InboxResult applyInbox(PlanStore store, Map<String, Object?> batch, {required String today, bool dryRun = false}) {
  final entriesRaw = batch['entries'];
  if (entriesRaw is! List) throw const FormatException('inbox: expected {"entries": [...]}');
  final sentAt = batch['sentAt']?.toString();
  final stamp = sentAt == null ? '' : ' (sent $sentAt)';
  final plan = store.load();
  final lines = <InboxLine>[];
  var applied = 0;
  var skipped = 0;
  for (final e in entriesRaw) {
    if (e is! Map) continue;
    final kind = e['kind']?.toString();
    final id = e['id']?.toString() ?? '';
    final note = e['note']?.toString();
    if (kind == 'item') {
      final i = plan.item(id);
      if (i == null) {
        lines.add(InboxLine('item', id, 'unknown', skipped: true));
        skipped++;
        continue;
      }
      final action = e['action']?.toString();
      final answer = e['answer']?.toString();
      final f = store.itemPath(id);
      final what = <String>[];
      if (answer != null && answer.isNotEmpty) {
        if (!dryRun) store.patch(f, ['question', 'answer'], answer);
        what.add('answer: $answer');
      }
      if (note != null && note.isNotEmpty) {
        if (!dryRun) {
          final existing = i.note;
          store.patch(f, ['note'], existing == null || existing.isEmpty ? '$note$stamp' : '$existing\n$note$stamp');
        }
        what.add('note');
      }
      if (action == 'drop') {
        if (!dryRun && i.isOpen) {
          store.patch(f, ['status'], 'dropped');
          store.patch(f, ['done_at'], today);
        }
        what.add('dropped');
      } else if (action == 'done' || (answer != null && answer.isNotEmpty)) {
        if (!dryRun && i.isOpen) {
          store.patch(f, ['status'], 'done');
          store.patch(f, ['done_at'], today);
        }
        what.add('done');
      }
      lines.add(InboxLine('item', id, what.isEmpty ? 'nothing to apply' : what.join(', ')));
      applied++;
    } else if (kind == 'step') {
      final s = plan.step(id);
      if (s == null) {
        lines.add(InboxLine('step', id, 'unknown', skipped: true));
        skipped++;
        continue;
      }
      if (note != null && note.isNotEmpty) {
        if (!dryRun) {
          store.appendTo(store.stepPath(id), ['history'], {'at': today, 'event': 'note from user', 'note': note});
        }
        lines.add(InboxLine('step', id, 'note recorded'));
        applied++;
      }
    } else {
      lines.add(InboxLine(kind ?? '?', id, 'entry of unknown kind', skipped: true));
      skipped++;
    }
  }
  final flippable = <String>[];
  if (!dryRun && applied > 0) {
    final g = Graph(store.load());
    for (final v in g.views()) {
      if (v.state == StepState.flippable) flippable.add(v.step.id);
    }
  }
  return InboxResult(lines: lines, applied: applied, skipped: skipped, flippable: flippable, dryRun: dryRun);
}
