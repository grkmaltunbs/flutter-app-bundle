// Timed orders: when they are due (once, every day, weekdays), what a late
// one does (sent within the grace, missed past it), sending through the
// orchestrator — started when it is not running — timers the orchestrator
// writes as ```studio-timer blocks, and the schedule kept across a relaunch.
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/studio/studio_schedule.dart';
import 'package:kit_app/src/theme.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_claude.dart';

void main() {
  late Directory home, proj, dir;
  setUp(() {
    home = Directory.systemTemp.createTempSync('sched_home_');
    proj = Directory.systemTemp.createTempSync('sched_proj_');
    dir = Directory.systemTemp.createTempSync('sched_file_');
  });
  tearDown(() {
    for (final d in [home, proj, dir]) {
      d.deleteSync(recursive: true);
    }
  });

  test('due times: today or tomorrow, weekdays skip the weekend', () {
    final fri = DateTime(2026, 11, 6, 20, 0); // a Friday
    expect(firstAt(fri, 19, 0, Repeat.once), DateTime(2026, 11, 7, 19, 0), reason: '19:00 has passed today');
    expect(firstAt(fri, 21, 0, Repeat.daily), DateTime(2026, 11, 6, 21, 0));
    expect(firstAt(fri, 19, 0, Repeat.weekdays), DateTime(2026, 11, 9, 19, 0), reason: 'Saturday and Sunday are skipped');
    final o = TimedOrder(id: 'x', at: DateTime(2026, 11, 6, 19, 0), text: 't', repeat: Repeat.weekdays);
    expect(o.nextAfter(DateTime(2026, 11, 6, 19, 0, 30)), DateTime(2026, 11, 9, 19, 0));
  });

  test('a studio-timer block from the orchestrator', () {
    final o = parseTimer('at: 2026-11-07 18:45\nrepeat: daily\nsend: /wait-at-the-next-stop c\nnote: before the 19:00 play session\n', id: 's-1')!;
    expect(o.at, DateTime(2026, 11, 7, 18, 45));
    expect(o.repeat, Repeat.daily);
    expect(o.text, '/wait-at-the-next-stop c');
    expect(o.by, 'orchestrator');
    expect(o.note, 'before the 19:00 play session');
    expect(parseTimer('send: x', id: 'y'), isNull, reason: 'no time, no timer');
  });

  test('check: sends what is due through the orchestrator — starting it — reschedules repeats, marks the too-late missed', () async {
    var clock = DateTime(2026, 11, 7, 18, 0);
    final s = StudioSchedule(file: p.join(dir.path, 'schedule.json'), now: () => clock);
    final spawned = <FakeClaude>[];
    final b = fakeSessionEach(spawned, dir: proj.path, home: home.path);
    s.bridge = b;
    s
      ..add(TimedOrder(id: 'once', at: DateTime(2026, 11, 7, 18, 45), text: '/wait-at-the-next-stop c', note: 'play session'))
      ..add(TimedOrder(id: 'daily', at: DateTime(2026, 11, 7, 18, 45), text: '/autopilot-status', repeat: Repeat.daily))
      ..add(TimedOrder(id: 'old', at: DateTime(2026, 11, 7, 17, 0), text: '/autopilot-continue c'));
    // 18:00 — the 17:00 one is an hour late: missed, not sent.
    expect(await s.check(), isEmpty);
    expect(s.orders.firstWhere((o) => o.id == 'old').status, 'missed');
    expect(b.running, isFalse, reason: 'nothing due, nothing started');
    // 18:46 — two are due; the orchestrator is started for them.
    clock = DateTime(2026, 11, 7, 18, 46);
    final sent = await s.check();
    expect(sent.map((o) => o.id), ['once', 'daily']);
    expect(b.running, isTrue);
    await spawned.single.writtenLines(1);
    expect(spawned.single.written.join('\n'), contains('/wait-at-the-next-stop c'));
    // The second waits its turn: one message per turn, queued behind the first.
    final users = [for (final m in b.transcript.messages) if (m.by == 'schedule') m];
    expect(users.map((m) => m.text), ['/wait-at-the-next-stop c', '/autopilot-status']);
    expect(users.last.queued, isTrue);
    expect(s.orders.firstWhere((o) => o.id == 'once').status, 'sent');
    expect(s.orders.firstWhere((o) => o.id == 'daily').at, DateTime(2026, 11, 8, 18, 45));
    expect(b.transcript.messages.where((m) => m.text.startsWith('⏰ Timed order')).length, 2, reason: 'a note per send');
    expect(s.upcoming, 1);
    // Kept across a relaunch.
    final again = StudioSchedule(file: p.join(dir.path, 'schedule.json'))..load();
    expect(again.orders.map((o) => '${o.id}:${o.status}').toSet(), {'once:sent', 'daily:scheduled', 'old:missed'});
    await b.stop();
  });

  test('a timer the orchestrator writes in a reply lands in the schedule once', () async {
    final fake = FakeClaude();
    final b = fakeSession(fake, dir: proj.path, home: home.path);
    final s = StudioSchedule(file: p.join(dir.path, 'schedule.json'))..watch(b);
    await b.start();
    await pumpEventQueue();
    b.send('pause lane C before 19:00 and resume it at 03:00');
    await fake.writtenLines(1);
    fake.emitJson({'type': 'assistant', 'message': {'id': 'm1', 'role': 'assistant', 'content': [{'type': 'text', 'text': 'Set.\n\n```studio-timer\nat: 2026-11-07 18:45\nrepeat: once\nsend: /wait-at-the-next-stop c\nnote: before play\n```\n\n```studio-timer\nat: 2026-11-08 03:00\nsend: /autopilot-continue c\n```'}]}, 'session_id': b.sessionId});
    fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 5, 'num_turns': 1, 'result': 'Set.', 'session_id': b.sessionId});
    await pumpEventQueue();
    expect(s.orders.map((o) => o.text), ['/wait-at-the-next-stop c', '/autopilot-continue c']);
    s.collectTimers(b);
    expect(s.orders, hasLength(2), reason: 'the same block is not added twice');
    await b.stop();
  });

  testWidgets('the sheet: upcoming with CANCEL, finished below', (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = StudioSchedule(file: p.join(dir.path, 'schedule.json'))
      ..add(TimedOrder(id: 'a', at: DateTime.now().add(const Duration(hours: 2)), text: '/autopilot-status', repeat: Repeat.daily))
      ..add(TimedOrder(id: 'b', at: DateTime.now().subtract(const Duration(hours: 2)), text: '/autopilot-continue c', status: 'missed', by: 'orchestrator'));
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => showScheduleSheet(context, s, lanes: const [], pickText: (_) async => null), child: const Text('OPEN'))))),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.text('TIMED ORDERS · 1 UPCOMING'), findsOneWidget);
    expect(find.text('/autopilot-status'), findsOneWidget);
    expect(find.textContaining('every day · set by you'), findsOneWidget);
    expect(find.textContaining('set by orchestrator'), findsOneWidget, reason: 'the missed one, below');
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('TIMED ORDERS · 0 UPCOMING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
