// The phone's ask panel over a fake relay: the card appears, answering
// writes a command, and the card drops both on its own answer and on the
// host stamping the ask.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/screens/remote_asks.dart';
import 'package:kit_app/src/theme.dart';

Map<String, Object?> _bashAsk(String id, {String command = 'touch /tmp/kit-ask', String at = '2026-08-30T12:00:00Z'}) => {
      'requestId': id,
      'toolName': 'Bash',
      'toolUseId': 'toolu_$id',
      'input': {'command': command, 'description': 'A marker'},
      'at': at,
      'description': 'Create a marker file',
      'suggestions': [
        {'type': 'addRules', 'rules': [{'toolName': 'Bash', 'ruleContent': 'touch:*'}], 'behavior': 'allow', 'destination': 'localSettings'}
      ],
      'requiresUserInteraction': false,
      'answeredAt': null,
    };

Map<String, Object?> _questionAsk(String id) => {
      'requestId': id,
      'toolName': 'AskUserQuestion',
      'toolUseId': 'toolu_$id',
      'input': {
        'questions': [
          {'question': 'Ship the artwork slots?', 'header': 'Catalogue', 'multiSelect': false, 'options': [{'label': 'All seven', 'description': ''}, {'label': 'Hold two', 'description': ''}]}
        ]
      },
      'at': '2026-09-03T20:00:00Z',
      'requiresUserInteraction': true,
      'answeredAt': null,
    };

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('the oldest unanswered ask shows; Deny becomes a command; the card drops', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final asks = db.collection('projects').doc('demo').collection('asks');
    await asks.doc('req_2').set(_bashAsk('req_2', command: 'touch /tmp/second', at: '2026-08-30T12:01:00Z'));
    await asks.doc('req_1').set(_bashAsk('req_1'));
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: Scaffold(body: Column(children: [RemoteAskPanel(db: db, slug: 'demo')])),
    ));
    await _settle(tester);
    expect(find.text('AUTHORIZATION REQUESTED'), findsOneWidget);
    expect(find.text('touch /tmp/kit-ask'), findsOneWidget, reason: 'the oldest first');
    expect(find.text('ALWAYS'), findsOneWidget, reason: 'the CLI offered a rule');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('DENY'));
    await _settle(tester);
    expect(find.text('touch /tmp/kit-ask'), findsNothing, reason: 'dropped the moment it was answered here');
    expect(find.text('touch /tmp/second'), findsOneWidget, reason: 'the next one takes its place');
    final cmds = await db.collection('projects').doc('demo').collection('commands').get();
    final cmd = cmds.docs.single.data();
    expect(cmd['type'], 'answer');
    expect(cmd['requestId'], 'req_1');
    expect(cmd['from'], 'phone');
    expect(cmd['doneAt'], isNull);
    expect((cmd['response'] as Map)['behavior'], 'deny');
    expect((cmd['response'] as Map)['message'], 'The user declined from the phone.');

    // The Mac answers the second one: the host stamps it, the card goes.
    await asks.doc('req_2').set({'answeredAt': Timestamp.now(), 'by': 'Mac', 'answer': 'Allowed'}, SetOptions(merge: true));
    await _settle(tester);
    expect(find.text('AUTHORIZATION REQUESTED'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a question takes an answer in the user\'s own words, beside the options', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final asks = db.collection('projects').doc('demo').collection('asks');
    await asks.doc('q_1').set(_questionAsk('q_1'));
    await tester.pumpWidget(MaterialApp(theme: kitTheme(KitTokens.dark), home: Scaffold(body: SingleChildScrollView(child: Column(children: [RemoteAskPanel(db: db, slug: 'demo')])))));
    await _settle(tester);
    expect(find.text('CLAUDE ASKS'), findsOneWidget);
    final answer = find.widgetWithText(FilledButton, 'ANSWER');
    expect(tester.widget<FilledButton>(answer).onPressed, isNull, reason: 'nothing chosen yet');

    // A pick, then own words: the words win and the pick clears.
    await tester.tap(find.text('All seven'));
    await tester.pump();
    expect(tester.widget<FilledButton>(answer).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField), 'Hold all of them until the next release');
    await tester.pump();
    expect(find.byIcon(Icons.radio_button_checked), findsNothing, reason: 'own words clear the pick');
    await tester.tap(answer);
    await _settle(tester);
    final cmd = (await db.collection('projects').doc('demo').collection('commands').get()).docs.single.data();
    expect(cmd['type'], 'answer');
    expect(((cmd['response'] as Map)['updatedInput'] as Map)['answers'], {'Ship the artwork slots?': 'Hold all of them until the next release'});
    expect(cmd['summary'], 'Hold all of them until the next release');

    // And the other way: a pick after words clears the words.
    await asks.doc('q_2').set({..._questionAsk('q_2'), 'at': '2026-09-03T20:01:00Z'});
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'maybe');
    await tester.pump();
    await tester.tap(find.text('Hold two'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await tester.tap(answer);
    await _settle(tester);
    final second = (await db.collection('projects').doc('demo').collection('commands').orderBy('sentAt').get()).docs.last.data();
    expect(((second['response'] as Map)['updatedInput'] as Map)['answers'], {'Ship the artwork slots?': 'Hold two'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('This session and Always travel with the command', (tester) async {
    final db = FakeFirebaseFirestore();
    final asks = db.collection('projects').doc('demo').collection('asks');
    await asks.doc('req_1').set(_bashAsk('req_1'));
    await tester.pumpWidget(MaterialApp(theme: kitTheme(KitTokens.dark), home: Scaffold(body: Column(children: [RemoteAskPanel(db: db, slug: 'demo')]))));
    await _settle(tester);
    await tester.tap(find.text('THIS SESSION'));
    await _settle(tester);
    var cmds = await db.collection('projects').doc('demo').collection('commands').get();
    expect(cmds.docs.single.data()['remember'], isTrue);
    expect((cmds.docs.single.data()['response'] as Map)['behavior'], 'allow');

    await asks.doc('req_2').set(_bashAsk('req_2', at: '2026-08-30T12:02:00Z'));
    await _settle(tester);
    await tester.tap(find.text('ALWAYS'));
    await _settle(tester);
    cmds = await db.collection('projects').doc('demo').collection('commands').orderBy('sentAt').get();
    final always = cmds.docs.last.data();
    expect(always['requestId'], 'req_2');
    expect((always['response'] as Map)['updatedPermissions'], isNotEmpty);
    expect(always['summary'], 'Allowed, always');
  });
}
