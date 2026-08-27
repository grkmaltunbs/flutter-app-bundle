import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

void main() {
  test('docs round-trip into an equal plan and stableJson is order-independent', () {
    final m = Manifest(projectName: 'T', releaseStep: 'b', boardFonts: {'display': 'Archivo Black'});
    final a = Step(id: 'a', title: 'A', rank: 1, status: StepStatus.done, sections: const [Section('Description', 'body')], meta: {'nested': [1, [2, 3]]});
    final b = Step(id: 'b', title: 'B', rank: 2, dependsOn: ['a'], gates: {'qa': Gate('qa', status: GateStatus.failed, note: 'x')});
    final i = Item(id: 'i', title: 'I', needs: ['console'], blocks: ['b'], runbook: const [RunbookLine(doText: 'do', expect: 'see')], question: const Question(ask: '?', options: [QuestionOption('x', recommended: true)]));
    final plan = planFromDocs(manifest: manifestDoc(m), steps: [stepDoc(a), stepDoc(b)], items: [itemDoc(i)]);
    expect(plan.manifest.releaseStep, 'b');
    expect(plan.manifest.boardFonts['display'], 'Archivo Black');
    expect(plan.step('b')!.gates['qa']!.status, GateStatus.failed);
    expect(plan.item('i')!.runbook.single.expect, 'see');
    expect(plan.item('i')!.question!.options.single.recommended, isTrue);
    expect(Graph(plan).view(plan.step('b')!).state, StepState.ready);
    // A list inside a list is wrapped for Firestore, and reads back through the model untouched otherwise.
    expect((stepDoc(a)['meta'] as Map)['nested'], [1, {'list': [2, 3]}]);
    expect(stableJson({'b': 1, 'a': {'d': 2, 'c': 3}}), stableJson({'a': {'c': 3, 'd': 2}, 'b': 1}));
    // A bad document is skipped, not fatal.
    final p2 = planFromDocs(manifest: manifestDoc(m), steps: [stepDoc(a), {'garbage': true}], items: const []);
    expect(p2.steps.map((s) => s.id), ['a']);
  });
}
