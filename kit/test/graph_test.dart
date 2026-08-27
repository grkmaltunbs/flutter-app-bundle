import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

Step step(String id, {int rank = 0, StepStatus status = StepStatus.pending, List<String> deps = const [], bool gatesPassed = false}) => Step(
      id: id,
      title: id,
      rank: rank,
      status: status,
      dependsOn: deps,
      gates: {
        for (final g in const ['analyze', 'tests', 'qa'])
          g: Gate(g, status: gatesPassed || status == StepStatus.done ? GateStatus.passed : GateStatus.pending),
      },
    );

Item item(String id, {List<String> blocks = const [], List<String> needs = const ['console'], ItemStatus status = ItemStatus.open, String? deadline, String? added}) =>
    Item(id: id, title: id, blocks: blocks, needs: needs, status: status, deadline: deadline, added: added);

Plan plan(List<Step> steps, List<Item> items, {String? release}) =>
    Plan(manifest: Manifest(projectName: 't', releaseStep: release), steps: steps, items: items);

void main() {
  group('step state', () {
    test('pending with done deps is ready; with a pending dep is blocked', () {
      final p = plan([
        step('a', rank: 1, status: StepStatus.done),
        step('b', rank: 2, deps: ['a']),
        step('c', rank: 3, deps: ['b']),
      ], []);
      final g = Graph(p);
      expect(g.view(p.step('b')!).state, StepState.ready);
      expect(g.view(p.step('c')!).state, StepState.blocked);
      expect(g.view(p.step('c')!).missingDeps.map((s) => s.id), ['b']);
    });

    test('active with pending gates is active; gates passed + open item is code complete; nothing left is flippable', () {
      final s = step('b', rank: 2, status: StepStatus.active);
      final p = plan([s], [item('box', blocks: ['b'])]);
      expect(Graph(p).view(s).state, StepState.active);

      for (final g in s.gates.values) {
        g.status = GateStatus.passed;
      }
      expect(Graph(p).view(s).state, StepState.codeComplete);
      expect(Graph(p).decisiveItemIds(), {'box'});

      p.item('box')!.status = ItemStatus.done;
      expect(Graph(p).view(s).state, StepState.flippable);
      expect(Graph(p).decisiveItemIds(), isEmpty);
    });

    test('a missing dependency shows up as missing, not as done', () {
      final p = plan([step('b', deps: ['ghost'])], []);
      final v = Graph(p).view(p.step('b')!);
      expect(v.state, StepState.blocked);
      expect(v.missingDeps.single.rank, -1);
    });
  });

  group('next step', () {
    test('prefers the active step over a ready one, and ready over blocked, in rank order', () {
      final p = plan([
        step('a', rank: 1, status: StepStatus.done),
        step('b', rank: 2, deps: ['a']),
        step('c', rank: 3, deps: ['a']),
        step('d', rank: 4, status: StepStatus.active),
      ], []);
      expect(Graph(p).nextStep()!.step.id, 'd');
      p.step('d')!.status = StepStatus.done;
      expect(Graph(p).nextStep()!.step.id, 'b');
    });

    test('a code-complete step is not "next" — Claude has nothing to do on it', () {
      final p = plan([
        step('a', rank: 1, status: StepStatus.active, gatesPassed: true),
        step('b', rank: 2),
      ], [item('box', blocks: ['a'])]);
      expect(Graph(p).nextStep()!.step.id, 'b');
      expect(Graph(p).codeComplete().single.step.id, 'a');
    });
  });

  group('blocks', () {
    test('reports a dependency that is itself waiting on a human', () {
      final p = plan([
        step('g2', rank: 1, status: StepStatus.active, gatesPassed: true),
        step('g12', rank: 2, deps: ['g2']),
      ], [item('push-on-iphone', blocks: ['g2'], needs: ['device'])]);
      final r = Graph(p).blocks('g12');
      expect(r.isClear, isFalse);
      expect(r.missingDeps.single.step.id, 'g2');
      expect(r.missingDeps.single.state, StepState.codeComplete);
      expect(r.missingDeps.single.openBlockers.single.id, 'push-on-iphone');
      expect(renderBlocks(p, 'g12'), contains('waiting on you: push-on-iphone'));
    });

    test('throws on an unknown step', () {
      expect(() => Graph(plan([], [])).blocks('nope'), throwsArgumentError);
    });
  });

  group('release path and urgency', () {
    test('a step the release depends on, transitively, is on the release path', () {
      final p = plan([
        step('a', rank: 1),
        step('b', rank: 2, deps: ['a']),
        step('side', rank: 3),
        step('ship', rank: 4, deps: ['b']),
      ], [], release: 'ship');
      final g = Graph(p);
      expect(g.isOnReleasePath('a'), isTrue);
      expect(g.isOnReleasePath('ship'), isTrue);
      expect(g.isOnReleasePath('side'), isFalse);
    });

    test('deadline beats decisive beats launch-path beats gating beats loose; ties by age', () {
      final p = plan([
        step('cc', rank: 1, status: StepStatus.active, gatesPassed: true),
        step('mid', rank: 2),
        step('ship', rank: 3, deps: ['mid']),
      ], [
        item('loose', added: '2026-01-01'),
        item('gates-mid', blocks: ['mid'], added: '2026-01-02'),
        item('launch', blocks: ['ship'], added: '2026-01-03'),
        item('flip', blocks: ['cc'], added: '2026-01-04'),
        item('dated', deadline: '2026-09-01', added: '2026-01-05'),
        item('loose-older', added: '2025-12-01'),
      ], release: 'ship');
      final order = Graph(p).openItemsByUrgency().map((i) => i.id).toList();
      // 'mid' is on the release path too (ship depends on it), so it ranks
      // with 'launch' and the tie breaks on age.
      expect(order, ['dated', 'flip', 'gates-mid', 'launch', 'loose-older', 'loose']);
    });
  });

  group('sittings', () {
    test('groups by the first need, in urgency order', () {
      final p = plan([step('s', rank: 1)], [
        item('a', needs: ['console', 'secret']),
        item('b', needs: ['device']),
        item('c', needs: ['console'], blocks: ['s']),
        item('d', needs: []),
      ]);
      final s = Graph(p).sittings();
      expect(s.keys, containsAll(['console', 'device', 'unsorted']));
      expect(s['console']!.map((i) => i.id), ['c', 'a']);
      expect(s['unsorted']!.single.id, 'd');
    });
  });
}
