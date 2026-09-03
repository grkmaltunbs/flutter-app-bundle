// The phone's side of pushes: permission, the token row, a refreshed token.
import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/push/push_registrar.dart';

void main() {
  late FakeFirebaseFirestore db;
  late StreamController<String> refresh;

  setUp(() {
    db = FakeFirebaseFirestore();
    refresh = StreamController<String>.broadcast();
  });
  tearDown(() => refresh.close());

  PushRegistrar make({bool allow = true, String? token = 'T1'}) => PushRegistrar(
        db,
        requestPermission: () async => allow,
        getToken: () async => token,
        tokenRefresh: refresh.stream,
        uid: () => 'I8XBZsWr9sScTrDAiOK2LSZ5qFZ2',
        platform: 'android',
        deviceName: 'android 14',
      );

  test('allowed: the token row is written with who and what, and stays when the token changes', () async {
    final r = make();
    await r.register();
    expect(r.registered, isTrue);
    expect(r.status, contains('Notifications on'));
    final row = (await db.collection('devices').doc('T1').get()).data()!;
    expect(row['platform'], 'android');
    expect(row['name'], 'android 14');
    expect(row['uid'], 'I8XBZsWr9sScTrDAiOK2LSZ5qFZ2');
    expect(row['registeredAt'], isNotNull);
    expect(row['seenAt'], isNotNull);

    refresh.add('T2');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(r.token, 'T2');
    expect((await db.collection('devices').doc('T2').get()).exists, isTrue);

    // Registering again touches the row, keeps its first registration.
    final first = row['registeredAt'];
    await r.register();
    expect((await db.collection('devices').doc('T1').get()).data()!['registeredAt'], first);
  });

  test('refused: nothing is written and the status says how to turn it on', () async {
    final r = make(allow: false);
    await r.register();
    expect(r.registered, isFalse);
    expect(r.status, contains('allow them for K.A.T.Y.A'));
    expect((await db.collection('devices').get()).docs, isEmpty);
  });

  test('no token from messaging is an error the bell shows, not a crash', () async {
    final r = make(token: null);
    await r.register();
    expect(r.registered, isFalse);
    expect(r.error, contains('no token'));
    expect(r.status, contains('could not be set up'));
  });

  test('a tap carries the project and the ask', () {
    expect(PushTap.from({'slug': 'kit', 'kind': 'permission', 'requestId': 'req_1'})?.requestId, 'req_1');
    expect(PushTap.from({'slug': 'kit', 'kind': 'problem'})?.requestId, isNull);
    expect(PushTap.from({'slug': 'kit', 'kind': 'problem'})?.kind, 'problem');
    expect(PushTap.from({'kind': 'problem'}), isNull, reason: 'no project, nothing to open');
    expect(PushTap.from({'slug': 'kit', 'requestId': ''})?.requestId, isNull);
  });
}
