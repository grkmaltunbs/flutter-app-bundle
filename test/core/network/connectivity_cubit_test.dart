import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/core/network/connectivity_cubit.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';

class _MockAppLogger extends Mock implements AppLogger {}

/// Hand-rolled [ConnectivityService] stub: a directly-driven change stream
/// plus a scriptable one-shot probe (result or thrown [Exception]).
class _StubConnectivityService implements ConnectivityService {
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  /// The next [isOnline] answer.
  bool online = true;

  /// When set, [isOnline] throws this instead of answering.
  Exception? probeError;

  /// How many times [isOnline] was called.
  int probes = 0;

  @override
  Stream<bool> get onlineStream => controller.stream;

  @override
  Future<bool> isOnline() async {
    probes++;
    final error = probeError;
    if (error != null) throw error;
    return online;
  }

  Future<void> dispose() => controller.close();
}

void main() {
  late _StubConnectivityService service;
  late _MockAppLogger logger;

  setUp(() {
    service = _StubConnectivityService();
    logger = _MockAppLogger();
  });
  tearDown(() => service.dispose());

  group('ConnectivityCubit', () {
    test('starts optimistically online before the first probe lands', () {
      final cubit = ConnectivityCubit(service, logger);
      addTearDown(cubit.close);

      check(cubit.state).isTrue();
      check(service.probes).equals(1); // the constructor probe is in flight
    });

    blocTest<ConnectivityCubit, bool>(
      'the constructor probe lands the real offline answer without waiting '
      'for a transport change',
      setUp: () => service.online = false,
      build: () => ConnectivityCubit(service, logger),
      wait: Duration.zero,
      expect: () => [false],
    );

    blocTest<ConnectivityCubit, bool>(
      'transport stream flips emit in order (the leading true is the '
      'constructor probe confirming the optimistic default — a first '
      'emission is never deduplicated)',
      build: () => ConnectivityCubit(service, logger),
      act: (cubit) async {
        await pumpEventQueue();
        service.controller.add(false);
        await pumpEventQueue();
        service.controller.add(true);
      },
      expect: () => [true, false, true],
    );

    blocTest<ConnectivityCubit, bool>(
      'repeated identical stream values deduplicate',
      build: () => ConnectivityCubit(service, logger),
      act: (cubit) async {
        await pumpEventQueue();
        service.controller
          ..add(false)
          ..add(false);
      },
      expect: () => [true, false],
    );

    blocTest<ConnectivityCubit, bool>(
      'a failing probe retains the last state, logs, and never throws',
      setUp: () => service.probeError = TimeoutException('probe down'),
      build: () => ConnectivityCubit(service, logger),
      wait: Duration.zero,
      expect: () => <bool>[],
      verify: (cubit) {
        check(cubit.state).isTrue();
        verify(() => logger.error(any(), any(), any())).called(1);
      },
    );

    test('refresh after a failed probe recovers to the real answer', () async {
      service.probeError = TimeoutException('probe down');
      final cubit = ConnectivityCubit(service, logger);
      addTearDown(cubit.close);
      await pumpEventQueue();
      check(cubit.state).isTrue(); // failed probe retained the default

      service
        ..probeError = null
        ..online = false;
      await cubit.refresh();

      check(cubit.state).isFalse();
    });

    test('refresh probes a change the stream never delivered (the resume '
        'path)', () async {
      final cubit = ConnectivityCubit(service, logger);
      addTearDown(cubit.close);
      await pumpEventQueue();
      check(cubit.state).isTrue();

      service.online = false; // dropped while backgrounded: no stream event
      await cubit.refresh();

      check(cubit.state).isFalse();
    });

    test('a stream error is logged and the subscription stays alive', () async {
      final cubit = ConnectivityCubit(service, logger);
      addTearDown(cubit.close);
      await pumpEventQueue();

      service.controller.addError(const FormatException('transport glitch'));
      await pumpEventQueue();

      verify(() => logger.error(any(), any(), any())).called(1);
      check(cubit.state).isTrue();

      // Later changes still land: the listener survived the error.
      service.controller.add(false);
      await pumpEventQueue();
      check(cubit.state).isFalse();
    });

    test('close cancels the subscription — nothing lands afterwards', () async {
      final cubit = ConnectivityCubit(service, logger);
      await pumpEventQueue();
      check(service.controller.hasListener).isTrue();

      await cubit.close();

      check(service.controller.hasListener).isFalse();
      service.controller.add(false); // delivered to nobody
      await pumpEventQueue();
      check(cubit.state).isTrue();
    });
  });
}
