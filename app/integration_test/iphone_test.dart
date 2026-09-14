// Native iOS bootstrap plus the actual phone widgets over an isolated relay.
// No credentials, live project writes, or engine calls are made by this test.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kit_app/firebase_options.dart';
import 'package:kit_app/src/app.dart';
import 'package:kit_app/src/draft.dart';
import 'package:kit_app/src/push/local_notices.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/screens/sign_in_screen.dart';
import 'package:kit_app/src/screens/steps_tab.dart';
import 'package:kit_app/src/screens/work_tab.dart';
import 'package:kit_app/src/theme.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

Widget shell(Widget child) => MaterialApp(theme: kitTheme(KitTokens.light), home: Scaffold(body: SafeArea(child: child)));

Future<void> settle(WidgetTester tester) async {
  // The Deck and constellation have intentional repeating animations.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iPhone: native Firebase, notifications, shares, and sign-in bootstrap', (tester) async {
    expect(Platform.isIOS, isTrue, reason: 'Run this integration suite on an iOS simulator.');
    expect(isHost, isFalse);
    final app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    expect(app.options.projectId, 'flutterappbundle');
    expect(app.options.iosBundleId, 'dev.flutterkit.kitApp');
    await LocalNotices.init();
    await LocalNotices.launchData();
    await ReceiveSharingIntent.instance.getInitialMedia();
    await ReceiveSharingIntent.instance.reset();
    await tester.pumpWidget(shell(const SignInScreen()));
    await settle(tester);
    expect(find.text('K.A.T.Y.A'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPhone: scratch Deck start, send, permission and question answers', (tester) async {
    final db = FakeFirebaseFirestore();
    final project = db.collection('projects').doc('scratch');
    await project.set({'name': 'Scratch', 'session': {'mode': 'idle', 'state': 'idle'}});
    await tester.pumpWidget(shell(RemoteDeckTab(db: db, slug: 'scratch')));
    await settle(tester);
    await tester.tap(find.text('START'));
    await settle(tester);
    expect((await project.collection('commands').get()).docs.single.data()['type'], 'start');
    await project.set({'session': {'mode': 'bridge', 'state': 'ready', 'sessionId': 'iphone-qa', 'engine': 'codex', 'model': 'gpt-6-astra'}}, SetOptions(merge: true));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Hello from iPhone');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await settle(tester);
    var commands = (await project.collection('commands').get()).docs.map((d) => d.data()).toList();
    expect(commands.where((c) => c['type'] == 'send').single['text'], 'Hello from iPhone');

    final asks = project.collection('asks');
    await asks.doc('permission').set({
      'requestId': 'permission', 'toolName': 'Bash', 'toolUseId': 't1',
      'input': {'command': 'echo scratch'}, 'at': '2026-09-13T12:00:00Z',
      'engine': 'codex', 'requiresUserInteraction': false, 'answeredAt': null,
    });
    await project.set({'session': {'state': 'waiting', 'pendingAsks': 1}}, SetOptions(merge: true));
    await settle(tester);
    expect(find.text('AUTHORIZATION REQUESTED'), findsOneWidget);
    await tester.ensureVisible(find.text('DENY'));
    await tester.tap(find.text('DENY'));
    await settle(tester);
    commands = (await project.collection('commands').get()).docs.map((d) => d.data()).toList();
    expect((commands.singleWhere((c) => c['requestId'] == 'permission')['response'] as Map)['behavior'], 'deny');
    await asks.doc('permission').update({'answeredAt': '2026-09-13T12:00:01Z'});
    await asks.doc('question').set({
      'requestId': 'question', 'toolName': 'AskUserQuestion', 'toolUseId': 't2',
      'input': {'questions': [{'question': 'Which device?', 'header': 'Device', 'multiSelect': false, 'options': [{'label': 'iPhone', 'description': 'This simulator'}, {'label': 'Android', 'description': 'Another phone'}]}]},
      'at': '2026-09-13T12:00:02Z', 'engine': 'codex', 'requiresUserInteraction': true, 'answeredAt': null,
    });
    await settle(tester);
    await tester.ensureVisible(find.text('iPhone'));
    await tester.tap(find.text('iPhone'));
    await settle(tester);
    final answer = find.text('ANSWER');
    await tester.ensureVisible(answer);
    await tester.tap(answer);
    await settle(tester);
    commands = (await project.collection('commands').get()).docs.map((d) => d.data()).toList();
    final question = commands.singleWhere((c) => c['requestId'] == 'question');
    expect(question['response'].toString(), contains('iPhone'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  });

  testWidgets('iPhone: /model selects locally and reports confirmed turns without relabelling history', (tester) async {
    final db = FakeFirebaseFirestore();
    final project = db.collection('projects').doc('scratch');
    const astra = 'gpt-6-astra';
    const luna = 'gpt-5.6-luna';
    await project.set({'name': 'Scratch', 'session': {
      'mode': 'bridge', 'state': 'ready', 'sessionId': 'model-qa', 'engine': 'codex',
      'models': [astra, luna], 'modelChoice': astra, 'model': astra,
      'confirmedModel': astra, 'modelConfirmation': 'confirmed',
    }});
    Map<String, Object?> row(String id, String model, String text) => {
      'id': id, 'role': 'assistant', 'text': text, 'model': model,
      'at': '2026-09-14T12:00:00Z', 'sessionId': 'model-qa',
    };
    await project.collection('chat').doc('m00000').set(row('m00000', astra, 'Before the model switch.'));
    await tester.pumpWidget(shell(RemoteDeckTab(db: db, slug: 'scratch')));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '/model');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await settle(tester);
    expect(find.text('CODEX MODEL'), findsOneWidget);
    expect((await project.collection('commands').get()).docs, isEmpty);
    await tester.tap(find.byKey(const ValueKey('model-choice-gpt-5.6-luna')));
    await settle(tester);
    var commands = (await project.collection('commands').get()).docs;
    expect(commands, hasLength(1));
    expect(commands.single.data()['type'], 'options');
    expect(commands.single.data()['model'], luna);
    await project.update({'session.modelChoice': luna, 'session.modelConfirmation': 'pending'});
    await commands.single.reference.update({'doneAt': DateTime.now().toUtc().toIso8601String(), 'result': 'applies to the next turn'});
    await settle(tester);
    expect(find.text('CODEX MODEL'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect((await project.collection('chat').get()).docs, hasLength(1), reason: '/model never creates a chat turn');
    await tester.tap(find.byTooltip('Show session controls'));
    await settle(tester);
    expect(find.textContaining('Last server confirmed: $astra'), findsOneWidget);
    expect(find.text('Server confirmed: $luna'), findsNothing, reason: 'saving a selection is not server confirmation');
    await project.update({'session.model': luna, 'session.confirmedModel': luna, 'session.modelConfirmation': 'confirmed'});
    await project.collection('chat').doc('m00001').set(row('m00001', luna, 'After the model switch.'));
    await settle(tester);
    expect(find.text('Server confirmed: $luna'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide session controls'));
    await settle(tester);
    expect(find.text('Model: $astra'), findsOneWidget);
    expect(find.text('Model: $luna'), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '/model default');
    await settle(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '/model default');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);
    commands = (await project.collection('commands').get()).docs;
    expect(commands, hasLength(2));
    final reset = commands.singleWhere((c) => c.data()['model'] == 'default');
    expect(reset.data()['type'], 'options');
    await project.update({'session.modelChoice': 'default', 'session.modelConfirmation': 'pending'});
    await reset.reference.update({'doneAt': DateTime.now().toUtc().toIso8601String(), 'result': 'applies to the next turn'});
    await settle(tester);
    await project.update({'session.model': astra, 'session.confirmedModel': astra, 'session.modelConfirmation': 'confirmed'});
    await settle(tester);
    expect(find.text('Model: $luna'), findsOneWidget, reason: 'the older Luna reply keeps its provenance after default resolves to Astra');
    await tester.tap(find.byType(TextField));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '/model not-a-model');
    await settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '/model not-a-model');
    expect((await project.collection('commands').get()).docs, hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  });

  testWidgets('iPhone: constellation selection and work-item draft persist', (tester) async {
    final plan = Plan(manifest: Manifest(projectName: 'Scratch'), steps: [Step(id: 'iphone', number: '1', title: 'iPhone simulator', rank: 10)], items: [Item(id: 'check', title: 'Check the simulator', needs: ['device'], blocks: ['iphone'])]);
    final graph = Graph(plan);
    String? selected;
    await tester.pumpWidget(shell(StepsTab(plan: plan, graph: graph, selected: null, onSelect: (id) => selected = id)));
    await settle(tester);
    await tester.tap(find.text('1').first);
    await settle(tester);
    expect(selected, 'iphone');
    final draft = Draft('scratch-iphone-qa');
    await draft.clear();
    await tester.pumpWidget(shell(WorkTab(plan: plan, graph: graph, draft: draft)));
    await settle(tester);
    expect(find.text('Check the simulator'), findsOneWidget);
    await tester.ensureVisible(find.text('DONE').last);
    await tester.tap(find.text('DONE').last);
    await settle(tester);
    expect(draft.items['check']?.action, 'done');
    final restored = Draft('scratch-iphone-qa');
    await restored.load();
    expect(restored.items['check']?.action, 'done');
    await draft.clear();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  });
}
