// Rich pushes: a phone's quiet hours hold Turn ended and problems on the
// Mac for one digest; the sheet that sets the window; the Deck landing on
// the turn a push named.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/host/push_sender.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/theme.dart';
import 'package:kit_app/src/widgets/quiet_hours_sheet.dart';

class _FixedMinter implements TokenMinter {
  @override
  String get projectId => 'flutterappbundle';
  @override
  String get who => 'pusher@flutterappbundle.iam.gserviceaccount.com';
  @override
  Future<String> token() async => 'tok-1';
}

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Map<String, Object?> _data(http.Request r) {
  final m = (jsonDecode(r.body) as Map)['message'] as Map;
  return {'token': m['token'], ...((m['data'] as Map?) ?? const {}).cast<String, Object?>()};
}

void main() {
  test('a phone in its quiet hours: Turn ended and a problem wait, an ask and a dead session go through; one digest at the window\'s end; the window turned off flushes', () async {
    final db = FakeFirebaseFirestore();
    final home = Directory.systemTemp.createTempSync('kit-quiet-');
    addTearDown(() => home.deleteSync(recursive: true));
    final posted = <http.Request>[];
    final client = MockClient((r) async {
      posted.add(r);
      return http.Response('{"name":"projects/x/messages/1"}', 200);
    });
    var now = DateTime.utc(2026, 9, 10, 23, 30);
    await db.collection('devices').doc('T1').set({'platform': 'android', 'name': 'Pixel', 'quiet': {'on': true, 'start': '23:00', 'end': '08:00', 'offset': 0}});
    await db.collection('devices').doc('T2').set({'platform': 'android', 'name': 'Spare'});
    final sender = PushSender(db: db, home: home.path, client: client, minter: _FixedMinter(), now: () => now);
    addTearDown(sender.dispose);
    sender.start();
    await _settle();
    expect(sender.quietNow('T1'), isTrue);
    expect(sender.quietNow('T2'), isFalse);

    final done = noticeForDone(const ResultEvent(subtype: 'success', sessionId: 's', text: 'Added the route.'), project: 'Kit');
    expect(await sender.send(done, slug: 'kit', project: 'Kit'), 1, reason: 'the spare phone hears it now');
    expect(posted.map((r) => _data(r)['token']), ['T2']);
    expect(sender.heldFor('kit'), 1);
    expect(sender.quietLine('kit'), 'Quiet hours 23:00–08:00 on Pixel · 1 held for this project until 08:00');

    posted.clear();
    await sender.send(noticeForAsk(Ask.fromMap({'requestId': 'r1', 'toolName': 'Bash', 'toolUseId': 't1', 'at': '2026-09-10T23:31:00Z', 'input': {'command': 'ls'}}), project: 'Kit'), slug: 'kit');
    expect(posted.map((r) => _data(r)['token']).toSet(), {'T1', 'T2'}, reason: 'asks always push');
    posted.clear();
    await sender.send(noticeForProblem('claude exited with code 1', project: 'Kit', urgent: true), slug: 'kit');
    expect(posted.map((r) => _data(r)['token']).toSet(), {'T1', 'T2'}, reason: 'a dead session pushes at once');
    posted.clear();
    await sender.send(noticeForProblem('the turn ended in an error', project: 'Kit'), slug: 'kit');
    expect(posted.map((r) => _data(r)['token']), ['T2']);
    expect(sender.heldFor('kit'), 2);
    posted.clear();

    now = DateTime.utc(2026, 9, 10, 23, 40);
    expect(await sender.flushDue(), 0, reason: 'still the window');
    expect(posted, isEmpty);
    now = DateTime.utc(2026, 9, 11, 8, 0);
    final before = sender.sent;
    expect(await sender.flushDue(), 1);
    final digest = _data(posted.single);
    expect(digest['token'], 'T1');
    expect(digest['title'], 'While you slept · Kit');
    expect(digest['body'], '1 turn ended · 1 problem\nthe turn ended in an error');
    expect(digest['channel'], 'problems');
    expect(digest['digest'], '2');
    expect(digest['slug'], 'kit');
    expect(sender.heldFor('kit'), 0);
    expect(sender.sent, before + 1);
    expect(sender.quietLine('kit'), 'Quiet hours 23:00–08:00 on Pixel');
    posted.clear();

    // Held again that night; the window switched off on the phone: due now.
    now = DateTime.utc(2026, 9, 11, 23, 30);
    await sender.send(done, slug: 'kit', project: 'Kit');
    expect(sender.heldFor('kit'), 1);
    posted.clear();
    await db.collection('devices').doc('T1').set({'quiet': {'on': false, 'start': '23:00', 'end': '08:00', 'offset': 0}}, SetOptions(merge: true));
    await _settle();
    expect(sender.quietNow('T1'), isFalse);
    expect(await sender.flushDue(), 1);
    expect(_data(posted.single)['body'], '1 turn ended\nAdded the route.');
    expect(_data(posted.single)['channel'], 'done');
    expect(sender.quietLine('kit'), startsWith('Quiet hours: none set'));

    // A phone that left takes what waited for it with it.
    await db.collection('devices').doc('T1').set({'quiet': {'on': true, 'start': '23:00', 'end': '08:00', 'offset': 0}}, SetOptions(merge: true));
    await _settle();
    await sender.send(done, slug: 'kit', project: 'Kit');
    expect(sender.heldFor('kit'), 1);
    await db.collection('devices').doc('T1').delete();
    await _settle();
    expect(sender.heldFor('kit'), 0);
    expect(PushSender.projectOf(done), 'Kit');
  });

  for (final scale in [1.0, 2.0, 3.12]) {
    testWidgets('at ${scale}x: the quiet-hours sheet — the switch writes the window, the times open a picker, unregistered is told — no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final set = <QuietWindow?>[];
      Widget app(Widget child) => MaterialApp(theme: kitTheme(KitTokens.light), home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: child)));
      await tester.pumpWidget(app(QuietHoursSheet(current: null, onSet: (w) async => set.add(w), offsetMinutes: 180)));
      await tester.pumpAndSettle();
      expect(find.text('QUIET HOURS'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('23:00'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.textContaining('UTC+03:00'), findsOneWidget);
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(set.last!.on, isTrue);
      expect(set.last!.start, 23 * 60);
      expect(set.last!.end, 8 * 60);
      expect(set.last!.offset, 180);
      expect(find.text('On · 23:00–08:00'), findsOneWidget);
      await tester.ensureVisible(find.text('UNTIL'));
      await tester.tap(find.text('UNTIL'));
      await tester.pumpAndSettle();
      expect(find.text('QUIET UNTIL'), findsOneWidget, reason: 'the picker, with its own help text');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(set.length, 2);
      expect(set.last!.end, 8 * 60, reason: 'OK on the same time writes the same window');
      expect(tester.takeException(), isNull);

      // A sheet of its own — the first one's state must not carry over.
      await tester.pumpWidget(app(QuietHoursSheet(key: const ValueKey('unregistered'), current: const QuietWindow(on: true, start: 22 * 60, end: 7 * 60 + 30, offset: 0), onSet: (w) async => set.add(w), registered: false, offsetMinutes: 0)));
      await tester.pumpAndSettle();
      expect(find.text('On · 22:00–07:30'), findsOneWidget);
      expect(find.textContaining('not set up on this phone yet'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull, reason: 'nothing to write to');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a Done push\'s tap lands the Deck on the turn it named', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final messages = [for (var i = 0; i < 60; i++) DeckMessage(id: 'm$i', role: i.isEven ? DeckRole.user : DeckRole.assistant, text: 'Row $i of the conversation, long enough to wrap onto a second line on a phone.', at: DateTime(2026, 9, 10, 10, i))];
    Widget app(Widget child) => MaterialApp(theme: kitTheme(KitTokens.light), home: MediaQuery(data: const MediaQueryData(size: Size(390, 844)), child: Scaffold(body: child)));
    await tester.pumpWidget(app(DeckView(state: BridgeState.ready, title: 'Nahmatik', facts: const [], messages: messages, running: true, canResume: false, onStart: () {}, onResume: () {}, onStop: () {}, onSend: (_, _) async {}, foldOnScroll: true, focusRowId: 'm20')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final row = find.text('Row 20 of the conversation, long enough to wrap onto a second line on a phone.');
    expect(row, findsOneWidget, reason: 'the named row is built');
    final rect = tester.getRect(row);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(844));
    expect(find.text('Row 59 of the conversation, long enough to wrap onto a second line on a phone.'), findsNothing, reason: 'not pinned at the end');
    expect(tester.takeException(), isNull);
  });
}
