import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/push/ios_notification_actions.dart';
import 'package:kit_app/src/push/local_notices.dart';

const _channel = MethodChannel('dev.flutterkit.kitApp/notification_actions');
const _codec = StandardMethodCodec();

Map<String, Object?> _event(String request, String action) => {
      'data': {'slug': 'scratch', 'requestId': request, 'kind': 'permission', 'channel': 'asks', 'aps': {'category': 'kit.permission'}},
      'actionId': action,
      'notificationId': 'apns-$request',
    };

Ask _ask(String id) => Ask.fromMap({
      'requestId': id,
      'toolName': 'Bash',
      'toolUseId': 'tool-$id',
      'at': '2026-09-13T10:00:00Z',
      'input': {'command': 'pwd'},
    });

Future<void> _native(String method, Object? arguments) async {
  final response = Completer<ByteData?>();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    _channel.name,
    _codec.encodeMethodCall(MethodCall(method, arguments)),
    response.complete,
  );
  final data = await response.future;
  if (data != null) _codec.decodeEnvelope(data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Object?> pending;
  late List<String> handled;
  late List<String> withdrawn;

  setUp(() {
    pending = [];
    handled = [];
    withdrawn = [];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'ready':
          return List<Object?>.of(pending);
        case 'handled':
          handled.add(call.arguments as String);
          pending.removeWhere((event) => event is Map && event['notificationId'] == call.arguments);
          return null;
        case 'withdraw':
          withdrawn.add(call.arguments as String);
          return null;
        default:
          throw MissingPluginException(call.method);
      }
    });
  });

  tearDown(() {
    _channel.setMethodCallHandler(null);
    messenger.setMockMethodCallHandler(_channel, null);
  });

  test('cold-start Allow and subsequent Deny write the relay answers before acknowledging APNs', () async {
    final db = FakeFirebaseFirestore();
    final project = db.collection('projects').doc('scratch');
    await project.collection('asks').doc('cold').set(_ask('cold').toMap());
    await project.collection('asks').doc('warm').set(_ask('warm').toMap());
    pending.add(_event('cold', 'allow'));
    final bridge = IosNotificationActions(answer: (data, action) async {
      expect(handled, isNot(contains('apns-${data['requestId']}')), reason: 'keep the notification until its answer reaches the relay');
      expect(await answerFromNotification(db, data, action, signedIn: () async => true), AnswerOutcome.answered);
    });
    await bridge.start();
    expect(handled, ['apns-cold']);
    await _native('action', _event('warm', 'deny'));
    expect(handled, ['apns-cold', 'apns-warm']);
    final commands = (await project.collection('commands').get()).docs.map((d) => d.data()).toList();
    expect(commands, hasLength(2));
    final allow = commands.singleWhere((c) => c['requestId'] == 'cold');
    expect(allow['type'], 'answer');
    expect(allow['from'], 'notification');
    expect(allow['allowed'], isTrue);
    expect(allow['response'], {'behavior': 'allow', 'updatedInput': {'command': 'pwd'}});
    final deny = commands.singleWhere((c) => c['requestId'] == 'warm');
    expect(deny['allowed'], isFalse);
    expect(deny['response'], {'behavior': 'deny', 'message': 'The user declined from the notification.'});
  });

  test('malformed events and unrelated channel methods cannot answer an ask', () async {
    final answers = <String>[];
    final bridge = IosNotificationActions(answer: (data, action) async => answers.add(action));
    pending.addAll([null, 'invalid', {'data': 'invalid', 'actionId': 'allow'}, {'data': <String, Object?>{}}, {'data': <String, Object?>{}, 'actionId': ''}]);
    await bridge.start();
    await _native('other', _event('ignored', 'allow'));
    await _native('action', {'data': null, 'actionId': 'allow'});
    expect(answers, isEmpty);
    expect(handled, isEmpty);
  });

  test('a failed queued action stays pending, later actions still run, and retry handles only the failure', () async {
    var available = false;
    final answered = <String>[];
    pending.addAll([_event('offline', 'allow'), _event('available', 'deny')]);
    final bridge = IosNotificationActions(answer: (data, action) async {
      final id = data['requestId'] as String;
      if (id == 'offline' && !available) throw StateError('relay unavailable');
      answered.add(id);
    });
    await expectLater(bridge.start(), throwsStateError);
    expect(answered, ['available']);
    expect(handled, ['apns-available']);
    expect(pending, [_event('offline', 'allow')]);
    available = true;
    await bridge.start();
    expect(answered, ['available', 'offline']);
    expect(handled, ['apns-available', 'apns-offline']);
    expect(pending, isEmpty);
  });

  test('an action failure after startup is not acknowledged as handled', () async {
    final bridge = IosNotificationActions(answer: (data, action) async => throw StateError('relay unavailable'));
    await bridge.start();
    await expectLater(_native('action', _event('offline', 'allow')), throwsA(isA<PlatformException>()));
    expect(handled, isEmpty);
  });

  test('withdrawing an ask sends its request ID to the native notification center', () async {
    final bridge = IosNotificationActions(answer: (data, action) async => fail('withdrawal is not an answer'));
    await bridge.withdraw('request-withdrawn');
    expect(withdrawn, ['request-withdrawn']);
    expect(handled, isEmpty);
  });

  test('a slow answer keeps the APNs notification until relay work finishes', () async {
    final release = Completer<void>();
    final entered = Completer<void>();
    final bridge = IosNotificationActions(answer: (data, action) async {
      entered.complete();
      await release.future;
    });
    await bridge.start();
    final delivery = _native('action', _event('slow', 'allow'));
    await entered.future;
    expect(handled, isEmpty);
    release.complete();
    await delivery;
    expect(handled, ['apns-slow']);
  });
}
