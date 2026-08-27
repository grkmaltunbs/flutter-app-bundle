import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

Step step(String id, {int rank = 0, StepStatus status = StepStatus.pending, List<String> deps = const [], bool gatesPassed = false}) => Step(
      id: id,
      title: id,
      rank: rank,
      status: status,
      dependsOn: deps,
      gates: {'qa': Gate('qa', status: gatesPassed ? GateStatus.passed : GateStatus.pending)},
      sections: const [Section('Description', 'x\n'), Section('Acceptance', 'y\n')],
    );

Plan plan(List<Step> steps, List<Item> items, {String? release}) =>
    Plan(manifest: Manifest(projectName: 't', releaseStep: release), steps: steps, items: items);

List<String> errors(Plan p) => [for (final x in validate(p)) if (x.isError) x.message];
List<String> warnings(Plan p) => [for (final x in validate(p)) if (!x.isError) x.message];

void main() {
  test('a clean plan validates with nothing to say', () {
    final p = plan([step('a', rank: 1, status: StepStatus.done, gatesPassed: true)], [
      Item(id: 'i', title: 'i', needs: const ['console'], status: ItemStatus.done, doneAt: '2026-01-01'),
    ]);
    expect(validate(p), isEmpty);
  });

  test('a done step with an open blocking item is an error — the invariant behind the whole board', () {
    final p = plan([step('a', rank: 1, status: StepStatus.done, gatesPassed: true)], [
      Item(id: 'box', title: 'box', needs: const ['console'], blocks: const ['a']),
    ]);
    expect(errors(p).single, contains('is done but 1 open item(s) still block it'));
  });

  test('unknown dependencies, unknown blocks, unknown needs, and cycles are errors', () {
    final p = plan([
      step('a', rank: 1, deps: ['b']),
      step('b', rank: 2, deps: ['a']),
      step('c', rank: 3, deps: ['ghost']),
    ], [
      Item(id: 'i', title: 'i', needs: const ['telepathy'], blocks: const ['nowhere']),
    ]);
    final e = errors(p).join('\n');
    expect(e, contains('dependency cycle'));
    expect(e, contains('unknown step "ghost"'));
    expect(e, contains('blocks an unknown step "nowhere"'));
    expect(e, contains('needs "telepathy" is not a known kind'));
  });

  test('a question with two recommended options is an error; with none is a warning', () {
    Plan withOptions(List<bool> recs) => plan([], [
          Item(
            id: 'q',
            title: 'q',
            needs: const ['decision'],
            question: Question(ask: '?', options: [for (final r in recs) QuestionOption('o', recommended: r)]),
          ),
        ]);
    expect(errors(withOptions([true, true])).single, contains('recommends more than one'));
    expect(warnings(withOptions([false, false])).single, contains('none is recommended'));
    expect(validate(withOptions([true, false])), isEmpty);
  });

  test('a flippable step is called out', () {
    final p = plan([step('a', rank: 1, status: StepStatus.active, gatesPassed: true)], []);
    expect(warnings(p).single, contains('kit step done a'));
  });

  test('release_step must be a step', () {
    expect(errors(plan([], [], release: 'ship')).single, contains('release_step "ship" is not a step'));
  });

  test('an open item with no needs warns; a done imported item without done_at does not', () {
    final p = plan([], [
      Item(id: 'a', title: 'a'),
      Item(id: 'b', title: 'b', status: ItemStatus.done, needs: const ['console'], source: const ItemSource(file: 'j.md')),
    ]);
    expect(warnings(p).single, contains('says nothing about what it needs'));
  });
}
