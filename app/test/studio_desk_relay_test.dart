// The step desk on the phone: the Mac publishes each thread (saved rows and
// new ones) with its counts and the desk's state; the phone's question
// reaches the desk with the step's text, the answer comes back as rows, and
// the desk's ask is answered from the phone. And the phone's Studio edits:
// its own draft, sent through the Mac.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart' show AskAnswer, DeckRole;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/studio/studio_desk.dart';
import 'package:kit_app/src/studio/studio_desk_relay.dart';
import 'package:kit_app/src/studio/studio_draft.dart';
import 'package:kit_app/src/studio/studio_relay.dart';
import 'package:kit_app/src/studio/studio_screen.dart';
import 'package:kit_app/src/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_claude.dart';

void main() {
  late Directory home, proj, store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    home = Directory.systemTemp.createTempSync('drelay_home_');
    proj = Directory.systemTemp.createTempSync('drelay_proj_');
    store = Directory.systemTemp.createTempSync('drelay_threads_');
  });
  tearDown(() {
    for (final d in [home, proj, store]) {
      d.deleteSync(recursive: true);
    }
  });

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await pumpEventQueue();
    }
  }

  test('a thread from the phone: the question reaches the desk, the answer comes back, the desk\'s ask is answered there', () async {
    final db = FakeFirebaseFirestore();
    final fake = FakeClaude();
    final desk = fakeSession(fake, dir: proj.path, home: home.path)..promptForAbout = deskPrompt;
    final threads = StudioThreads(dir: store.path)..watch(desk);
    desk.describeAbout = (about) => threads.context[threadKeyOf(about)];
    final relay = DeskRelay(db: db, desk: desk, threads: threads)..start();
    final phone = RemoteThreads(db)..start();
    await settle();

    // The phone asks about lane A's ROOMLAB-1C.
    final about = stepAbout('a', 'ROOMLAB-1C');
    expect(await phone.ask(about, stepText: '[ ] ROOMLAB-1C: Play in that room', text: 'why is this next?'), isNull);
    expect(phone.busy('step:a/ROOMLAB-1C'), isTrue, reason: 'waiting from the moment it is sent');
    await settle();
    await fake.writtenLines(1);
    expect(fake.written.single, contains('[Studio desk · lane step a/ROOMLAB-1C] why is this next?'));
    expect(fake.written.single, contains('ROOMLAB-1C: Play in that room'), reason: 'the step\'s text rides with the question');

    // The desk asks to run a command: the phone sees it and allows it.
    fake.emitJson({'type': 'control_request', 'request_id': 'r1', 'request': {'subtype': 'can_use_tool', 'tool_name': 'Bash', 'input': {'command': 'ls'}, 'tool_use_id': 't1'}});
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await settle();
    expect(phone.pendingAsk?.requestId, 'r1');
    phone.answer(AskAnswer.allow(phone.pendingAsk!));
    await settle();
    await fake.writtenLines(2);
    expect(fake.written.last, contains('"behavior":"allow"'));

    // The answer: saved on the Mac, published, read on the phone.
    fake.emitJson({'type': 'assistant', 'message': {'id': 'm1', 'role': 'assistant', 'content': [{'type': 'text', 'text': 'Because 1B is done.\n\n```studio-summary\nIt lets you fight in one room.\n```'}]}, 'session_id': desk.sessionId});
    fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 5, 'num_turns': 1, 'result': 'ok', 'session_id': desk.sessionId});
    await settle();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await settle();
    expect(phone.questions('step:a/ROOMLAB-1C'), 1);
    expect(phone.summary('step:a/ROOMLAB-1C'), 'It lets you fight in one room.');
    expect(phone.lastAnswer('step:a/ROOMLAB-1C'), 'Because 1B is done.');
    phone.rowsFor('step:a/ROOMLAB-1C');
    await settle();
    final rows = phone.rowsFor('step:a/ROOMLAB-1C');
    expect(rows.first.role, DeckRole.user);
    expect(rows.last.role, DeckRole.assistant);
    expect(phone.busy('step:a/ROOMLAB-1C'), isFalse);
    relay.stop();
    phone.dispose();
    await desk.stop();
  });

  testWidgets('the phone Studio edits: a step\'s panel offers questions and changes; the draft goes out through the Mac', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final draft = StudioDraft(persist: false)..add(const DraftOrder(kind: DraftKind.remove, lane: 'a', target: 'A4'));
    final sent = <String>[];
    final db = FakeFirebaseFirestore();
    final data = RemoteStudioData(db)..start();
    final threads = RemoteThreads(db)..start();
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: StudioScreen(source: data, remote: true, threads: threads, draft: draft, sendToOrchestrator: (text) async {
        sent.add(text);
        return 'sent';
      }),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1 CHANGE IN THE DRAFT'), findsOneWidget);
    await tester.tap(find.text('SEND TO ORCHESTRATOR'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(sent.single, startsWith('[Studio · plan changes] The user sends 1 change'));
    expect(draft.isEmpty, isTrue);
    await tester.pump(const Duration(seconds: 5));
    data.dispose();
    threads.dispose();
  });
}
