// The Mac's push sender: the key, the phones, one FCM v1 request each —
// against a scripted FCM and a fake relay.
import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/host/push_sender.dart';

class _FixedMinter implements TokenMinter {
  @override
  String get projectId => 'flutterappbundle';
  @override
  String get who => 'pusher@flutterappbundle.iam.gserviceaccount.com';
  @override
  Future<String> token() async => 'tok-1';
}

Ask _bashAsk() => Ask.fromMap({'requestId': 'req_1', 'toolName': 'Bash', 'toolUseId': 't1', 'at': '2026-09-03T10:00:00Z', 'input': {'command': 'git push'}});

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late List<http.Request> posted;
  late Directory home;

  setUp(() {
    db = FakeFirebaseFirestore();
    posted = [];
    home = Directory.systemTemp.createTempSync('kit-push-');
  });
  tearDown(() => home.deleteSync(recursive: true));

  MockClient fcm(int Function(String token) status, {String body = '{"name":"projects/x/messages/1"}'}) => MockClient((r) async {
        posted.add(r);
        final token = ((jsonDecode(r.body) as Map)['message'] as Map)['token'].toString();
        final code = status(token);
        if (code == 200) return http.Response(body, 200);
        if (code == 404) {
          return http.Response(jsonEncode({'error': {'code': 404, 'message': 'Requested entity was not found.', 'status': 'NOT_FOUND', 'details': [{'@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', 'errorCode': 'UNREGISTERED'}]}}), 404);
        }
        return http.Response(jsonEncode({'error': {'code': code, 'message': 'boom', 'status': 'INTERNAL'}}), code);
      });

  test('the message names the channel, the tag and what a tap opens', () {
    final n = noticeForAsk(_bashAsk(), project: 'kit');
    final m = fcmMessage(n, slug: 'kit', token: 'T');
    expect(m['token'], 'T');
    expect(m['notification'], {'title': 'Allow Run? · kit', 'body': 'git push'});
    expect(m['data'], {'slug': 'kit', 'kind': 'permission', 'requestId': 'req_1'});
    final android = m['android'] as Map;
    expect(android['priority'], 'high');
    expect(android['notification'], {'channel_id': 'asks', 'tag': 'asks-kit', 'sound': 'default'});
    expect(((m['apns'] as Map)['payload'] as Map)['aps'], {'sound': 'default', 'thread-id': 'kit'});

    final p = fcmMessage(noticeForProblem('it broke', project: 'kit'), slug: 'kit', token: 'T');
    expect((p['android'] as Map)['notification'], {'channel_id': 'problems', 'tag': 'problems-kit', 'sound': 'default'});
    expect(p['data'], {'slug': 'kit', 'kind': 'problem'});
    final d = fcmMessage(noticeForDone(const ResultEvent(subtype: 'success', sessionId: 's', text: 'ok'), project: 'kit'), slug: 'kit', token: 'T');
    expect((d['android'] as Map)['notification'], {'channel_id': 'done', 'tag': 'done-kit', 'sound': 'default'});
    expect(d['data'], {'slug': 'kit', 'kind': 'done'});
  });

  test('no key on the Mac: not ready, the status says where it goes, nothing is sent', () async {
    final s = PushSender(db: db, home: home.path, client: fcm((_) => 200))..start();
    addTearDown(s.dispose);
    await db.collection('devices').doc('T1').set({'platform': 'android'});
    await _settle();
    expect(s.ready, isFalse);
    expect(s.status, contains(home.path));
    expect(s.status, contains('flutterappbundle-service-account.json'));
    expect(await s.send(noticeForProblem('x', project: 'kit'), slug: 'kit'), 0);
    expect(posted, isEmpty);
    expect(s.devices.keys, ['T1'], reason: 'the phones are watched all the same');
  });

  test('a file that is not a service-account key says so; one that appears later is picked up', () async {
    final key = File(serviceAccountPath(home: home.path));
    key.createSync(recursive: true);
    key.writeAsStringSync('{"type":"user"}');
    var t = DateTime(2026, 9, 3, 10);
    final s = PushSender(db: db, home: home.path, client: fcm((_) => 200), now: () => t)..start();
    addTearDown(s.dispose);
    expect(s.ready, isFalse);
    expect(s.status, contains('could not be read'));
    expect(s.status, contains('not a service-account key'));
    key.deleteSync();
    t = t.add(const Duration(seconds: 11));
    await s.send(noticeForProblem('x', project: 'kit'), slug: 'kit');
    expect(s.ready, isFalse);
    expect(s.status, contains('No service-account key'), reason: 'a missing file is not an error, just off');
  });

  test('every registered phone gets the push, with the bearer, on the project\'s FCM endpoint', () async {
    await db.collection('devices').doc('T1').set({'platform': 'android', 'name': 'Pixel'});
    await db.collection('devices').doc('T2').set({'platform': 'ios', 'name': 'iPhone'});
    var now = DateTime(2026, 9, 3, 14, 5);
    final s = PushSender(db: db, home: home.path, client: fcm((_) => 200), minter: _FixedMinter(), now: () => now)..start();
    addTearDown(s.dispose);
    await _settle();
    expect(s.ready, isTrue);
    expect(s.status, contains('2 phones registered'));
    final n = await s.send(noticeForAsk(_bashAsk(), project: 'kit'), slug: 'kit');
    expect(n, 2);
    expect(posted.length, 2);
    expect(posted.first.url.toString(), 'https://fcm.googleapis.com/v1/projects/flutterappbundle/messages:send');
    expect(posted.first.headers['Authorization'], 'Bearer tok-1');
    expect(posted.map((r) => ((jsonDecode(r.body) as Map)['message'] as Map)['token']).toSet(), {'T1', 'T2'});
    expect(s.sent, 2);
    expect(s.lastSentAt, now);
    expect(s.lastError, isNull);
    expect(s.status, contains('last sent 14:05'));
    expect(s.status, contains('pusher@flutterappbundle'));
  });

  test('a token FCM no longer knows is forgotten; the others still hear', () async {
    await db.collection('devices').doc('OLD').set({'platform': 'android'});
    await db.collection('devices').doc('NEW').set({'platform': 'android'});
    final s = PushSender(db: db, home: home.path, client: fcm((t) => t == 'OLD' ? 404 : 200), minter: _FixedMinter())..start();
    addTearDown(s.dispose);
    await _settle();
    expect(await s.send(noticeForProblem('x', project: 'kit'), slug: 'kit'), 1);
    await _settle();
    expect((await db.collection('devices').doc('OLD').get()).exists, isFalse);
    expect((await db.collection('devices').doc('NEW').get()).exists, isTrue);
    expect(s.lastError, isNull, reason: 'a stale phone is housekeeping, not a failure');
    expect(s.devices.keys, ['NEW']);
  });

  test('a failure is kept for the Session tab, the phone is not dropped', () async {
    await db.collection('devices').doc('T1').set({'platform': 'android'});
    final s = PushSender(db: db, home: home.path, client: fcm((_) => 500), minter: _FixedMinter())..start();
    addTearDown(s.dispose);
    await _settle();
    expect(await s.send(noticeForProblem('x', project: 'kit'), slug: 'kit'), 0);
    expect(s.lastError, 'FCM 500 — INTERNAL: boom');
    expect(s.status, contains('last error: FCM 500'));
    expect((await db.collection('devices').doc('T1').get()).exists, isTrue);
    expect(s.sent, 0);
  });

  test('a problem is pushed once per failure and once per failed turn; a good turn once too', () {
    final w = TurnWatch();
    Notice? check(BridgeState st, {String? error, ResultEvent? r}) => w.check(state: st, error: error, lastResult: r, project: 'kit');
    expect(check(BridgeState.ready), isNull);
    expect(check(BridgeState.busy), isNull);
    final died = check(BridgeState.failed, error: 'claude exited with code 1');
    expect(died?.kind, NoticeKind.problem);
    expect(died?.body, 'claude exited with code 1');
    expect(check(BridgeState.failed, error: 'claude exited with code 1'), isNull, reason: 'the same failure, on every repaint');
    expect(check(BridgeState.starting), isNull);
    expect(check(BridgeState.failed, error: 'claude exited with code 1')?.body, 'claude exited with code 1', reason: 'a new run that fails the same way is a new problem');

    const bad = ResultEvent(subtype: 'error_during_execution', sessionId: 's', isError: true, text: 'API error: overloaded');
    expect(check(BridgeState.ready, r: bad)?.body, 'API error: overloaded');
    expect(check(BridgeState.ready, r: bad), isNull);
    const fine = ResultEvent(subtype: 'success', sessionId: 's', text: 'All green.');
    final done = check(BridgeState.ready, r: fine);
    expect(done?.kind, NoticeKind.done);
    expect(done?.body, 'All green.');
    expect(check(BridgeState.ready, r: fine), isNull, reason: 'the same result, on every repaint');
    expect(check(BridgeState.busy, r: fine), isNull);
    const blank = ResultEvent(subtype: 'error_max_turns', sessionId: 's', isError: true);
    expect(check(BridgeState.ready, r: blank)?.body, 'The turn ended in an error.');
  });
}
