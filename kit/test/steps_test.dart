// Step moves that need no model: start, done, and a new place in the
// order — the same refusals `kit step` prints, and ranks moved as little
// as the order allows.
import 'dart:io';

import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late PlanStore store;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kit_steps_');
    store = PlanStore(p.join(tmp.path, 'plan'));
    store.writeManifest(Manifest(projectName: 'T'));
    store.writeStep(Step(id: 'a', number: '1', title: 'A', rank: 100, status: StepStatus.done));
    store.writeStep(Step(id: 'b', number: '2', title: 'B', rank: 200, status: StepStatus.active, dependsOn: ['a'], gates: {'tests': Gate('tests', status: GateStatus.pending)}));
    store.writeStep(Step(id: 'c', number: '3', title: 'C', rank: 300, dependsOn: ['b']));
    store.writeStep(Step(id: 'd', number: '4', title: 'D', rank: 301));
    store.writeStep(Step(id: 'e', number: '5', title: 'E', rank: 400, dependsOn: ['b']));
    store.writeItem(Item(id: 'box', title: 'Plug it in', needs: ['device'], blocks: ['b']));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('done refuses a pending gate, then an open box, with the CLI\'s words; flips and names what it made ready', () {
    expect(() => stepDone(store, 'b', today: '2026-09-10'), throwsA(isA<StepRefused>().having((e) => e.message, 'message', 'b: gates not passed: tests. Record them with `kit gate`, or --force.')));
    store.patch(store.stepPath('b'), ['gates', 'tests', 'status'], 'passed');
    expect(stepDoneRefusal(store.load(), 'b'), startsWith('b: 1 human item(s) still open: box.'));
    store.patch(store.itemPath('box'), ['status'], 'done');
    expect(stepDoneRefusal(store.load(), 'b'), isNull);
    final r = stepDone(store, 'b', today: '2026-09-10');
    expect(r.message, 'b: done.');
    expect(r.nowReady, ['c', 'e'], reason: 'both waited on b');
    expect(r.lines, 'b: done.\n  c is now ready to start.\n  e is now ready to start.');
    final b = store.load().step('b')!;
    expect(b.status, StepStatus.done);
    expect(b.history.last.event, 'done');
    expect(() => stepDone(store, 'b', today: '2026-09-10'), throwsA(isA<StepRefused>().having((e) => e.message, 'message', 'b is already done.')));
    expect(() => stepDone(store, 'zz', today: '2026-09-10'), throwsA(isA<StepRefused>().having((e) => e.message, 'message', 'No step "zz"')));
    // Force skips the checks, and says so in the history.
    stepDone(store, 'c', force: true, today: '2026-09-10');
    expect(store.load().step('c')!.history.last.event, 'done (forced)');
  });

  test('start refuses a blocked step unless forced', () {
    expect(() => stepStart(store, 'c', today: '2026-09-10'), throwsA(isA<StepRefused>().having((e) => e.message, 'message', 'c is blocked by b. Finish those first, or --force.')));
    expect(stepStart(store, 'd', today: '2026-09-10').message, 'd: active.');
    expect(store.load().step('d')!.status, StepStatus.active);
    expect(stepStart(store, 'c', force: true, today: '2026-09-10').message, 'c: active.');
    expect(() => stepStart(store, 'a', today: '2026-09-10'), throwsA(isA<StepRefused>()));
  });

  group('reorder', () {
    List<String> order(List<Step> steps) => [for (final s in steps) '${s.id}:${s.rank}'];

    test('takes the middle of a gap, only bumps when there is none, and goes to the end without --before', () {
      final steps = store.load().steps;
      // e before c: between b (200) and c (300) → 250.
      expect(order(reorderedSteps(steps, const StepPlace('e', 'c'))), ['a:100', 'b:200', 'e:250', 'c:300', 'd:301']);
      // a before d: c is 300, d is 301 — no gap, so a takes 301 and d moves up one.
      expect(order(reorderedSteps(steps, const StepPlace('a', 'd'))), ['b:200', 'c:300', 'a:301', 'd:302', 'e:400']);
      // c to the end.
      expect(order(reorderedSteps(steps, const StepPlace('c', null))), ['a:100', 'b:200', 'd:301', 'e:400', 'c:410']);
      // e to the front.
      expect(order(reorderedSteps(steps, const StepPlace('e', 'a'))), ['e:90', 'a:100', 'b:200', 'c:300', 'd:301']);
      // Numbers ride along untouched.
      expect(reorderedSteps(steps, const StepPlace('e', 'a')).first.number, '5');
      expect(() => reorderedSteps(steps, const StepPlace('zz', 'a')), throwsArgumentError);
      expect(() => reorderedSteps(steps, const StepPlace('a', 'zz')), throwsArgumentError);
      expect(() => reorderedSteps(steps, const StepPlace('a', 'a')), throwsArgumentError);
    });

    test('a front move past rank 0 stays at 0 and shifts what follows', () {
      final steps = [Step(id: 'x', title: 'X', rank: 0), Step(id: 'y', title: 'Y', rank: 1), Step(id: 'z', title: 'Z', rank: 2)];
      expect(order(reorderedSteps(steps, const StepPlace('z', 'x'))), ['z:0', 'x:1', 'y:2']);
    });

    test('writes only the ranks that changed, notes the move in history, and reads back in the new order', () {
      final r = reorderStep(store, const StepPlace('a', 'd'), today: '2026-09-10');
      expect(r.message, 'a: moved before d (rank 100 → 301); 1 other rank shifted: d');
      expect(r.files.map(p.basename), ['a.yaml', 'd.yaml']);
      final plan = store.load();
      expect(plan.steps.map((s) => s.id), ['b', 'c', 'a', 'd', 'e']);
      expect(plan.step('a')!.history.last.note, 'before d');
      expect(plan.step('d')!.history, isEmpty, reason: 'a shifted neighbour keeps its history');
      expect(reorderStep(store, const StepPlace('a', 'd'), today: '2026-09-10').message, 'a: already there');
      expect(() => reorderStep(store, const StepPlace('a', 'nope'), today: '2026-09-10'), throwsA(isA<StepRefused>()));
    });

    test('planWithMoves draws the order a draft holds, without writing', () {
      final plan = store.load();
      final shown = planWithMoves(plan, const [StepPlace('e', 'c'), StepPlace('a', null), StepPlace('gone', 'a')]);
      expect(shown.steps.map((s) => s.id), ['b', 'e', 'c', 'd', 'a']);
      expect(store.load().steps.map((s) => s.id), ['a', 'b', 'c', 'd', 'e'], reason: 'nothing written');
      expect(reorderPreview(plan, const StepPlace('e', 'c')), 'moved before c (rank 400 → 250)');
    });
  });

  test('hostOnlyBatch is true only for reorders and step dones', () {
    expect(hostOnlyBatch({'entries': [{'kind': 'reorder', 'id': 'a', 'before': 'b'}]}), isTrue);
    expect(hostOnlyBatch({'entries': [{'kind': 'reorder', 'id': 'a', 'before': null}, {'kind': 'step_done', 'id': 'b'}]}), isTrue);
    expect(hostOnlyBatch({'entries': [{'kind': 'reorder', 'id': 'a'}, {'kind': 'step', 'id': 'b', 'note': 'hi'}]}), isFalse);
    expect(hostOnlyBatch({'entries': []}), isFalse);
    expect(hostOnlyBatch({}), isFalse);
  });
}
