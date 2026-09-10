// The human's rules, edited where the human is: the project brief in the
// bridge record and on the command line, and the Rules editor's save —
// one file written, that file alone committed, a stale save refused.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/host/host_actions.dart';
import 'package:kit_app/src/relay.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/screens/rules_editor.dart';
import 'package:kit_app/src/theme.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_claude.dart';

Widget _app(Widget child, {Size size = const Size(360, 780), double scale = 1.0}) => MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)), child: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rules writer', () {
    late Directory tmp;
    late String project;
    late RulesWriter rules;
    Future<ProcessResult> git(List<String> args) => Process.run('git', args, workingDirectory: project);

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('rules-');
      project = p.join(tmp.path, 'proj');
      Directory(p.join(project, 'plan')).createSync(recursive: true);
      File(p.join(project, 'CLAUDE.md')).writeAsStringSync('# Rules\n- Keep it short.\n');
      File(p.join(project, 'other.txt')).writeAsStringSync('untouched\n');
      final store = PlanStore(p.join(project, 'plan'));
      store.writeManifest(Manifest(projectName: 'T', qa: {'runtime': 'macos', 'note': 'Two suites.'}));
      await git(['init', '-q', '-b', 'main']);
      await git(['config', 'user.email', 't@example.com']);
      await git(['config', 'user.name', 'Test']);
      await git(['add', '-A']);
      await git(['commit', '-q', '-m', 'first']);
      rules = RulesWriter(dir: project, files: HostFiles(dir: project, attachmentsDir: p.join(tmp.path, 'att')), git: GitOps(project, run: git), store: store);
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('CLAUDE.md: read carries a stamp; save writes and commits that one file, named after the new line; a dirty file elsewhere stays', () async {
      final r = rules.read('CLAUDE.md');
      expect(r.ok, isTrue);
      expect(r.stamp, isNotNull);
      File(p.join(project, 'other.txt')).writeAsStringSync('dirty\n');
      final w = await rules.write('CLAUDE.md', '${r.text}- Always run the tests first.', base: r.stamp);
      expect(w.ok, isTrue);
      expect(w.committed, isTrue);
      expect(w.message, 'rules: - Always run the tests first.');
      expect(w.line, startsWith('saved and committed — '));
      final log = (await git(['log', '-1', '--pretty=%s', '--stat'])).stdout.toString();
      expect(log, startsWith('rules: - Always run the tests first.'));
      expect(log, contains('CLAUDE.md'));
      expect(log, isNot(contains('other.txt')), reason: 'only the one file');
      final status = (await git(['status', '--porcelain'])).stdout.toString();
      expect(status, contains('M other.txt'), reason: 'the dirty file is left alone');
      expect(status, isNot(contains('CLAUDE.md')));
      expect(File(p.join(project, 'CLAUDE.md')).readAsStringSync(), endsWith('- Always run the tests first.\n'), reason: 'the missing final newline is added');
    });

    test('a save over a file that changed since it was read is refused with the reload line; nothing written', () async {
      final r = rules.read('CLAUDE.md');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      File(p.join(project, 'CLAUDE.md')).writeAsStringSync('# Rules\n- Changed on the Mac.\n');
      final w = await rules.write('CLAUDE.md', '# Rules\n- From the phone.\n', base: r.stamp);
      expect(w.ok, isFalse);
      expect(w.line, RulesWriter.staleLine);
      expect(File(p.join(project, 'CLAUDE.md')).readAsStringSync(), '# Rules\n- Changed on the Mac.\n');
      // Read again, save again: the new stamp goes through.
      final again = rules.read('CLAUDE.md');
      expect((await rules.write('CLAUDE.md', '# Rules\n- From the phone.\n', base: again.stamp)).committed, isTrue);
      expect((await rules.write('CLAUDE.md', '# Rules\n- From the phone.\n', base: rules.read('CLAUDE.md').stamp)).line, 'nothing changed');
      expect((await rules.write('/etc/passwd', 'x')).line, 'refused: outside the project folder');
      expect((await rules.write('plan', 'x')).line, 'refused: a folder, not a file');
    });

    test('the qa note is a field: read from the manifest with kit.yaml\'s stamp, written by patch, committed as plan/kit.yaml', () async {
      final r = rules.read(rulesQaNote);
      expect(r.ok, isTrue);
      expect(r.text, 'Two suites.');
      expect(r.lines, 1);
      expect(r.stamp, isNotNull);
      final w = await rules.write(rulesQaNote, 'Two suites.\nThe phone screens are proven on the phone.\n', base: r.stamp);
      expect(w.committed, isTrue);
      expect(w.message, 'rules: The phone screens are proven on the phone.');
      final log = (await git(['log', '-1', '--pretty=%s', '--stat'])).stdout.toString();
      expect(log, contains('plan/kit.yaml'));
      expect(log, isNot(contains('CLAUDE.md')));
      final plan = PlanStore(p.join(project, 'plan')).load();
      expect(plan.manifest.qa['note'], 'Two suites.\nThe phone screens are proven on the phone.');
      expect(plan.manifest.qa['runtime'], 'macos', reason: 'the rest of the manifest is untouched');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      File(p.join(project, 'plan', 'kit.yaml')).writeAsStringSync(File(p.join(project, 'plan', 'kit.yaml')).readAsStringSync());
      expect((await rules.write(rulesQaNote, 'x', base: r.stamp)).line, RulesWriter.staleLine);
    });

    test('a project without CLAUDE.md reads as an empty file; the first save creates and commits it', () async {
      File(p.join(project, 'CLAUDE.md')).deleteSync();
      await git(['commit', '-q', '-am', 'no rules']);
      final r = rules.read('CLAUDE.md');
      expect(r.ok, isTrue);
      expect(r.text, '');
      expect(r.stamp, isNull);
      expect(rules.read('other/missing.md').refused, 'not found', reason: 'only CLAUDE.md is invented');
      final w = await rules.write('CLAUDE.md', '# Rules\n- Be brief.\n', base: r.stamp);
      expect(w.committed, isTrue);
      expect(w.message, 'rules: # Rules');
      expect((await git(['log', '-1', '--pretty=%s', '--stat'])).stdout.toString(), contains('CLAUDE.md'));
    });

    test('without a repository the file is saved and the line says it was not committed', () async {
      Directory(p.join(project, '.git')).deleteSync(recursive: true);
      final w = await rules.write('CLAUDE.md', '# Rules\n- No git here.\n');
      expect(w.ok, isTrue);
      expect(w.committed, isFalse);
      expect(w.line, startsWith('saved, not committed: '));
      expect(File(p.join(project, 'CLAUDE.md')).readAsStringSync(), '# Rules\n- No git here.\n');
    });
  });

  group('brief', () {
    late Directory home;
    late Directory project;
    setUp(() {
      home = Directory.systemTemp.createTempSync('kit_brief_home_');
      project = Directory.systemTemp.createTempSync('kit_brief_project_');
    });
    tearDown(() {
      home.deleteSync(recursive: true);
      project.deleteSync(recursive: true);
    });

    test('the user\'s block lives in the record, rides the command line under the fixed lines, and the relay carries both parts', () async {
      final s = fakeSession(FakeClaude(), dir: project.path, home: home.path);
      expect(s.customBrief, isNull);
      expect(s.toRelay()['brief'], '');
      expect(s.toRelay()['briefFixed'], s.fixedBrief);
      expect(s.setBrief('  Always answer in Turkish.  '), 'Saved. It applies at the next Start.');
      expect(s.customBrief, 'Always answer in Turkish.');
      expect(s.previous()!.brief, 'Always answer in Turkish.');
      expect(s.brief, endsWith('$projectBriefHead\nAlways answer in Turkish.'));
      expect(s.fixedBrief, isNot(contains('Turkish')));
      expect(s.toRelay()['brief'], 'Always answer in Turkish.');
      // A fresh session on the folder reads it back and starts with it.
      final fake = FakeClaude();
      final again = fakeSession(fake, dir: project.path, home: home.path);
      expect(again.customBrief, 'Always answer in Turkish.');
      await again.start();
      final args = fake.startedWith;
      final prompt = args[args.indexOf('--append-system-prompt') + 1];
      expect(prompt, endsWith('$projectBriefHead\nAlways answer in Turkish.'));
      expect(again.setBrief('Never touch main.'), startsWith('Saved. It applies when the session starts again'));
      expect(again.setBrief('   '), startsWith('Saved.'));
      expect(again.customBrief, isNull);
      expect(again.previous()!.brief, isNull);
      await again.stop();
    });
  });

  group('editors', () {
    for (final scale in [1.0, 2.0, 3.12]) {
      testWidgets('the brief editor at $scale×: the fixed block folded above, the field, Save reachable, the host\'s line under it', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final saved = <String>[];
        await tester.pumpWidget(_app(BriefEditorScreen(fixed: 'You are driven from K.A.T.Y.A.\nBrowser: none.', current: 'Always answer in Turkish.', onSave: (t) async {
          saved.add(t);
          return 'Saved. It applies at the next Start.';
        }), scale: scale));
        await tester.pump();
        expect(find.text('What every session is told'), findsOneWidget);
        expect(find.text('You are driven from K.A.T.Y.A.\nBrowser: none.'), findsNothing, reason: 'folded');
        expect(find.text('Always answer in Turkish.'), findsOneWidget);
        final save = find.text('SAVE');
        expect(save, findsOneWidget);
        expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(780), reason: 'the Save row stays on screen');
        await tester.enterText(find.byType(TextField), 'Always answer in Turkish.\nNever touch main.');
        await tester.pump();
        expect(find.textContaining('UNSAVED'), findsOneWidget);
        await tester.tap(save);
        await tester.pump();
        await tester.pump();
        expect(saved, ['Always answer in Turkish.\nNever touch main.']);
        expect(find.text('Saved. It applies at the next Start.'), findsOneWidget);
        expect(find.textContaining('UNSAVED'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the rules editor at $scale×: loads the file, saves with its stamp, a stale save offers to reload', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var disk = '# Rules\n- Keep it short.\n';
        var stamp = 100;
        final writes = <(String, String, int?)>[];
        var refuse = false;
        await tester.pumpWidget(_app(RulesEditorScreen(
          read: (path) async => path == rulesQaNote ? FileRead.ok(path: path, text: 'Two suites.', lines: 1, bytes: 11, stamp: 7) : FileRead.ok(path: path, text: disk, lines: 2, bytes: disk.length, stamp: stamp),
          write: (path, text, {base}) async {
            writes.add((path, text, base));
            if (refuse) return RulesWriter.staleLine;
            disk = text;
            stamp++;
            return 'saved and committed — [main 1a2b] rules: - Run the tests first.';
          },
        ), scale: scale));
        await tester.pump();
        await tester.pump();
        expect(find.text('# Rules\n- Keep it short.\n'), findsOneWidget);
        expect(find.textContaining('CLAUDE.MD · 2 LINES'), findsOneWidget);
        final save = find.text('SAVE');
        expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(780), reason: 'the Save row stays on screen');
        await tester.enterText(find.byType(TextField), '# Rules\n- Keep it short.\n- Run the tests first.\n');
        await tester.pump();
        await tester.tap(save);
        await tester.pump();
        await tester.pump();
        expect(writes.single, ('CLAUDE.md', '# Rules\n- Keep it short.\n- Run the tests first.\n', 100));
        await tester.pump();
        expect(find.textContaining('saved and committed'), findsOneWidget);
        // The Mac changed the file meanwhile: the save is refused, RELOAD shows the disk.
        refuse = true;
        disk = '# Rules\n- Changed on the Mac.\n';
        await tester.enterText(find.byType(TextField), '# Rules\n- From the phone.\n');
        await tester.pump();
        await tester.tap(save);
        await tester.pump();
        await tester.pump();
        expect(find.text('Changed on the Mac'), findsOneWidget);
        expect(find.text('KEEP EDITING'), findsOneWidget);
        await tester.tap(find.text('RELOAD'));
        await tester.pump();
        await tester.pump();
        expect(find.text('# Rules\n- Changed on the Mac.\n'), findsOneWidget);
        expect(find.text('# Rules\n- From the phone.\n'), findsNothing);
        // KEEP EDITING keeps the words and shows the refusal.
        refuse = true;
        await tester.enterText(find.byType(TextField), '# Rules\n- Again.\n');
        await tester.pump();
        await tester.tap(save);
        await tester.pump();
        await tester.pump();
        await tester.tap(find.text('KEEP EDITING'));
        await tester.pump();
        expect(find.text('# Rules\n- Again.\n'), findsOneWidget);
        expect(find.textContaining('changed on disk'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the second target is the qa note; switching with unsaved changes asks first', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final reads = <String>[];
      await tester.pumpWidget(_app(RulesEditorScreen(
        read: (path) async {
          reads.add(path);
          return path == rulesQaNote ? FileRead.ok(path: path, text: 'Two suites.', lines: 1, bytes: 11, stamp: 7) : FileRead.ok(path: path, text: '# Rules\n', lines: 1, bytes: 8, stamp: 1);
        },
        write: (path, text, {base}) async => 'saved and committed — x',
      )));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(TextField), '# Rules\n- new\n');
      await tester.pump();
      await tester.tap(find.text('QA NOTE'));
      await tester.pump();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('KEEP EDITING'));
      await tester.pump();
      expect(find.text('# Rules\n- new\n'), findsOneWidget);
      await tester.tap(find.text('QA NOTE'));
      await tester.pump();
      await tester.tap(find.text('DROP'));
      await tester.pump();
      await tester.pump();
      expect(reads, ['CLAUDE.md', rulesQaNote]);
      expect(find.text('Two suites.'), findsOneWidget);
      expect(find.textContaining('PLAN/KIT.YAML:QA.NOTE · 1 LINE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Deck\'s fold carries BRIEF and RULES; BRIEF opens the editor with the block', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(Scaffold(
        body: DeckView(
          state: BridgeState.idle,
          title: 'Scratch',
          facts: const [],
          messages: const [],
          running: false,
          canResume: false,
          onStart: () {},
          onResume: () {},
          onStop: () {},
          onSend: (_, _) async {},
          foldOnScroll: false,
          onOptions: ({mode, chrome, model, effort}) {},
          brief: 'Always answer in Turkish.\nNever touch main.',
          briefFixed: 'You are driven from K.A.T.Y.A.',
          onBrief: (t) async => 'Saved.',
          loadFile: (path) async => FileRead.ok(path: path, text: '# Rules\n', lines: 1, bytes: 8, stamp: 1),
          onWriteFile: (path, text, {base}) async => 'saved and committed — x',
        ),
      )));
      await tester.pump();
      expect(find.text('BRIEF · 2 LINES'), findsOneWidget);
      expect(find.text('RULES · CLAUDE.MD'), findsOneWidget);
      await tester.tap(find.text('BRIEF · 2 LINES'));
      await tester.pumpAndSettle();
      expect(find.text('Brief'), findsOneWidget);
      expect(find.text('Always answer in Turkish.\nNever touch main.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('over the relay: brief and write_file are commands the Mac answers with its line', () async {
    final db = FakeFirebaseFirestore();
    final project = db.collection('projects').doc('demo');
    await project.set({'name': 'Demo', 'session': {'mode': 'idle', 'brief': 'Always answer in Turkish.', 'briefFixed': 'fixed lines'}});
    final deck = RemoteDeck(db, 'demo')..start();
    final sub = project.collection('commands').snapshots().listen((q) async {
      for (final d in q.docs) {
        final m = d.data();
        if (m['doneAt'] != null) continue;
        if (m['type'] == 'brief') {
          await d.reference.set({'doneAt': 'now', 'result': 'Saved. It applies at the next Start. (${m['text']})'}, SetOptions(merge: true));
        } else if (m['type'] == 'host' && m['action'] == 'write_file') {
          await d.reference.set({'doneAt': 'now', 'result': m['base'] == 5 ? 'saved and committed — [main 1a2b] rules: ${m['text']}' : RulesWriter.staleLine}, SetOptions(merge: true));
        }
      }
    });
    await pumpEventQueue();
    expect(deck.brief, 'Always answer in Turkish.');
    expect(deck.briefFixed, 'fixed lines');
    expect(await deck.setBrief('Never touch main.'), 'Saved. It applies at the next Start. (Never touch main.)');
    expect(await deck.writeFile('CLAUDE.md', '- new', base: 5), 'saved and committed — [main 1a2b] rules: - new');
    expect(await deck.writeFile('CLAUDE.md', '- new', base: 4), RulesWriter.staleLine);
    await sub.cancel();
    deck.dispose();
  });
}
