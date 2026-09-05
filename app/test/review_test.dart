// Reviewing what the agent changed: the diff on an edit's row and ask,
// the file behind a tap, the Git card — and the host's hands from the
// phone, as commands answered by id.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/host/host_actions.dart';
import 'package:kit_app/src/relay.dart';
import 'package:kit_app/src/screens/ask_card.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/screens/file_view.dart';
import 'package:kit_app/src/theme.dart';
import 'package:kit_app/src/widgets/git_card.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_claude.dart';

/// Fixed pumps: the live status glyph animates forever, so pumpAndSettle
/// never would.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Widget _app(Widget child, {bool dark = true}) => MaterialApp(
      theme: kitTheme(dark ? KitTokens.dark : KitTokens.light),
      home: MediaQuery(data: const MediaQueryData(size: Size(390, 844)), child: Scaffold(body: child)),
    );

void main() {
  late Directory home;
  late Directory project;
  setUp(() {
    home = Directory.systemTemp.createTempSync('kit_review_home_');
    project = Directory.systemTemp.createTempSync('kit_review_project_');
    File(p.join(project.path, 'lib', 'main.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync("void main() {\n  print(1);\n  final title = 'Old';\n}\n");
  });
  tearDown(() {
    home.deleteSync(recursive: true);
    project.deleteSync(recursive: true);
  });

  test('an edit\'s row and its ask carry the diff against the disk; a git command from the phone is a row and a line in the next prompt', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    s.diffFor = (tool, input) => diffForAsk(
          toolName: tool,
          input: input,
          read: (path) {
            final f = File(p.join(project.path, path));
            return f.existsSync() ? f.readAsStringSync() : null;
          },
        );
    await s.start();
    s.send('rename the title');
    await fake.writtenLines(1);
    final input = {'file_path': 'lib/main.dart', 'old_string': "title = 'Old'", 'new_string': "title = 'New'"};
    fake.emitJson({'type': 'assistant', 'message': {'role': 'assistant', 'content': [{'type': 'tool_use', 'id': 'tu1', 'name': 'Edit', 'input': input}]}});
    await pumpEventQueue();
    final row = s.transcript.messages.last;
    expect(row.toolName, 'Edit');
    expect(row.path, 'lib/main.dart');
    expect(row.diff, contains("-  final title = 'Old';"));
    expect(row.diff, contains("+  final title = 'New';"));
    expect(row.diff, startsWith('--- a/lib/main.dart\n+++ b/lib/main.dart\n@@'));
    // The ask for the same call reuses it; both ride the relay.
    fake.emitJson({'type': 'control_request', 'request_id': 'r1', 'request': {'subtype': 'can_use_tool', 'tool_name': 'Edit', 'input': input, 'tool_use_id': 'tu1'}});
    await pumpEventQueue();
    final ask = s.transcript.pending!;
    expect(ask.diff, row.diff);
    expect(ask.path, 'lib/main.dart');
    expect(Ask.fromMap(ask.toMap()).diff, row.diff);
    expect(DeckMessage.fromMap(row.toMap()).diff, row.diff);
    s.answer(AskAnswer.deny('no'));
    await fake.writtenLines(2);
    // A Bash call has no diff.
    fake.emitJson({'type': 'assistant', 'message': {'role': 'assistant', 'content': [{'type': 'tool_use', 'id': 'tu2', 'name': 'Bash', 'input': {'command': 'ls'}}]}});
    await pumpEventQueue();
    expect(s.transcript.messages.last.diff, isNull);
    expect(s.transcript.messages.last.path, isNull);
    fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 10, 'num_turns': 1, 'result': 'ok', 'session_id': s.sessionId});
    await pumpEventQueue();

    // The host ran git for the phone: a row now, a line the session reads next.
    final git = s.addHostRow(toolName: 'git', input: {'op': 'commit', 'message': 'wip: title'}, result: '[main 1a2b3c] wip: title');
    expect(git.role, DeckRole.tool);
    expect(git.toolSummary, 'git commit "wip: title"');
    expect(s.transcript.messages.last, git);
    s.noteHostAction('git commit "wip: title" — ok: [main 1a2b3c] wip: title');
    s.send('now push it');
    await fake.writtenLines(3);
    final text = ((jsonDecode(fake.written.last) as Map)['message'] as Map)['content'] as String;
    expect(text, startsWith('Since your last turn the user did this from the app, outside this session:\n- git commit "wip: title" — ok'));
    expect(text, endsWith('\n\nnow push it'));
    expect(s.transcript.messages.last.text, 'now push it', reason: 'the row shows what was typed');
    fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 10, 'num_turns': 1, 'result': 'ok', 'session_id': s.sessionId});
    await pumpEventQueue();
    s.send('and again');
    await fake.writtenLines(4);
    expect(((jsonDecode(fake.written.last) as Map)['message'] as Map)['content'], 'and again', reason: 'told once');
  });

  testWidgets('an Edit ask shows its diff, green and red, not the input', (tester) async {
    final ask = Ask(requestId: 'r1', toolName: 'Edit', toolUseId: 't1', input: {'file_path': 'lib/main.dart', 'old_string': 'a', 'new_string': 'b'}, at: DateTime(2026))
      ..diff = '--- a/lib/main.dart\n+++ b/lib/main.dart\n@@ -1,3 +1,3 @@\n void main() {\n-  a\n+  b\n }';
    await tester.pumpWidget(_app(SingleChildScrollView(child: AskCard(ask: ask, onAnswer: (a, {remember = false}) {}))));
    await tester.pump();
    expect(find.text('-  a'), findsOneWidget);
    expect(find.text('+  b'), findsOneWidget);
    expect(find.text('@@ -1,3 +1,3 @@'), findsOneWidget);
    expect(find.text('ALLOW'), findsOneWidget);
    expect(find.textContaining('old_string'), findsNothing, reason: 'the diff replaces the input');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tool row with a diff opens it; the path opens the file; find and Ask about this scope the composer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final files = HostFiles(dir: project.path, attachmentsDir: p.join(home.path, 'attachments'));
    final row = DeckMessage(id: 'm1', role: DeckRole.tool, text: '', at: DateTime(2026), toolName: 'Edit', toolInput: {'file_path': 'lib/main.dart', 'old_string': 'x', 'new_string': 'y'}, toolUseId: 't1', toolResult: 'ok', diff: '@@ -1,2 +1,2 @@\n-x\n+y');
    final ops = <String>[];
    await tester.pumpWidget(_app(DeckView(
      state: BridgeState.ready,
      title: 'Nahmatik',
      facts: const [],
      messages: [row],
      running: true,
      canResume: false,
      onStart: () {},
      onResume: () {},
      onStop: () {},
      onSend: (_, _) async {},
      foldOnScroll: false,
      loadFile: (path) async => files.read(path),
      onGit: (op, {message, path}) async {
        ops.add('$op $path');
        return 'reverted $path';
      },
    )));
    await tester.pump();
    expect(find.text('DIFF · TAP'), findsOneWidget);
    await tester.tap(find.text('DIFF · TAP'));
    await _settle(tester);
    expect(find.text('-x'), findsOneWidget);
    expect(find.text('+y'), findsOneWidget);
    expect(find.text('REVERT FILE'), findsOneWidget);
    await tester.tap(find.text('lib/main.dart'));
    await _settle(tester);
    expect(find.byType(FileViewScreen), findsOneWidget);
    expect(find.text("  final title = 'Old';"), findsOneWidget);
    expect(find.textContaining('4 LINES'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(FileViewScreen), matching: find.byType(TextField)), 'title');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(find.text('3 · 1'), findsOneWidget, reason: 'the hit line, and how many');
    await tester.tap(find.byTooltip('Ask about this'));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FileViewScreen), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'lib/main.dart:3 ');
    // Revert file from the file view, behind the confirm.
    await tester.tap(find.text('DIFF · TAP'));
    await _settle(tester);
    await tester.tap(find.text('REVERT FILE'));
    await _settle(tester);
    expect(find.text('Revert this file?'), findsOneWidget);
    await tester.tap(find.text('KEEP'));
    await _settle(tester);
    expect(ops, isEmpty);
    await tester.tap(find.text('REVERT FILE'));
    await _settle(tester);
    await tester.tap(find.text('REVERT'));
    await _settle(tester);
    expect(ops, ['revert lib/main.dart']);
    // A refused path reads why.
    await tester.pumpWidget(_app(FileViewScreen(path: '/etc/passwd', load: () async => files.read('/etc/passwd'))));
    await _settle(tester);
    expect(find.textContaining('Refused: outside the project folder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Git card reads the numbers; Commit takes a message; Push is a tap; nothing to commit when clean', (tester) async {
    final calls = <String>[];
    Future<String> op(String o, {String? message, String? path}) async {
      calls.add('$o ${message ?? ''}'.trim());
      return 'ok: [main 1a2b] ${message ?? ''}'.trim();
    }

    await tester.pumpWidget(_app(GitCard(git: const GitStatus(branch: 'main', ahead: 1, dirty: 2, lastCommit: 'plan: interrupt done'), onOp: op), dark: false));
    expect(find.text('GIT · MAIN'), findsOneWidget);
    expect(find.text('2 CHANGED'), findsOneWidget);
    expect(find.text('↑1 ↓0'), findsOneWidget);
    expect(find.text('plan: interrupt done'), findsOneWidget);
    await tester.tap(find.text('COMMIT'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'wip: title');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('COMMIT')));
    await tester.pumpAndSettle();
    expect(calls, ['commit wip: title']);
    expect(find.text('ok: [main 1a2b] wip: title'), findsOneWidget, reason: 'toasted');
    await tester.tap(find.text('PUSH'));
    await tester.pumpAndSettle();
    expect(calls.last, 'push');
    await tester.pumpWidget(_app(GitCard(git: const GitStatus(branch: 'main'), onOp: op), dark: false));
    expect(find.text('CLEAN'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'COMMIT')).onPressed, isNull);
    await tester.pumpWidget(_app(GitCard(git: const GitStatus(branch: '', error: 'not a git repository'), onOp: op), dark: false));
    expect(find.text('GIT · NONE'), findsOneWidget);
    expect(find.text('not a git repository'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('read_file and git from the phone are host commands, answered by the command\'s id', () async {
    final db = FakeFirebaseFirestore();
    final project = db.collection('projects').doc('demo');
    await project.set({'name': 'Demo', 'machine': 'mac-mini', 'session': {'mode': 'bridge', 'state': 'ready', 'git': {'branch': 'main', 'dirty': 3, 'lastCommit': 'x'}}});
    final deck = RemoteDeck(db, 'demo')..start();
    // The Mac, in miniature: answers what the phone asks.
    final sub = project.collection('commands').snapshots().listen((q) async {
      for (final d in q.docs) {
        final m = d.data();
        if (m['doneAt'] != null || m['type'] != 'host') continue;
        if (m['action'] == 'read_file') {
          final path = m['path'] as String;
          if (path.startsWith('/etc')) {
            await d.reference.set({'doneAt': 'now', 'result': 'refused: outside the project folder'}, SetOptions(merge: true));
            continue;
          }
          await project.collection('files').doc(d.id).set(FileRead.ok(path: path, text: 'hello\nworld\n', lines: 2, bytes: 12).toMap());
          await d.reference.set({'doneAt': 'now', 'result': 'read'}, SetOptions(merge: true));
        } else if (m['action'] == 'git') {
          await d.reference.set({'doneAt': 'now', 'result': 'ok: [main 1a2b] ${m['message']}'}, SetOptions(merge: true));
        }
      }
    });
    await pumpEventQueue();
    expect(deck.git!.dirty, 3);
    expect(deck.git!.branch, 'main');
    final r = await deck.readFile('lib/main.dart');
    expect(r.ok, isTrue);
    expect(r.text, 'hello\nworld\n');
    expect(r.lines, 2);
    await pumpEventQueue();
    expect((await project.collection('files').get()).docs, isEmpty, reason: 'gone once read');
    final refused = await deck.readFile('/etc/passwd');
    expect(refused.ok, isFalse);
    expect(refused.refused, 'refused: outside the project folder');
    expect(await deck.gitOp('commit', message: 'wip'), 'ok: [main 1a2b] wip');
    final cmds = (await project.collection('commands').get()).docs.map((d) => d.data()).toList();
    expect(cmds.where((c) => c['action'] == 'git').single['op'], 'commit');
    expect(cmds.where((c) => c['action'] == 'read_file').length, 2);
    await sub.cancel();
    deck.dispose();
  });
}
