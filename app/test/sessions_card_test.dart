// The sessions card and its sheet at phone width and every text scale:
// the conversation on the Deck on the card, the whole list in the sheet
// newest first, RESUME and the bin as commands, NEW — no overflow.
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/theme.dart';
import 'package:kit_app/src/widgets/sessions_card.dart';

Widget _app(Widget child, {double scale = 1.0}) => MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: SingleChildScrollView(child: child))),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final now = DateTime(2026, 9, 9, 15, 0);
  final a = SessionEntry(id: 'aaaaaaaa-0000-4000-8000-000000000001', startedAt: DateTime(2026, 9, 8, 10, 5), endedAt: DateTime(2026, 9, 8, 11), firstMessage: 'remember falcon', turns: 3, model: 'claude-fable-5-1', mode: 'default');
  final b = SessionEntry(id: 'bbbbbbbb-0000-4000-8000-000000000002', startedAt: DateTime(2026, 9, 9, 14, 30), firstMessage: 'remember heron, and a first line long enough that a phone has to cut it because it goes on and on and on', turns: 1, model: 'claude-fable-5-1', mode: 'plan');

  for (final scale in [1.0, 2.0, 3.12]) {
    testWidgets('at ${scale}x: the card shows the conversation on the Deck; the sheet lists all, newest first; RESUME, NEW and the bin are the commands — no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      await tester.pumpWidget(_app(
        SessionsCard(
          sessions: [a, b],
          currentId: b.id,
          running: true,
          turnOpen: false,
          onResume: (id) async {
            calls.add('resume:$id');
            return 'resumed';
          },
          onNew: () async {
            calls.add('new');
            return 'a new session';
          },
          onDelete: (id) async {
            calls.add('delete:$id');
            return 'removed';
          },
          now: () => now,
        ),
        scale: scale,
      ));
      await _settle(tester);
      expect(find.text('SESSIONS · 2'), findsOneWidget);
      expect(find.textContaining('remember heron'), findsOneWidget);
      expect(find.text('today 14:30 · 1 turn · claude-fable-5-1 · live'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('NEW'));
      await _settle(tester);
      expect(calls, ['new']);
      expect(find.text('a new session'), findsOneWidget, reason: 'the line toasted');

      await tester.tap(find.text('ALL'));
      await _settle(tester);
      expect(find.text('SESSIONS'), findsOneWidget);
      expect(find.textContaining('remember falcon'), findsOneWidget);
      expect(find.text('yesterday 10:05 · 3 turns · claude-fable-5-1 · default'), findsOneWidget);
      expect(find.text('today 14:30 · 1 turn · claude-fable-5-1 · live · plan'), findsOneWidget);
      final heronY = tester.getTopLeft(find.textContaining('remember heron').last).dy;
      final falconY = tester.getTopLeft(find.textContaining('remember falcon')).dy;
      expect(heronY < falconY, isTrue, reason: 'newest first');
      expect(find.text('RESUME'), findsOneWidget, reason: 'the live one has none');
      await tester.ensureVisible(find.text('RESUME'));
      await tester.tap(find.text('RESUME'));
      await _settle(tester);
      expect(calls, ['new', 'resume:${a.id}']);
      expect(find.text('SESSIONS'), findsNothing, reason: 'the sheet closed');
      expect(tester.takeException(), isNull);

      // The bin: a confirm, then the command. The live one's bin is off.
      await tester.tap(find.text('ALL'));
      await _settle(tester);
      final bins = find.byIcon(Icons.delete_outline);
      expect(bins, findsNWidgets(2));
      expect(tester.widget<IconButton>(find.ancestor(of: bins.first, matching: find.byType(IconButton))).onPressed, isNull, reason: 'the live one');
      await tester.ensureVisible(bins.last);
      await tester.tap(bins.last);
      await _settle(tester);
      expect(find.text('Remove from the list?'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await _settle(tester);
      expect(calls.length, 2);
      await tester.tap(bins.last);
      await _settle(tester);
      await tester.tap(find.text('REMOVE'));
      await _settle(tester);
      expect(calls.last, 'delete:${a.id}');
      expect(find.text('SESSIONS'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nothing on the Deck: the card says so; a running turn holds NEW and RESUME', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<String?> none(String _) async => null;
    await tester.pumpWidget(_app(SessionsCard(sessions: const [], running: false, turnOpen: false, onResume: none, onNew: () async => null, onDelete: none, now: () => now)));
    await _settle(tester);
    expect(find.text('SESSIONS · 0'), findsOneWidget);
    expect(find.textContaining('No conversation yet'), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'ALL')).enabled, isFalse);

    await tester.pumpWidget(_app(SessionsCard(sessions: [a], running: false, turnOpen: false, onResume: none, onNew: () async => null, onDelete: none, now: () => now)));
    await _settle(tester);
    expect(find.textContaining('Nothing on the Deck'), findsOneWidget);

    await tester.pumpWidget(_app(SessionsCard(sessions: [a, b], currentId: b.id, running: true, turnOpen: true, onResume: none, onNew: () async => null, onDelete: none, now: () => now)));
    await _settle(tester);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'NEW')).enabled, isFalse);
    await tester.tap(find.text('ALL'));
    await _settle(tester);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'RESUME')).enabled, isFalse, reason: 'mid-turn');
    expect(tester.takeException(), isNull);
  });

  test('the labels: today, yesterday, a date, the year when it differs; the session line', () {
    expect(whenLabel(DateTime(2026, 9, 9, 8, 3), now: now), 'today 08:03');
    expect(whenLabel(DateTime(2026, 9, 8, 23, 59), now: now), 'yesterday 23:59');
    expect(whenLabel(DateTime(2026, 9, 1, 12, 0), now: now), '1 Sep 12:00');
    expect(whenLabel(DateTime(2025, 12, 31, 12, 0), now: now), '31 Dec 2025 12:00');
    expect(sessionLine(a, now: now), 'yesterday 10:05 · 3 turns · claude-fable-5-1');
    expect(sessionLine(b, now: now), 'today 14:30 · 1 turn · claude-fable-5-1 · open');
    expect(sessionLine(b, now: now, running: true), 'today 14:30 · 1 turn · claude-fable-5-1 · live');
    expect(sortedSessions([a, b]).map((s) => s.id), [b.id, a.id]);
  });
}
