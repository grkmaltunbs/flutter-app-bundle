// The phone's Deck over a fake relay at phone width and every text scale:
// Start is a command, the mirrored transcript renders, a send shows at
// once and becomes a command, an ask pins inside the Deck.
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/attachments.dart';
import 'package:kit_app/src/blobs.dart';
import 'package:kit_app/src/relay.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/theme.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Map<String, Object?> _row(String id, DeckRole role, String text, {String? tool, String? result}) => {
      'id': id,
      'role': role.name,
      'text': text,
      'at': '2026-08-30T12:00:00Z',
      'toolName': ?tool,
      if (tool != null) 'toolInput': {'command': text},
      'toolResult': ?result,
      'isError': false,
      'streaming': false,
      'sessionId': 'sess-1',
    };

void main() {
  for (final scale in [1.0, 2.0, 3.12]) {
    testWidgets('phone at ${scale}x: start, read, send, an ask — no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = FakeFirebaseFirestore();
      final project = db.collection('projects').doc('demo');
      await project.set({'name': 'Demo', 'machine': 'mac-mini', 'session': {'mode': 'idle', 'state': 'idle', 'canResume': true, 'pendingAsks': 0}});

      await tester.pumpWidget(MaterialApp(
        theme: kitTheme(scale == 2.0 ? KitTokens.dark : KitTokens.light),
        home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: RemoteDeckTab(db: db, slug: 'demo'))),
      ));
      await _settle(tester);
      expect(find.text('START'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget, reason: 'the host recorded a session');
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('START'));
      await _settle(tester);
      var cmds = await project.collection('commands').get();
      expect(cmds.docs.single.data()['type'], 'start');
      expect(cmds.docs.single.data()['resume'], isFalse);

      // The host started: the session document flips and the transcript arrives.
      await project.set({'session': {'mode': 'bridge', 'state': 'ready', 'sessionId': 'sess-1', 'model': 'claude-fable-5', 'cliVersion': '2.1.251', 'canResume': false, 'pendingAsks': 0}}, SetOptions(merge: true));
      final chat = project.collection('chat');
      await chat.doc('m00000').set(_row('m00000', DeckRole.user, 'Why is step 29 still open?'));
      await chat.doc('m00001').set(_row('m00001', DeckRole.assistant, 'It is **code complete** — three of your boxes hold it:\n\n- the Play data-safety confirmation\n- the presence decision\n- the launch path at 3.12×'));
      await chat.doc('m00002').set(_row('m00002', DeckRole.tool, 'bash kit/kit.sh blocks a11y-and-profile-privacy', tool: 'Bash', result: 'code complete · 3 items open'));
      await _settle(tester);
      expect(find.byTooltip('Stop'), findsOneWidget, reason: 'folded while running, Stop stays on the title row');
      expect(find.textContaining('CLAUDE 2.1.251'), findsOneWidget);
      final list = find.byType(ListView);
      await tester.dragUntilVisible(find.textContaining('three of your boxes', findRichText: true), list, const Offset(0, 200));
      expect(find.textContaining('three of your boxes', findRichText: true), findsOneWidget);
      await tester.dragUntilVisible(find.textContaining('3 items open'), list, const Offset(0, -200));
      expect(find.textContaining('3 items open'), findsOneWidget, reason: 'the tool row with its result');
      expect(tester.takeException(), isNull, reason: 'transcript');

      // A send shows at once and becomes a command.
      await tester.enterText(find.byType(TextField), '/next');
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await _settle(tester);
      expect(find.text('/next'), findsWidgets, reason: 'the echo (and the chip)');
      cmds = await project.collection('commands').orderBy('sentAt').get();
      expect(cmds.docs.last.data()['type'], 'send');
      expect(cmds.docs.last.data()['text'], '/next');

      // An ask pins inside the Deck and is answered from here.
      await project.collection('asks').doc('req_1').set({
        'requestId': 'req_1',
        'toolName': 'Bash',
        'toolUseId': 't1',
        'input': {'command': 'touch /tmp/kit-ask'},
        'at': '2026-08-30T12:01:00Z',
        'suggestions': [],
        'requiresUserInteraction': false,
        'answeredAt': null,
      });
      await project.set({'session': {'state': 'waiting', 'pendingAsks': 1}}, SetOptions(merge: true));
      await _settle(tester);
      expect(find.text('AUTHORIZATION REQUESTED'), findsOneWidget);
      expect(find.text('NEEDS YOU'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'ask card');
      await tester.ensureVisible(find.text('DENY'));
      await tester.tap(find.text('DENY'));
      await _settle(tester);
      cmds = await project.collection('commands').orderBy('sentAt').get();
      expect(cmds.docs.last.data()['type'], 'answer');
      expect((cmds.docs.last.data()['response'] as Map)['message'], 'The user declined from the phone.');
      expect(find.text('AUTHORIZATION REQUESTED'), findsNothing);

      await tester.tap(find.byTooltip('Stop'));
      await _settle(tester);
      cmds = await project.collection('commands').orderBy('sentAt').get();
      expect(cmds.docs.last.data()['type'], 'stop');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a file from the phone goes into the bucket; the command names it; the echo shows the chip', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final project = db.collection('projects').doc('demo');
    await project.set({'name': 'Demo', 'machine': 'mac-mini', 'session': {'mode': 'bridge', 'state': 'ready', 'sessionId': 'sess-1', 'canResume': false, 'pendingAsks': 0}});
    final bytes = Uint8List.fromList(List.generate(700 * 1024 + 10, (i) => i % 251));
    final blobs = MemoryBlobStore();
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.dark),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 780)),
        child: Scaffold(body: RemoteDeckTab(db: db, slug: 'demo', blobs: blobs, pick: () async => [PendingAttachment(name: 'shot.png', mime: 'image/png', bytes: bytes)])),
      ),
    ));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.attach_file));
    await _settle(tester);
    expect(find.text('shot.png'), findsOneWidget, reason: 'the chip');
    // No words: the file is the message.
    await tester.tap(find.byIcon(Icons.arrow_forward));
    for (var i = 0; i < 4; i++) {
      await _settle(tester);
    }
    expect(blobs.objects.keys.single, startsWith('projects/demo/uploads/'));
    expect(blobs.objects.keys.single, endsWith('/shot.png'));
    expect(blobs.progress.values.single.last, 1, reason: 'the chip heard it go up');
    final cmd = (await project.collection('commands').get()).docs.single.data();
    expect(cmd['type'], 'send');
    expect(cmd['text'], '');
    final up = ((cmd['uploads'] as List).single as Map).map((k, v) => MapEntry(k.toString(), v as Object?));
    expect(up['name'], 'shot.png');
    expect(up['mime'], 'image/png');
    expect(up['size'], bytes.length);
    expect(up['path'], blobs.objects.keys.single);
    expect(up['from'], 'phone');
    expect((await project.collection('uploads').get()).docs, isEmpty, reason: 'no parts in Firestore, ever again');
    expect(find.text('shot.png'), findsOneWidget, reason: 'the echo row carries the chip');
    expect(find.textContaining('UP '), findsNothing, reason: 'the progress line is gone once the command is written');
    expect(find.byIcon(Icons.close), findsNothing, reason: 'the composer cleared');
    // What the host reads back is the file, whole.
    expect((await UploadReader(blobs, 'demo').fetch(up)).bytes, bytes);

    // The host could not run it: the echo comes back, with the reason.
    final cmdRef = (await project.collection('commands').get()).docs.single.reference;
    await cmdRef.set({'doneAt': '2026-09-02T10:00:00Z', 'result': 'failed: Bad state: upload ${up['id']} is gone'}, SetOptions(merge: true));
    await _settle(tester);
    expect(find.text('shot.png'), findsNothing, reason: 'the echo is taken back');
    expect(find.textContaining('Not sent: failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a file that will not go up: the echo comes back, the composer keeps the words and the file, nothing is written', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final project = db.collection('projects').doc('demo');
    await project.set({'name': 'Demo', 'machine': 'mac-mini', 'session': {'mode': 'bridge', 'state': 'ready', 'sessionId': 'sess-1', 'canResume': false, 'pendingAsks': 0}});
    final blobs = MemoryBlobStore()..failNextPutWith = StateError('the network went');
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.dark),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 780)),
        child: Scaffold(body: RemoteDeckTab(db: db, slug: 'demo', blobs: blobs, pick: () async => [PendingAttachment(name: 'shot.png', mime: 'image/png', bytes: Uint8List(10))])),
      ),
    ));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.attach_file));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'what is this');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    for (var i = 0; i < 4; i++) {
      await _settle(tester);
    }
    expect(find.textContaining('Could not send'), findsOneWidget);
    expect(find.text('shot.png'), findsOneWidget, reason: 'the chip is still in the composer, and there is no echo row');
    expect(find.byIcon(Icons.close), findsOneWidget, reason: 'the chip can still be removed');
    expect(find.text('what is this'), findsOneWidget, reason: 'the words stay');
    expect((await project.collection('commands').get()).docs, isEmpty);
    expect(blobs.objects, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Mac\'s line sits under the facts; a live session on a Mac that is gone reads LOST; a queued send offers WITHDRAW', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final project = db.collection('projects').doc('demo');
    await project.set({'name': 'Demo', 'machine': 'MacBook-Pro.local', 'session': {'mode': 'bridge', 'state': 'ready', 'sessionId': 'sess-1', 'canResume': false, 'pendingAsks': 0}});
    final hosts = db.collection('hosts').doc('macbook-pro-local');
    await hosts.set({'seenAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(seconds: 20))), 'stopping': false});
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.dark),
      home: MediaQuery(data: const MediaQueryData(size: Size(360, 780)), child: Scaffold(body: RemoteDeckTab(db: db, slug: 'demo'))),
    ));
    await _settle(tester);
    expect(find.textContaining('MAC · 20 S AGO'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);

    await hosts.set({'seenAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 7))), 'stopping': false});
    await _settle(tester);
    expect(find.textContaining('MAC UNREACHABLE SINCE 7 MIN'), findsOneWidget);
    expect(find.text('LOST'), findsOneWidget, reason: 'the relay still says live; the Mac cannot be running it');
    expect(find.text('LIVE'), findsNothing);

    await tester.enterText(find.byType(TextField), 'anyone there?');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await _settle(tester);
    expect(find.text('QUEUED · MAC UNREACHABLE'), findsOneWidget);
    expect((await project.collection('commands').get()).docs, hasLength(1));
    await tester.tap(find.text('WITHDRAW'));
    await _settle(tester);
    expect(find.text('anyone there?'), findsNothing, reason: 'the echo is taken back');
    expect((await project.collection('commands').get()).docs, isEmpty);

    await hosts.set({'seenAt': Timestamp.fromDate(DateTime.now()), 'stopping': true});
    await _settle(tester);
    expect(find.textContaining('MAC STOPPED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0, 3.12]) {
    testWidgets('phone at ${scale}x: the Mac line, LOST and a queued send do not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = FakeFirebaseFirestore();
      await db.collection('projects').doc('demo').set({'name': 'Demo', 'machine': 'MacBook-Pro.local', 'session': {'mode': 'bridge', 'state': 'ready', 'sessionId': 'sess-1', 'canResume': false, 'pendingAsks': 0}});
      await db.collection('hosts').doc('macbook-pro-local').set({'seenAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 7))), 'stopping': false});
      await tester.pumpWidget(MaterialApp(
        theme: kitTheme(KitTokens.dark),
        home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: RemoteDeckTab(db: db, slug: 'demo'))),
      ));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'a send that waits on the Mac, long enough to wrap at the largest size');
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await _settle(tester);
      expect(find.text('LOST'), findsOneWidget);
      expect(find.text('QUEUED · MAC UNREACHABLE'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow at ${scale}x');
    });
  }

  testWidgets('a send the host ran keeps its echo until the mirror replaces it', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final project = db.collection('projects').doc('demo');
    await project.set({'name': 'Demo', 'machine': 'mac-mini', 'session': {'mode': 'bridge', 'state': 'ready', 'sessionId': 'sess-1', 'canResume': false, 'pendingAsks': 0}});
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: const MediaQueryData(size: Size(360, 780)), child: Scaffold(body: RemoteDeckTab(db: db, slug: 'demo'))),
    ));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'hello there');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await _settle(tester);
    final cmdRef = (await project.collection('commands').get()).docs.single.reference;
    await cmdRef.set({'doneAt': '2026-09-02T10:00:00Z', 'result': 'sent'}, SetOptions(merge: true));
    await _settle(tester);
    expect(find.text('hello there'), findsOneWidget, reason: 'the echo stays');
    expect(find.textContaining('Not sent'), findsNothing);
    await project.collection('chat').doc('m00000').set(_row('m00000', DeckRole.user, 'hello there'));
    await _settle(tester);
    expect(find.text('hello there'), findsOneWidget, reason: 'the mirror\'s row replaced the echo, not doubled it');
  });

  testWidgets('the option pills on the phone are commands; the session document is what they show', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final project = db.collection('projects').doc('demo');
    await project.set({'name': 'Demo', 'machine': 'mac-mini', 'session': {'mode': 'idle', 'state': 'idle', 'canResume': false, 'pendingAsks': 0, 'modeChoice': 'default', 'chrome': true}});
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.dark),
      home: MediaQuery(data: const MediaQueryData(size: Size(360, 780)), child: Scaffold(body: RemoteDeckTab(db: db, slug: 'demo'))),
    ));
    await _settle(tester);
    expect(find.text('PERMISSIONS · ASK'), findsNothing, reason: 'the pill is gone; bypass is a notch on the mode dial');
    expect(find.text('CHROME · ON'), findsOneWidget);
    expect(find.text('MODEL · DEFAULT'), findsOneWidget);
    expect(find.text('MODE · DEFAULT'), findsOneWidget);
    await tester.drag(find.byType(Slider).last, const Offset(400, 0));
    await _settle(tester);
    final cmd = (await project.collection('commands').get()).docs.single.data();
    expect(cmd['type'], 'options');
    expect(cmd['mode'], 'bypassPermissions');
    expect(cmd.containsKey('chrome'), isFalse);
    expect(cmd.containsKey('model'), isFalse);
    // A dial is one command, sent when the finger lifts.
    await tester.drag(find.byType(Slider).first, const Offset(400, 0));
    await _settle(tester);
    final dial = (await project.collection('commands').get()).docs.map((d) => d.data()).firstWhere((d) => d['model'] != null);
    expect(dial['model'], 'fable');
    await project.set({'session': {'modelChoice': 'fable', 'effort': 'xhigh'}}, SetOptions(merge: true));
    await _settle(tester);
    expect(find.text('MODEL · FABLE'), findsOneWidget);
    expect(find.text('EFFORT · XHIGH'), findsOneWidget);
    // The host wrote its record and republished.
    await project.set({'session': {'modeChoice': 'plan', 'modePending': true}}, SetOptions(merge: true));
    await _settle(tester);
    expect(find.text('MODE · PLAN'), findsOneWidget);
    // Running: frozen, and the browser's status shows.
    await project.set({'session': {'mode': 'bridge', 'state': 'ready', 'chromeStatus': 'failed'}}, SetOptions(merge: true));
    await _settle(tester);
    expect(find.text('CHROME · FAILED'), findsNothing, reason: 'running: the controls fold');
    await tester.tap(find.byTooltip('Show session controls'));
    await _settle(tester);
    expect(find.text('CHROME · FAILED'), findsOneWidget);
    await tester.tap(find.text('CHROME · FAILED'));
    await _settle(tester);
    final live = (await project.collection('commands').get()).docs.map((d) => d.data()).where((d) => d.containsKey('chrome'));
    expect(live.single['chrome'], isFalse, reason: 'a change while live is a command; the host restarts on the same conversation');
    await project.set({'session': {'restartPending': true}}, SetOptions(merge: true));
    await _settle(tester);
    expect(find.textContaining('Applies when this turn ends'), findsOneWidget);
    // The test pill: a command, then the host's answer toasted.
    await tester.tap(find.text('PUSH · TEST'));
    await _settle(tester);
    final cmds = (await project.collection('commands').get()).docs;
    expect(cmds.length, 4);
    final test = cmds.firstWhere((d) => d.data()['type'] == 'push-test');
    await test.reference.set({'doneAt': FieldValue.serverTimestamp(), 'result': 'sent to 1 phone'}, SetOptions(merge: true));
    await _settle(tester);
    expect(find.text('sent to 1 phone'), findsOneWidget, reason: 'what came of it, toasted');
    expect(tester.takeException(), isNull);
  });
}
