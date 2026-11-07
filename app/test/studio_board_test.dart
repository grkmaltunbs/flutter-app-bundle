// The messaging board with Fırat's side: parsed from the real file's shape,
// kept on the Mac by a fetch of only its branch (into a repo of its own),
// a new message from Fırat's side announced once, shown in INBOX with REPLY,
// and published for the phone.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/studio/studio_board.dart';
import 'package:kit_app/src/studio/studio_relay.dart';
import 'package:kit_app/src/studio/studio_screen.dart';
import 'package:kit_app/src/studio/studio_source.dart';
import 'package:kit_app/src/theme.dart';
import 'package:path/path.dart' as p;

const board1 = '''
# MESSAGING BOARD

Messages between Fırat's AIs and Görkem's AIs.

- Post with `/send-team-message`. Newest first, one short bullet.

## Messages

- 2026-11-06 23:02 · Görkem's AI (claude/mine-room-layouts) → Fırat's AIs: re 2026-11-06 22:43: **acked** for M3.62.
- 2026-11-06 22:43 · Fırat's AI (develop) → Görkem's AIs: ask, on Fırat's yes: **M3.62**, the stand-in boss as the Mine finale.
- 2026-11-03 04:55 · Fırat's box AI (nightly) → everyone: FYI, no reply needed. The full run did not complete.
''';

Future<void> git(List<String> args, {String? dir}) async {
  final r = await Process.run('git', args, workingDirectory: dir);
  if (r.exitCode != 0) throw StateError('git $args: ${r.stderr}');
}

void main() {
  test('parseBoard: stamp, from, to, text; Fırat\'s side to this one is for you', () {
    final b = parseBoard(board1);
    expect(b, hasLength(3));
    expect(b[0].from, "Görkem's AI (claude/mine-room-layouts)");
    expect(b[0].to, "Fırat's AIs");
    expect(b[0].forYou, isFalse, reason: 'our own post');
    expect(b[1].at, DateTime(2026, 11, 6, 22, 43));
    expect(b[1].forYou, isTrue);
    expect(b[1].text, startsWith('ask, on Fırat\'s yes: **M3.62**'));
    expect(b[2].forYou, isTrue, reason: 'Fırat\'s box writing to everyone counts');
  });

  test('the watcher: a repo of its own for the branch, the file written, the first look marks, a new message from Fırat is announced once', () async {
    final root = Directory.systemTemp.createTempSync('board_root_');
    addTearDown(() => root.deleteSync(recursive: true));
    // "GitHub": a repo with the messaging-board branch.
    final origin = p.join(root.path, 'origin');
    Directory(origin).createSync();
    await git(['init', '-q', '-b', 'messaging-board'], dir: origin);
    await git(['config', 'user.email', 't@t'], dir: origin);
    await git(['config', 'user.name', 't'], dir: origin);
    File(p.join(origin, 'MESSAGING_BOARD.md')).writeAsStringSync(board1);
    await git(['add', '.'], dir: origin);
    await git(['commit', '-q', '-m', 'board'], dir: origin);
    // The game repo: only its origin URL is read.
    final game = p.join(root.path, 'game');
    Directory(game).createSync();
    await git(['init', '-q'], dir: game);
    await git(['remote', 'add', 'origin', origin], dir: game);

    final heard = <List<BoardMessage>>[];
    final w = BoardWatcher(gameDir: game, home: p.join(root.path, 'studio'), onNew: heard.add);
    await w.fetch();
    expect(w.error, isNull);
    expect(File(w.file).readAsStringSync(), board1);
    expect(heard, isEmpty, reason: 'the first look only marks');
    expect(Directory(p.join(game, '.git', 'refs', 'remotes')).existsSync() && Directory(p.join(game, '.git', 'refs', 'remotes', 'origin')).existsSync(), isFalse, reason: 'the game repo is not fetched into');

    // Fırat posts; and Görkem's side posts too.
    File(p.join(origin, 'MESSAGING_BOARD.md')).writeAsStringSync(board1.replaceFirst('## Messages\n\n', "## Messages\n\n- 2026-11-07 10:00 · Görkem's AI (lane) → Fırat's AIs: ours.\n- 2026-11-07 09:30 · Fırat's AI (develop) → Görkem's AIs: **FYI** M3.63 is on develop.\n"));
    await git(['commit', '-q', '-am', 'board 2'], dir: origin);
    await w.fetch();
    expect(heard.single.map((m) => m.text), ['**FYI** M3.63 is on develop.']);
    await w.fetch();
    expect(heard, hasLength(1), reason: 'announced once');
  });

  testWidgets('INBOX: the board, Fırat\'s to you in amber; REPLY asks the orchestrator to post', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auto = Directory.systemTemp.createTempSync('board_auto_');
    addTearDown(() => auto.deleteSync(recursive: true));
    File(p.join(auto.path, 'lane-a', 'status')).createSync(recursive: true);
    final boardFile = File(p.join(auto.path, 'board.md'))..writeAsStringSync(board1);
    final source = StudioSource(autopilotDir: auto.path, boardFile: boardFile.path);
    await tester.runAsync(source.refresh);
    final sent = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: StudioScreen(source: source, initialTab: 4, initialInboxSegment: 1, sendToOrchestrator: (t) async {
        sent.add(t);
        return 'sent';
      }),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('BOARD · 3 · 2 FROM FIRAT'), findsOneWidget);
    expect(find.textContaining('the stand-in boss as the Mine finale'), findsOneWidget);
    await tester.tap(find.textContaining('the stand-in boss as the Mine finale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REPLY'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'yes, take it');
    await tester.tap(find.text('SEND TO ORCHESTRATOR'));
    await tester.pumpAndSettle();
    expect(sent.single, contains('/send-team-message'));
    expect(sent.single, contains("2026-11-06 22:43 · Fırat's AI (develop) → Görkem's AIs"));
    expect(sent.single, contains('The user wants it to say: yes, take it'));
    expect(tester.takeException(), isNull);
  });

  test('the board reaches the phone', () async {
    final auto = Directory.systemTemp.createTempSync('board_auto2_');
    addTearDown(() => auto.deleteSync(recursive: true));
    File(p.join(auto.path, 'lane-a', 'status')).createSync(recursive: true);
    final boardFile = File(p.join(auto.path, 'board.md'))..writeAsStringSync(board1);
    final mac = StudioSource(autopilotDir: auto.path, boardFile: boardFile.path);
    await mac.refresh();
    final db = FakeFirebaseFirestore();
    await StudioPublisher(db: db, source: mac, machine: 'm').publish();
    final phone = RemoteStudioData(db)..start();
    for (var i = 0; i < 6; i++) {
      await pumpEventQueue();
    }
    expect(phone.snapshot.board.map((m) => m.forYou), [false, true, true]);
    phone.dispose();
  });
}
