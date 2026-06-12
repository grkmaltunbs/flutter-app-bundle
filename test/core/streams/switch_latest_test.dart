import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/streams/switch_latest.dart';

void main() {
  group('switchLatest', () {
    test('emits the events of the latest inner stream only; events from a '
        'switched-away inner stream never leak', () async {
      final outer = StreamController<String>();
      final innerA = StreamController<int>();
      final innerB = StreamController<int>();
      final inners = {'a': innerA, 'b': innerB};

      final events = <int>[];
      final subscription = switchLatest(
        outer.stream,
        (key) => inners[key]!.stream,
      ).listen(events.add);

      outer.add('a');
      await pumpEventQueue();
      innerA
        ..add(1)
        ..add(2);
      await pumpEventQueue();
      check(events).deepEquals([1, 2]);

      outer.add('b');
      await pumpEventQueue();
      // Stale: A was switched away; its events must not pass through.
      innerA.add(99);
      innerB.add(10);
      await pumpEventQueue();
      check(events).deepEquals([1, 2, 10]);

      await subscription.cancel();
      await outer.close();
      await innerA.close();
      await innerB.close();
    });

    test(
      'cancels the previous inner subscription on every outer event',
      () async {
        final outer = StreamController<String>();
        var firstCancelled = false;
        var secondCancelled = false;
        final innerA = StreamController<int>(
          onCancel: () => firstCancelled = true,
        );
        final innerB = StreamController<int>(
          onCancel: () => secondCancelled = true,
        );
        final inners = {'a': innerA, 'b': innerB};

        final subscription = switchLatest(
          outer.stream,
          (key) => inners[key]!.stream,
        ).listen((_) {});

        outer.add('a');
        await pumpEventQueue();
        check(firstCancelled).isFalse();

        outer.add('b');
        await pumpEventQueue();
        check(firstCancelled).isTrue();
        check(secondCancelled).isFalse();

        await subscription.cancel();
        await outer.close();
      },
    );

    test(
      'forwards inner stream errors without tearing the stream down',
      () async {
        final outer = StreamController<String>();
        final inner = StreamController<int>();

        final events = <int>[];
        final errors = <Object>[];
        final subscription = switchLatest(
          outer.stream,
          (_) => inner.stream,
        ).listen(events.add, onError: errors.add);

        outer.add('go');
        await pumpEventQueue();
        inner
          ..add(1)
          ..addError(StateError('inner boom'))
          ..add(2);
        await pumpEventQueue();

        check(events).deepEquals([1, 2]);
        check(errors.length).equals(1);
        check(errors.single).isA<StateError>();

        await subscription.cancel();
        await outer.close();
        await inner.close();
      },
    );

    test('forwards outer stream errors', () async {
      final outer = StreamController<String>();

      final errors = <Object>[];
      final subscription = switchLatest(
        outer.stream,
        (_) => const Stream<int>.empty(),
      ).listen((_) {}, onError: errors.add);

      outer.addError(ArgumentError('outer boom'));
      await pumpEventQueue();

      check(errors.length).equals(1);
      check(errors.single).isA<ArgumentError>();

      await subscription.cancel();
      await outer.close();
    });

    test('cancelling the result cancels both the outer and the current inner '
        'subscription', () async {
      var outerCancelled = false;
      var innerCancelled = false;
      final outer = StreamController<String>(
        onCancel: () => outerCancelled = true,
      );
      final inner = StreamController<int>(
        onCancel: () => innerCancelled = true,
      );

      final subscription = switchLatest(
        outer.stream,
        (_) => inner.stream,
      ).listen((_) {});
      outer.add('go');
      await pumpEventQueue();

      await subscription.cancel();
      check(outerCancelled).isTrue();
      check(innerCancelled).isTrue();

      await outer.close();
      await inner.close();
    });

    test(
      'closes only once the outer is done AND the last inner is done',
      () async {
        final outer = StreamController<String>();
        final inner = StreamController<int>();

        var done = false;
        final events = <int>[];
        switchLatest(
          outer.stream,
          (_) => inner.stream,
        ).listen(events.add, onDone: () => done = true);

        outer.add('go');
        await pumpEventQueue();
        await outer.close();
        await pumpEventQueue();
        // The inner stream is still live — the result must stay open.
        check(done).isFalse();
        inner.add(7);
        await pumpEventQueue();
        check(events).deepEquals([7]);

        await inner.close();
        await pumpEventQueue();
        check(done).isTrue();
      },
    );
  });
}
