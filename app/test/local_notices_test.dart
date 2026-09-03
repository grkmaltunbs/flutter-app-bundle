// The phone draws the Mac's data messages itself, and a button answers
// the ask without the app: the pure parts, over a fake relay.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/push_sender.dart';
import 'package:kit_app/src/push/local_notices.dart';

void main() {
  Ask bash(String id) => Ask.fromMap({'requestId': id, 'toolName': 'Bash', 'toolUseId': 't$id', 'at': '2026-09-04T10:00:00Z', 'input': {'command': 'touch /tmp/kit-lock'}, 'description': 'A marker'});

  test('a data message from the Mac becomes the notification the phone draws: words, channel, buttons, a stable id', () {
    final data = androidData(noticeForAsk(bash('req_1'), project: 'Kit'), slug: 'kit');
    final n = LocalNotice.from(data)!;
    expect(n.title, 'Allow Run? · Kit');
    expect(n.body, 'touch /tmp/kit-lock');
    expect(n.channel, NoticeChannel.asks);
    expect(n.isAsk, isTrue);
    expect(n.actions.map((a) => '${a.id}=${a.label}'), ['allow=Allow', 'deny=Deny']);
    expect(n.requestId, 'req_1');
    expect(n.slug, 'kit');
    expect(n.id, LocalNotice.idFor('req_1'), reason: 'an ask is its own notification');
    expect(n.id, greaterThan(0));
    expect(LocalNotice.idFor('req_1'), isNot(LocalNotice.idFor('req_2')));
    expect(jsonDecode(n.payload), data);
    expect(LocalNotice.from(LocalNotices.dataOf(n.payload)!)!.id, n.id, reason: 'the payload round-trips into the same notification');
    expect(LocalNotices.dataOf('not json'), isNull);
    expect(LocalNotices.dataOf(null), isNull);

    final done = LocalNotice.from(androidData(noticeForDone(const ResultEvent(subtype: 'success', sessionId: 's', text: 'ok'), project: 'Kit'), slug: 'kit'))!;
    expect(done.channel, NoticeChannel.done);
    expect(done.actions, isEmpty);
    expect(done.isAsk, isFalse);
    expect(done.id, LocalNotice.idFor('done-kit'), reason: 'one per channel and project — the newest replaces the last');
    expect(LocalNotice.from(androidData(noticeForStep(number: '6b', title: 'X', project: 'Kit'), slug: 'kit'))!.channel, NoticeChannel.steps);
    expect(LocalNotice.from(androidData(noticeForProblem('boom', project: 'Kit'), slug: 'kit'))!.channel.high, isTrue);
    expect(NoticeChannel.steps.high, isFalse);

    expect(LocalNotice.from({'kind': 'permission', 'title': 't'}), isNull, reason: 'no project, nothing to open');
    expect(LocalNotice.from({'slug': 'kit', 'kind': 'permission', 'title': 't', 'actions': 'not json'})!.actions, isEmpty, reason: 'no buttons beats no notification');
    expect(LocalNotice.withdrawnId({'slug': 'kit', 'kind': 'withdraw', 'requestId': 'req_1'}), LocalNotice.idFor('req_1'));
    expect(LocalNotice.withdrawnId({'slug': 'kit', 'kind': 'withdraw'}), isNull);
    expect(LocalNotice.withdrawnId(data), isNull);
    expect(LocalNotice.from({'slug': 'kit', 'kind': 'withdraw', 'requestId': 'req_1'}), isNull, reason: 'a withdrawal draws nothing');
  });

  test('a button answers the ask the card would: the answer command, from the notification; stale, unknown and signed-out write nothing', () async {
    final db = FakeFirebaseFirestore();
    final asks = db.collection('projects').doc('kit').collection('asks');
    final commands = db.collection('projects').doc('kit').collection('commands');
    await asks.doc('req_1').set({...bash('req_1').toMap(), 'answeredAt': null});
    final data = androidData(noticeForAsk(bash('req_1'), project: 'Kit'), slug: 'kit');

    expect(await answerFromNotification(db, data, 'allow', signedIn: () async => true), AnswerOutcome.answered);
    var docs = (await commands.get()).docs;
    expect(docs, hasLength(1));
    final c = docs.single.data();
    expect(c['type'], 'answer');
    expect(c['requestId'], 'req_1');
    expect(c['from'], 'notification');
    expect(c['allowed'], isTrue);
    expect(c['summary'], 'Allowed');
    expect((c['response'] as Map)['behavior'], 'allow');
    expect((c['response'] as Map)['updatedInput'], {'command': 'touch /tmp/kit-lock'});
    expect(c['doneAt'], isNull, reason: 'the host stamps it when it runs');
    expect((await asks.doc('req_1').get()).data()!['answeredAt'], isNull, reason: 'the host stamps the ask, not the phone');

    expect(await answerFromNotification(db, data, 'deny'), AnswerOutcome.answered);
    docs = (await commands.get()).docs;
    expect(docs, hasLength(2));
    final deny = docs.map((d) => d.data()).firstWhere((d) => d['allowed'] == false);
    expect(deny['response'], {'behavior': 'deny', 'message': 'The user declined from the notification.'});
    expect(deny['summary'], 'Denied');

    expect(await answerFromNotification(db, data, 'option:0'), AnswerOutcome.unknown, reason: 'a permission has no options');
    expect(await answerFromNotification(db, data, 'allow', signedIn: () async => false), AnswerOutcome.signedOut);
    await asks.doc('req_1').set({'answeredAt': '2026-09-04T10:01:00Z'}, SetOptions(merge: true));
    expect(await answerFromNotification(db, data, 'allow'), AnswerOutcome.stale);
    expect(await answerFromNotification(db, {...data, 'requestId': 'req_gone'}, 'allow'), AnswerOutcome.stale);
    expect(await answerFromNotification(db, {'kind': 'permission'}, 'allow'), AnswerOutcome.unknown);
    expect((await commands.get()).docs, hasLength(2), reason: 'nothing else wrote a command');
    for (final o in AnswerOutcome.values) {
      expect(outcomeLine(o), isNotEmpty);
    }
  });
}
