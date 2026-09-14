import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/relay.dart';

Future<void> acknowledge(WidgetTester tester, Future<void> Function() write) async {
  await tester.runAsync(() async {
    await write();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
}

void main() {
  final now = DateTime.utc(2026, 9, 14);
  late FakeFirebaseFirestore db;
  late RemoteDeck deck;

  setUp(() {
    db = FakeFirebaseFirestore();
    deck = RemoteDeck(db, 'scratch', from: 'iphone', now: () => now);
  });
  tearDown(() => deck.dispose());

  for (final response in const [
    'applies to the next turn',
    'options saved',
    'applies when this turn ends',
    'switched in place',
  ]) {
    testWidgets('model selection awaits host acknowledgement: $response', (tester) async {
      deck.session = {
        'engine': 'codex', 'modelChoice': 'alpha',
        'confirmedModel': 'alpha', 'modelConfirmation': 'confirmed',
      };
      var completed = false;
      final selection = deck.selectModel('beta').then((_) => completed = true);
      await tester.pump();
      final commands = await deck.ref.collection('commands').get();
      expect(commands.docs.length, 1);
      final command = commands.docs.single;
      expect(command.data()['type'], 'options');
      expect(command.data()['model'], 'beta');
      expect(command.data()['from'], 'iphone');
      expect(completed, isFalse);
      expect(deck.modelChoice, 'alpha');

      // A result written before doneAt is not yet a host acknowledgement.
      await command.reference.update({'result': response});
      await tester.pump();
      expect(completed, isFalse);

      await acknowledge(tester, () => command.reference.update({'doneAt': now.toIso8601String()}));
      await tester.pump();
      await selection;
      expect(completed, isTrue);
      // Accepting a selection cannot manufacture confirmation of a turn.
      expect(deck.modelChoice, 'alpha');
      expect(deck.confirmedModel, 'alpha');
      expect(deck.modelConfirmation, ModelConfirmation.confirmed);
    });
  }

  for (final response in const [
    'Unknown Codex model "invented". Choose a model from /model.',
    'error: The Codex session is unavailable. Start it again.',
    '',
  ]) {
    testWidgets('model selection rejects unsuccessful host result: $response', (tester) async {
      Object? failure;
      var succeeded = false;
      final selection = deck.selectModel('invented').then<void>(
        (_) => succeeded = true,
        onError: (Object error) { failure = error; },
      );
      await tester.pump();
      final command = (await deck.ref.collection('commands').get()).docs.single;
      await acknowledge(tester, () => command.reference.update({'doneAt': now.toIso8601String(), 'result': response}));
      await tester.pump();
      await selection;
      expect(succeeded, isFalse);
      expect(failure, isA<StateError>());
      expect((failure as StateError).message, response.isEmpty ? 'The Mac did not confirm the model selection. Try again.' : response);
      expect(deck.modelConfirmation, ModelConfirmation.unknown);
      expect(deck.confirmedModel, isNull);
    });
  }

  testWidgets('unanswered model selection reports the Mac timeout', (tester) async {
    Object? failure;
    var succeeded = false;
    final selection = deck.selectModel('beta').then<void>(
      (_) => succeeded = true,
      onError: (Object error) { failure = error; },
    );
    await tester.pump();
    expect((await deck.ref.collection('commands').get()).docs.length, 1);
    // Advance the actual command deadline, without waiting on wall time.
    await tester.pump(const Duration(seconds: 30));
    await selection;
    expect(succeeded, isFalse);
    expect(failure, isA<TimeoutException>().having((e) => e.message, 'message', 'The Mac did not answer in 30 s.'));
    expect(deck.modelConfirmation, ModelConfirmation.unknown);
  });

  test('relay tracks pending selection separately from last confirmed turn', () async {
    deck.start();
    await deck.ref.set({'session': {
      'engine': 'codex', 'model': 'alpha', 'modelChoice': 'beta',
      'confirmedModel': 'alpha', 'modelConfirmation': 'pending',
    }});
    await pumpEventQueue();
    expect(deck.modelChoice, 'beta');
    expect(deck.confirmedModel, 'alpha');
    expect(deck.modelConfirmation, ModelConfirmation.pending);

    await deck.ref.update({'session.model': 'beta', 'session.confirmedModel': 'beta',
      'session.modelConfirmation': 'confirmed'});
    await pumpEventQueue();
    expect(deck.modelChoice, 'beta');
    expect(deck.confirmedModel, 'beta');
    expect(deck.modelConfirmation, ModelConfirmation.confirmed);
  });

  test('legacy matching model choice is not server confirmation', () async {
    deck.start();
    await deck.ref.set({'session': {
      'engine': 'codex', 'model': 'alpha', 'modelChoice': 'alpha',
    }});
    await pumpEventQueue();
    expect(deck.model, 'alpha');
    expect(deck.modelChoice, 'alpha');
    expect(deck.confirmedModel, isNull);
    expect(deck.modelConfirmation, ModelConfirmation.unknown);

    await deck.ref.update({'session.modelConfirmation': 'future-state'});
    await pumpEventQueue();
    expect(deck.modelConfirmation, ModelConfirmation.unknown);
  });

  test('publishing an explicit null clears older model confirmation', () async {
    final publisher = RelayPublisher(db, 'scratch', dir: '/scratch', machine: 'test');
    addTearDown(publisher.dispose);
    deck.start();
    await publisher.publishSession({
      'engine': 'codex', 'modelChoice': 'alpha', 'model': 'alpha',
      'confirmedModel': 'alpha', 'modelConfirmation': 'confirmed',
    });
    await pumpEventQueue();
    expect(deck.confirmedModel, 'alpha');

    await publisher.publishSession({
      'modelChoice': 'beta', 'confirmedModel': null, 'modelConfirmation': 'pending',
    });
    await pumpEventQueue();
    expect(deck.modelChoice, 'beta');
    expect(deck.confirmedModel, isNull);
    expect(deck.modelConfirmation, ModelConfirmation.pending);
    final session = (await deck.ref.get()).data()!['session'] as Map;
    expect(session.containsKey('confirmedModel'), isTrue);
    expect(session['confirmedModel'], isNull);
  });
}
