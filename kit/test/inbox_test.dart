import 'dart:io';

import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late PlanStore store;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kit_inbox_');
    store = PlanStore(p.join(tmp.path, 'plan'));
    store.writeManifest(Manifest(projectName: 'T'));
    store.writeStep(Step(id: 'a', title: 'A', rank: 1, status: StepStatus.active, gates: {'tests': Gate('tests', status: GateStatus.passed)}));
    store.writeItem(Item(id: 'i1', title: 'Tick me', needs: ['device'], blocks: ['a']));
    store.writeItem(Item(
      id: 'q1',
      title: 'Decide',
      needs: ['decision'],
      question: const Question(ask: 'Which?', options: [QuestionOption('x', recommended: true), QuestionOption('y')]),
    ));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('dry run writes nothing and says what it would do', () {
    final r = applyInbox(store, {
      'sentAt': '2026-08-28T09:00:00Z',
      'entries': [
        {'kind': 'item', 'id': 'i1', 'action': 'done'},
        {'kind': 'step', 'id': 'a', 'note': 'hi'},
      ],
    }, today: '2026-08-28', dryRun: true);
    expect(r.applied, 2);
    expect(r.dryRun, isTrue);
    expect(store.load().item('i1')!.isOpen, isTrue);
    expect(store.load().step('a')!.history, isEmpty);
    expect(r.flippable, isEmpty, reason: 'a dry run does not look ahead');
  });

  test('a tick closes the item, an answer records and closes, a step note lands in history', () {
    final r = applyInbox(store, {
      'sentAt': '2026-08-28T09:00:00Z',
      'entries': [
        {'kind': 'item', 'id': 'i1', 'action': 'done', 'note': 'seen on the phone'},
        {'kind': 'item', 'id': 'q1', 'answer': 'y'},
        {'kind': 'step', 'id': 'a', 'note': 'looks good'},
        {'kind': 'item', 'id': 'nope', 'action': 'done'},
      ],
    }, today: '2026-08-28');
    expect(r.applied, 3);
    expect(r.skipped, 1);
    final plan = store.load();
    final i1 = plan.item('i1')!;
    expect(i1.status, ItemStatus.done);
    expect(i1.doneAt, '2026-08-28');
    expect(i1.note, 'seen on the phone (sent 2026-08-28T09:00:00Z)');
    final q1 = plan.item('q1')!;
    expect(q1.question!.answer, 'y');
    expect(q1.status, ItemStatus.done);
    expect(plan.step('a')!.history.single.note, 'looks good');
    expect(r.flippable, ['a'], reason: 'its only blocker closed and its gates are green');
  });

  test('drop wins over done and a closed item is not re-stamped', () {
    applyInbox(store, {'entries': [{'kind': 'item', 'id': 'i1', 'action': 'drop'}]}, today: '2026-08-01');
    applyInbox(store, {'entries': [{'kind': 'item', 'id': 'i1', 'action': 'done'}]}, today: '2026-08-28');
    final i1 = store.load().item('i1')!;
    expect(i1.status, ItemStatus.dropped);
    expect(i1.doneAt, '2026-08-01');
  });

  test('reopen undoes a tick, and an answer on a closed decision changes it without closing again', () {
    applyInbox(store, {'entries': [{'kind': 'item', 'id': 'i1', 'action': 'done'}, {'kind': 'item', 'id': 'q1', 'answer': 'x'}]}, today: '2026-08-01');
    final r = applyInbox(store, {'entries': [{'kind': 'item', 'id': 'i1', 'action': 'reopen'}, {'kind': 'item', 'id': 'q1', 'answer': 'y'}]}, today: '2026-08-28');
    final plan = store.load();
    expect(plan.item('i1')!.isOpen, isTrue);
    expect(plan.item('i1')!.doneAt, isNull);
    expect(plan.item('q1')!.question!.answer, 'y');
    expect(plan.item('q1')!.status, ItemStatus.done);
    expect(plan.item('q1')!.doneAt, '2026-08-01', reason: 'changing an answer is not a second closing');
    expect(r.lines.map((l) => l.text), ['reopened', 'answer: y']);
    expect(r.flippable, isEmpty, reason: 'a reopened blocker takes the step back to code complete');
  });

  test('a malformed batch is a FormatException, not a crash', () {
    expect(() => applyInbox(store, {'entries': 'x'}, today: '2026-08-28'), throwsFormatException);
  });
}
