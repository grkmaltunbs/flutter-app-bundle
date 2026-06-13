import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';

void main() {
  late FakeConnectivityService service;

  setUp(() => service = FakeConnectivityService());
  tearDown(() => service.dispose());

  group('FakeConnectivityService', () {
    test('starts online', () async {
      check(await service.isOnline()).isTrue();
    });

    test('a new listener immediately receives the current value', () async {
      final events = <bool>[];
      final subscription = service.onlineStream.listen(events.add);
      await pumpEventQueue();

      check(events).deepEquals([true]);
      await subscription.cancel();
    });

    test('setOnline(false) emits the change and flips isOnline', () async {
      final events = <bool>[];
      final subscription = service.onlineStream.listen(events.add);
      await pumpEventQueue();

      service.setOnline(online: false);
      await pumpEventQueue();

      check(events).deepEquals([true, false]);
      check(await service.isOnline()).isFalse();
      await subscription.cancel();
    });

    test('a listener attached while offline replays false first', () async {
      service.setOnline(online: false);

      final events = <bool>[];
      final subscription = service.onlineStream.listen(events.add);
      await pumpEventQueue();

      check(events).deepEquals([false]);
      await subscription.cancel();
    });

    test('setOnline with the unchanged value does not re-emit', () async {
      final events = <bool>[];
      final subscription = service.onlineStream.listen(events.add);
      await pumpEventQueue();

      service
        ..setOnline(online: true) // no-op: already online
        ..setOnline(online: false)
        ..setOnline(online: false); // no-op: already offline
      await pumpEventQueue();

      check(events).deepEquals([true, false]);
      await subscription.cancel();
    });

    test('setOnlineSilently flips isOnline without emitting (the missed '
        'transport change behind the resume-refresh path)', () async {
      final events = <bool>[];
      final subscription = service.onlineStream.listen(events.add);
      await pumpEventQueue();

      service.setOnlineSilently(online: false);
      await pumpEventQueue();

      check(events).deepEquals([true]); // only the replay — no change event
      check(await service.isOnline()).isFalse();
      // A fresh listener replays the silent state.
      final lateEvents = <bool>[];
      final lateSubscription = service.onlineStream.listen(lateEvents.add);
      await pumpEventQueue();
      check(lateEvents).deepEquals([false]);
      await subscription.cancel();
      await lateSubscription.cancel();
    });

    test('reset restores the online state and emits it', () async {
      service.setOnline(online: false);
      final events = <bool>[];
      final subscription = service.onlineStream.listen(events.add);
      await pumpEventQueue();

      service.reset();
      await pumpEventQueue();

      check(events).deepEquals([false, true]);
      check(await service.isOnline()).isTrue();
      await subscription.cancel();
    });

    test('reset while already online is a no-op emission-wise', () async {
      final events = <bool>[];
      final subscription = service.onlineStream.listen(events.add);
      await pumpEventQueue();

      service.reset();
      await pumpEventQueue();

      check(events).deepEquals([true]);
      await subscription.cancel();
    });
  });
}
