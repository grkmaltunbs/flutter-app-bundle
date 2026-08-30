// The phone's Deck over a fake relay at phone width and every text scale:
// Start is a command, the mirrored transcript renders, a send shows at
// once and becomes a command, an ask pins inside the Deck.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(find.text('STOP'), findsOneWidget);
      expect(find.textContaining('CLAUDE 2.1.251'), findsOneWidget);
      final list = find.byType(Scrollable).first;
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

      await tester.ensureVisible(find.text('STOP'));
      await tester.tap(find.text('STOP'));
      await _settle(tester);
      cmds = await project.collection('commands').orderBy('sentAt').get();
      expect(cmds.docs.last.data()['type'], 'stop');
      expect(tester.takeException(), isNull);
    });
  }
}
