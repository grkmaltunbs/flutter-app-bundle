// The thread over a fake relay: the rows render (question, reply, the
// UPDATED strip), the composer sends through the callback, and a card
// wears its thread summary. At phone width and the largest text size.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/draft.dart';
import 'package:kit_app/src/relay.dart';
import 'package:kit_app/src/screens/item_card.dart';
import 'package:kit_app/src/screens/thread_sheet.dart';
import 'package:kit_app/src/theme.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  for (final scale in [1.0, 3.12]) {
    testWidgets('at ${scale}x: the thread renders and the composer sends', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = FakeFirebaseFirestore();
      final msgs = db.collection('projects').doc('demo').collection('threads').doc('item:presence').collection('messages');
      await msgs.doc('s1-m00000').set({'id': 'm00000', 'role': 'user', 'text': 'What does friends-only cost in reads?', 'at': '2026-08-30T12:00:00Z', 'about': {'item': 'presence'}, 'isError': false, 'streaming': false});
      await msgs.doc('s1-m00001').set({'id': 'm00001', 'role': 'assistant', 'text': 'About **50 reads** per home-screen open.', 'at': '2026-08-30T12:00:20Z', 'about': {'item': 'presence'}, 'isError': false, 'streaming': false});
      await msgs.doc('upd-1').set({'id': 'upd-1', 'role': 'note', 'text': 'UPDATED · body, needs', 'at': '2026-08-30T12:00:30Z', 'about': {'item': 'presence'}, 'isError': false, 'streaming': false});

      final sent = <String>[];
      await tester.pumpWidget(MaterialApp(
        theme: kitTheme(scale == 3.12 ? KitTokens.dark : KitTokens.light),
        home: MediaQuery(
          data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: ThreadView(
              db: db,
              slug: 'demo',
              about: const {'item': 'presence'},
              title: 'Presence is readable by any signed-in account',
              running: true,
              onSend: (t) async {
                sent.add(t);
                return null;
              },
            ),
          ),
        ),
      ));
      await _settle(tester);
      expect(find.text('ASK ABOUT THIS ITEM'), findsOneWidget);
      expect(find.text('What does friends-only cost in reads?'), findsOneWidget);
      // At the largest scale the reply is below the fold; scroll to it.
      final list = find.byType(Scrollable).first;
      await tester.dragUntilVisible(find.textContaining('50 reads', findRichText: true), list, const Offset(0, -200));
      expect(find.textContaining('50 reads', findRichText: true), findsOneWidget);
      await tester.dragUntilVisible(find.textContaining('UPDATED · BODY, NEEDS'), list, const Offset(0, -200));
      expect(find.textContaining('UPDATED · BODY, NEEDS'), findsOneWidget, reason: 'the strip, uppercased');
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'And with a cache?');
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await _settle(tester);
      expect(sent, ['And with a cache?']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a stopped session leaves the composer off with the hint', (tester) async {
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.dark),
      home: Scaffold(body: ThreadView(db: db, slug: 'demo', about: const {'step': 'instrument-skin'}, title: 'The skin', running: false, onSend: (_) async => null)),
    ));
    await _settle(tester);
    expect(find.text('ASK ABOUT THIS STEP'), findsOneWidget);
    expect(find.textContaining('Session not running'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an item card wears its thread: the strip, the count, and ASK opens it', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = PlanStore('${Directory.systemTemp.createTempSync('kit_thread_card_').path}/plan');
    store.writeManifest(Manifest(projectName: 'Demo'));
    store.writeStep(Step(id: 'a', title: 'A', rank: 1, status: StepStatus.active));
    store.writeItem(Item(id: 'presence', title: 'Presence is readable by anyone', needs: ['decision'], blocks: ['a']));
    final plan = store.load();
    var asked = 0;
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.dark),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ItemCard(
            item: plan.item('presence')!,
            plan: plan,
            graph: Graph(plan),
            draft: Draft('t'),
            needs: plan.manifest.needs,
            decisive: true,
            thread: ThreadSummary(
              key: 'item:presence',
              about: const {'item': 'presence'},
              count: 3,
              lastRole: 'assistant',
              lastText: 'About 50 reads per open.',
              lastAt: DateTime.now(),
              updatedFields: const ['body', 'needs'],
              updatedAt: DateTime.now(),
            ),
            onAsk: () => asked++,
          ),
        ),
      ),
    ));
    await _settle(tester);
    expect(find.textContaining('UPDATED · BODY, NEEDS'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'the thread count');
    expect(find.textContaining('About 50 reads'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('ASK'));
    await tester.tap(find.text('ASK'));
    expect(asked, 1);
  });
}
