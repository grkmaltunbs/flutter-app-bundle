import 'dart:io';

import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory tmp;
  late PlanStore store;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kit_store_');
    store = PlanStore(p.join(tmp.path, 'plan'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('emitter', () {
    test('round-trips the awkward strings a plan actually contains', () {
      final cases = <String>[
        'For Step 16 (release prep), from QA\'s device run:',
        'yes',
        'true',
        '2026-08-27',
        '  leading spaces',
        'trailing colon:',
        '- starts like a list',
        'has # hash and a: colon',
        'multi\nline\n  with indent\n\nand blank\n',
        '  first line indented\nsecond flush\n',
        '"quoted" and \\backslash',
        '',
        '0x1F',
        '1e3',
      ];
      for (final c in cases) {
        final y = emitYaml({'v': c, 'list': [c], 'nested': {'k': c}});
        final back = loadYaml(y);
        expect(back['v'], c, reason: 'top-level: $y');
        expect(back['list'][0], c, reason: 'in list: $y');
        expect(back['nested']['k'], c, reason: 'nested: $y');
      }
    });

    test('numbers, bools, nulls, empty collections and lists of maps', () {
      final v = {
        'n': 3,
        'f': 1.5,
        'b': false,
        'z': null,
        'e1': <String>[],
        'e2': <String, Object?>{},
        'lm': [
          {'a': 1, 'b': 'x'},
          {'a': 2, 'b': 'y\nz'},
        ],
      };
      final back = deepPlain(loadYaml(emitYaml(v)));
      expect(back, v);
    });
  });

  group('store', () {
    test('writes and reads a plan back identically', () {
      final step = Step(
        id: 's1',
        number: 'G2',
        title: 'Title: with colon',
        rank: 10,
        status: StepStatus.active,
        dependsOn: const ['s0'],
        meta: const {'max_turns': 300, 'qa_required': true},
        gates: {'qa': Gate('qa', status: GateStatus.passed, at: '2026-08-27', note: 'green')},
        sections: const [Section('Description', 'Body\n\n  - [ ] not a box any more\n'), Section('Acceptance', '- ok\n')],
        history: const [HistoryEntry('2026-08-27', 'imported')],
      );
      final item = Item(
        id: 'i1',
        title: 'Do the thing',
        needs: const ['console', 'secret'],
        blocks: const ['s1'],
        step: 's1',
        added: '2026-08-27',
        deadline: '2026-10-30',
        body: 'Why.\n\n1. Step one.\n',
        runbook: const [RunbookLine(doText: 'Open console', expect: 'A key', ifFails: 'Retry', verify: 'gcloud x')],
        question: const Question(ask: 'Which?', options: [QuestionOption('A', recommended: true, why: 'because'), QuestionOption('B')]),
        source: const ItemSource(file: 'j.md', section: 'A. x', line: 12),
      );
      store.writeManifest(Manifest(projectName: 'T', releaseStep: 's1', boardFonts: const {'display': 'Archivo Black'}, boardColors: const {'light': {'accent': '#123456'}}));
      store.writeStep(step);
      store.writeItem(item);

      final plan = store.load();
      expect(plan.manifest.projectName, 'T');
      expect(plan.manifest.boardFonts['display'], 'Archivo Black');
      expect(plan.manifest.boardColors['light']!['accent'], '#123456');
      final s = plan.step('s1')!;
      expect(s.toMap(), step.toMap());
      final i = plan.item('i1')!;
      expect(i.toMap(), item.toMap());
    });

    test('a file whose id does not match its name is refused', () {
      store.writeManifest(Manifest(projectName: 'T'));
      Directory(store.itemsDir).createSync(recursive: true);
      File(p.join(store.itemsDir, 'wrong.yaml')).writeAsStringSync('id: right\ntitle: t\n');
      expect(store.load, throwsFormatException);
    });

    test('patch preserves comments and the rest of the file', () {
      store.writeManifest(Manifest(projectName: 'T'));
      Directory(store.itemsDir).createSync(recursive: true);
      final f = store.itemPath('i');
      File(f).writeAsStringSync('''
# hand-written, keep me
id: i
title: t
status: open   # trailing comment
needs: [console]
blocks: []
body: |
  Prose that must survive.
''');
      store.patch(f, ['status'], 'done');
      store.patch(f, ['done_at'], '2026-08-27');
      store.appendTo(f, ['history'], {'at': '2026-08-27', 'event': 'x'});
      final text = File(f).readAsStringSync();
      expect(text, contains('# hand-written, keep me'));
      expect(text, contains('status: done'));
      expect(text, contains('Prose that must survive.'));
      final i = store.load().item('i')!;
      expect(i.status, ItemStatus.done);
      expect(i.doneAt, '2026-08-27');
    });

    test('patch creates missing parents', () {
      store.writeManifest(Manifest(projectName: 'T'));
      store.writeStep(Step(id: 's', title: 's', rank: 1));
      store.patch(store.stepPath('s'), ['gates', 'qa', 'status'], 'passed');
      expect(store.load().step('s')!.gates['qa']!.status, GateStatus.passed);
    });
  });
}
