// The instruments: the context arc and the pool arc on the header, the
// numbers behind a tap, COMPACT past 80 %, and the same over the relay.
import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/relay.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/theme.dart';
import 'package:kit_app/src/widgets/common.dart';

import 'helpers/fake_claude.dart';

Widget _app(Widget child, {required double scale}) => MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: child)),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

DeckView _deck({required int used, required int window, RateLimitEvent? pool, bool turnOpen = true, bool compacting = false, VoidCallback? onCompact, List<DeckMessage> messages = const []}) => DeckView(
      state: turnOpen ? BridgeState.busy : BridgeState.ready,
      title: 'Nahmatik',
      facts: const ['session abcd1234', 'claude-fable-5-1', 'claude 2.1.261'],
      messages: messages,
      running: true,
      canResume: false,
      turnOpen: turnOpen,
      onStart: () {},
      onResume: () {},
      onStop: () {},
      onSend: (_, _) async {},
      onInterrupt: () {},
      foldOnScroll: false,
      contextUsed: used,
      contextWindow: window,
      pool: pool,
      compacting: compacting,
      onCompact: onCompact,
    );

void main() {
  final resets = DateTime.now().add(const Duration(minutes: 72, seconds: 30));
  final pool = RateLimitEvent(status: 'allowed', fiveHour: PoolWindow(utilization: 0.19, resetsAt: resets), sevenDay: PoolWindow(utilization: 0.04, resetsAt: resets.add(const Duration(days: 4))));

  for (final scale in [1.0, 2.0, 3.12]) {
    testWidgets('at ${scale}x: two arcs, COMPACT at 80 %, the numbers on a tap, no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var compacts = 0;
      final row = DeckMessage(id: 'm1', role: DeckRole.assistant, text: 'Counted.', at: DateTime(2026, 9, 6, 1, 2), turn: const Usage(input: 32, cacheCreation: 3892, cacheRead: 20504, output: 3747));
      await tester.pumpWidget(_app(_deck(used: 160000, window: 200000, pool: pool, onCompact: () => compacts++, messages: [row]), scale: scale));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'header with INTERRUPT and the pill');
      expect(find.byType(GaugeArc), findsNWidgets(2));
      expect(find.text('COMPACT'), findsOneWidget, reason: 'offered at 80 %');
      expect(find.textContaining('24.4K CTX · 3.7K OUT'), findsOneWidget, reason: 'the turn costed on its row');
      // The numbers.
      await tester.tap(find.byType(GaugeArc).first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('INSTRUMENTS'), findsOneWidget);
      expect(find.textContaining('160,000 / 200,000 tokens · 80 %'), findsOneWidget);
      expect(find.textContaining('19 % used · resets in 1 h 12 m'), findsOneWidget);
      expect(find.textContaining('4 % used · resets in 4 d 1 h'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'COMPACT')).onPressed, isNull, reason: 'a turn runs');
      expect(tester.takeException(), isNull, reason: 'sheet');
      await tester.tapAt(const Offset(180, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('INSTRUMENTS'), findsNothing);
      // The pill waits for the turn to end: its tap falls through to the
      // gauges and opens the numbers instead.
      await tester.tap(find.text('COMPACT'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(compacts, 0);
      expect(find.text('INSTRUMENTS'), findsOneWidget);
      await tester.tapAt(const Offset(180, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Idle: the pill sends; below 80 % it is not there.
      await tester.pumpWidget(_app(_deck(used: 160000, window: 200000, pool: pool, turnOpen: false, onCompact: () => compacts++), scale: scale));
      await _settle(tester);
      await tester.ensureVisible(find.text('COMPACT'));
      await tester.pump();
      await tester.tap(find.text('COMPACT'));
      await _settle(tester);
      expect(compacts, 1);
      await tester.pumpWidget(_app(_deck(used: 100000, window: 200000, pool: pool, turnOpen: false, onCompact: () => compacts++), scale: scale));
      await _settle(tester);
      expect(find.text('COMPACT'), findsNothing);
      expect(tester.takeException(), isNull);

      // Compacting: the pill says so and takes no tap.
      await tester.pumpWidget(_app(_deck(used: 160000, window: 200000, pool: pool, turnOpen: true, compacting: true, onCompact: () => compacts++), scale: scale));
      await _settle(tester);
      expect(find.text('COMPACTING…'), findsOneWidget);

      // The pool refused: the line under the title says when it is back.
      final refused = RateLimitEvent(status: 'rejected', resetsAt: resets, fiveHour: PoolWindow(utilization: 1.0, resetsAt: resets));
      await tester.pumpWidget(_app(_deck(used: 20000, window: 200000, pool: refused, turnOpen: false), scale: scale));
      await _settle(tester);
      expect(find.text('POOL EXHAUSTED · RESETS IN 1 H 12 M'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no session, no arcs', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_deck(used: 0, window: 0, turnOpen: false), scale: 1.0));
    await _settle(tester);
    expect(find.byType(GaugeArc), findsNothing);
  });

  group('the host', () {
    late Directory home;
    late Directory project;
    setUp(() {
      home = Directory.systemTemp.createTempSync('kit_inst_home_');
      project = Directory.systemTemp.createTempSync('kit_inst_project_');
    });
    tearDown(() {
      home.deleteSync(recursive: true);
      project.deleteSync(recursive: true);
    });

    test('reads usage and the pool into the session doc, sends /compact, and shows the drop', () async {
      final fake = FakeClaude();
      final s = fakeSession(fake, dir: project.path, home: home.path);
      await s.start();
      final sid = s.sessionId!;
      fake.emitJson({'type': 'system', 'subtype': 'init', 'session_id': sid, 'model': 'claude-fable-5-1', 'permissionMode': 'default', 'tools': ['Bash']});
      fake.emitJson({
        'type': 'rate_limit_event',
        'rate_limit_info': {'status': 'allowed', 'resetsAt': 1788658200, 'rateLimitType': 'five_hour', 'unifiedWindows': {'five_hour': {'utilization': 0.19, 'resetsAt': 1788658200}, 'seven_day': {'utilization': 0.04, 'resetsAt': 1789066800}}},
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      s.send('count the classes');
      fake.emitJson({
        'type': 'assistant',
        'message': {'role': 'assistant', 'model': 'claude-fable-5-1', 'content': [{'type': 'text', 'text': 'Counted.'}], 'usage': {'input_tokens': 32, 'cache_creation_input_tokens': 3892, 'cache_read_input_tokens': 20504, 'output_tokens': 2}},
        'session_id': sid,
      });
      fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'num_turns': 1, 'session_id': sid, 'usage': {'input_tokens': 130, 'output_tokens': 3747}, 'modelUsage': {'claude-fable-5-1': {'contextWindow': 1000000}}});
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(s.transcript.contextUsed, 24428);
      final relay = s.toRelay();
      expect(relay['context'], {'used': 24428, 'window': 1000000, 'at': isA<String>()});
      expect((relay['pool'] as Map)['fiveHour'], {'utilization': 0.19, 'resetsAt': '2026-09-06T01:30:00.000Z'});
      expect(relay['compacting'], isFalse);
      expect(s.transcript.messages.last.turn!.output, 3747);

      expect(s.compact(), 'compacting');
      await fake.writtenLines(2);
      final line = jsonDecode(fake.written.last) as Map;
      expect(line['message']['content'], '/compact');
      fake.emitJson({'type': 'system', 'subtype': 'status', 'status': 'compacting', 'session_id': sid});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(s.toRelay()['compacting'], isTrue);
      fake.emitJson({'type': 'system', 'subtype': 'status', 'status': null, 'compact_result': 'success', 'session_id': sid});
      fake.emitJson({'type': 'system', 'subtype': 'init', 'session_id': sid, 'model': 'claude-fable-5-1', 'permissionMode': 'default', 'tools': ['Bash']});
      fake.emitJson({'type': 'system', 'subtype': 'compact_boundary', 'session_id': sid, 'compact_metadata': {'trigger': 'manual', 'pre_tokens': 80559, 'post_tokens': 3596}});
      fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'num_turns': 0, 'session_id': sid, 'usage': {'input_tokens': 0, 'output_tokens': 0}});
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(s.toRelay()['compacting'], isFalse);
      expect(s.transcript.contextUsed, 3596);
      expect(s.transcript.messages.last.text, 'Compacted · 80.6K → 3.6K tokens.');
      expect(s.transcript.turnOpen, isFalse);
      // A turn running: /compact waits its turn like any message.
      s.send('and now?');
      expect(s.compact(), 'queued');
      await s.stop();
      expect(s.compact(), 'no session');
    });
  });

  test('the phone reads the instruments off the session and sends compact as a command', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('projects').doc('nahmatik').set({
      'machine': 'mac',
      'session': {
        'mode': 'bridge',
        'state': 'ready',
        'context': {'used': 24428, 'window': 1000000, 'at': '2026-09-06T01:00:00.000Z'},
        'pool': {'status': 'allowed', 'fiveHour': {'utilization': 0.19, 'resetsAt': '2026-09-06T01:30:00.000Z'}, 'sevenDay': {'utilization': 0.04, 'resetsAt': '2026-09-10T18:00:00.000Z'}},
        'compacting': true,
      },
    });
    final d = RemoteDeck(db, 'nahmatik')..start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(d.contextUsed, 24428);
    expect(d.contextWindow, 1000000);
    expect(d.pool!.fiveHour!.utilization, 0.19);
    expect(d.pool!.sevenDay!.resetsAt, DateTime.utc(2026, 9, 10, 18));
    expect(d.compacting, isTrue);
    await d.compact();
    final cmds = await db.collection('projects').doc('nahmatik').collection('commands').get();
    expect(cmds.docs.map((c) => c.data()['type']), ['compact']);
    d.dispose();
  });
}
