import 'dart:io';

import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String fixture(String name) => File(p.join('test', 'fixtures', name)).readAsStringSync();

void main() {
  group('plan import', () {
    late List<Step> steps;
    late List<Item> items;
    setUp(() {
      items = [];
      steps = importPlanMarkdown(fixture('plan_fixture.md'), itemsOut: items, activeIds: const ['notification-engine']);
    });

    test('a heading inside a code fence is not a step, and a fenced ### is not a section', () {
      expect(steps.map((s) => s.id), ['bootstrap', 'notification-engine', 'recap-winback']);
      final boot = steps.first;
      expect(boot.sections.map((s) => s.title), ['Description', 'Acceptance']);
      expect(boot.section('description')!.body, contains('## Step 99'));
    });

    test('number, status, depends_on and passthrough meta are read; rank follows file order', () {
      expect(steps[0].number, '0');
      expect(steps[0].status, StepStatus.done);
      expect(steps[0].meta['max_turns'], 100);
      expect(steps[1].number, 'G2');
      expect(steps[1].dependsOn, ['bootstrap']);
      expect(steps[1].meta['qa_required'], true);
      expect(steps[2].dependsOn, ['notification-engine', 'bootstrap']);
      expect(steps.map((s) => s.rank), [10, 20, 30]);
    });

    test('--active marks a pending step active with every gate passed', () {
      expect(steps[1].status, StepStatus.active);
      expect(steps[1].gates.values.every((g) => g.status == GateStatus.passed), isTrue);
      expect(steps[2].status, StepStatus.pending);
      expect(steps[2].gates.values.every((g) => g.status == GateStatus.pending), isTrue);
    });

    test('human boxes become items that block the step, with continuation lines joined, and a marker is left behind', () {
      expect(items.map((i) => i.id), ['notification-engine-h1', 'notification-engine-h2']);
      final done = items[0];
      expect(done.status, ItemStatus.done);
      expect(done.title, 'Approve the product defaults: cap 6/day');
      final open = items[1];
      expect(open.status, ItemStatus.open);
      expect(open.blocks, ['notification-engine']);
      expect(open.body, contains('quiet hours hold it'));
      expect(open.body, isNot(contains('\n')));
      expect(open.needs, contains('device'));
      final desc = steps[1].section('description')!.body;
      expect(desc, contains(humanBoxesMarker));
      expect(desc, isNot(contains('- [ ]')));
      expect(desc, contains('Trailing paragraph after the boxes.'));
    });

    test('renders back with the boxes re-injected where the marker was', () {
      final plan = Plan(manifest: Manifest(projectName: 'Fixture'), steps: steps, items: items);
      final md = renderPlanMarkdown(plan);
      expect(md, contains('## Step G2 — Finish the notification engine\n- [ ]\n- state: code complete — waiting on 1 human item(s)'));
      expect(md, contains('  - [x] Approve the product defaults: cap 6/day *(item `notification-engine-h1`)*'));
      expect(md, contains('  - [ ] On a physical iPhone receive one friend-request push end to end *(item `notification-engine-h2`)*'));
      final boxesAt = md.indexOf('- [x] Approve the product');
      final trailingAt = md.indexOf('Trailing paragraph');
      expect(boxesAt, lessThan(trailingAt));
      expect(md, contains('## Step G12 — Weekly recap\n- [ ]\n- state: blocked — waiting on notification-engine'));
      expect(md, isNot(contains(humanBoxesMarker)));
    });

    test('a box left open under a done step is closed at import and says so', () {
      final md = '''
## Step 1 — Done already
- [x]
- id: done-already
- depends_on: none

### Description

**Your part (human):**

  - [ ] Somebody forgot to tick this.
''';
      final out = <Item>[];
      importPlanMarkdown(md, itemsOut: out);
      expect(out.single.status, ItemStatus.done);
      expect(out.single.note, contains('closed at import'));
    });
  });

  group('journal import', () {
    late List<Item> items;
    late List<String> notes;
    setUp(() {
      notes = [];
      items = importJournalMarkdown(
        fixture('journal_fixture.md'),
        numberToStepId: {'G4': 'app-links-invites', 'G12': 'recap-winback', '0': 'bootstrap', '21': 'cloud-functions', '28': 'block-report'},
        releaseStep: 'store-submission',
        doneStepIds: {'bootstrap', 'app-links-invites', 'cloud-functions', 'block-report'},
        notes: notes,
      );
    });

    test('every top-level box is an item; blockquotes and prose are not', () {
      expect(items.length, 6);
      expect(items.map((i) => i.status).where((s) => s == ItemStatus.done).length, 1);
    });

    test('the bold lead is the title, even across a line break; the body is verbatim and de-indented', () {
      final d = items.firstWhere((i) => i.id.startsWith('register-the-domain'));
      expect(d.title, 'Register the domain, `nahmatik.app`, and add it as a Hosting custom domain');
      expect(d.body, contains('1. Porkbun → buy the domain.'));
      expect(d.body, isNot(contains('\n  1.')));
    });

    test('provenance gives the step and the date; a section-A item gates the release step', () {
      final d = items.firstWhere((i) => i.id.startsWith('register-the-domain'));
      expect(d.step, 'app-links-invites');
      expect(d.added, '2026-08-22');
      expect(d.blocks, contains('store-submission'));
      expect(d.source!.section, startsWith('A.'));
      expect(d.source!.line, greaterThan(1));
    });

    test('a mention of a step that is not done becomes a block; a done one never does', () {
      final d = items.firstWhere((i) => i.id.startsWith('register-the-domain'));
      expect(d.blocks, contains('recap-winback'));
      expect(d.blocks, isNot(contains('bootstrap')));
    });

    test('section defaults come first in needs; keyword guesses follow', () {
      final d = items.firstWhere((i) => i.id.startsWith('register-the-domain'));
      expect(d.needs.first, anyOf('console', 'money'));
      final node = items.firstWhere((i) => i.id.startsWith('the-node-js-20'));
      expect(node.needs.first, 'console');
      final dec = items.firstWhere((i) => i.id.startsWith('blocking-silences'));
      expect(dec.needs.first, 'decision');
    });

    test('a deadline is read off an item that talks about a cut-off', () {
      final node = items.firstWhere((i) => i.id.startsWith('the-node-js-20'));
      expect(node.deadline, '2026-10-30');
      expect(node.added, '2026-08-15');
    });

    test('a box with no bold lead gets its first sentence as title; its section still files it', () {
      final plain = items.firstWhere((i) => i.id.startsWith('plain-box'));
      expect(plain.title, 'Plain box with no bold lead');
      expect(plain.needs, ['console']);
    });

    test('a box in no section with no clue is left unsorted and noted', () {
      final orphan = items.firstWhere((i) => i.id.startsWith('not-an-item-either'));
      expect(orphan.needs, isEmpty);
      expect(orphan.blocks, isEmpty);
      expect(notes, contains('items/${orphan.id}: could not tell what it needs'));
    });

    test('a done box records done_at from the last date in its text', () {
      final done = items.firstWhere((i) => i.status == ItemStatus.done);
      expect(done.doneAt, '2026-08-22');
    });
  });
}
