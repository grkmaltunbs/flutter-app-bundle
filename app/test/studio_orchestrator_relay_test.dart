// The orchestrator on the phone: the Mac publishes its session like a
// project's (marked as the Studio's), carries out what the phone sends —
// a message, an answer to an ask, the review loop, a timed order — and the
// phone's view reads the loop and the schedule back.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_kit/kit.dart' show Ask, AskAnswer;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/relay.dart';
import 'package:kit_app/src/studio/studio_orchestrator.dart';
import 'package:kit_app/src/studio/studio_orchestrator_relay.dart';
import 'package:kit_app/src/studio/studio_schedule.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_claude.dart';

void main() {
  late Directory home, proj, auto, files;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    home = Directory.systemTemp.createTempSync('orelay_home_');
    proj = Directory.systemTemp.createTempSync('orelay_proj_');
    auto = Directory.systemTemp.createTempSync('orelay_auto_');
    files = Directory.systemTemp.createTempSync('orelay_files_');
  });
  tearDown(() {
    for (final d in [home, proj, auto, files]) {
      d.deleteSync(recursive: true);
    }
  });

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await pumpEventQueue();
    }
  }

  test('published like a project, driven from the phone: send, answer, loop, schedule', () async {
    final db = FakeFirebaseFirestore();
    final fake = FakeClaude();
    final b = fakeSession(fake, dir: proj.path, home: home.path);
    final loop = ReviewLoop(bridge: b, autopilotDir: auto.path);
    final schedule = StudioSchedule(file: p.join(files.path, 'schedule.json'));
    final relay = OrchestratorRelay(db: db, bridge: b, machine: 'Gorkems-Mac-Mini', dir: proj.path, loop: loop, schedule: schedule)..start();
    await settle();
    final doc = await db.collection('projects').doc(kOrchestratorSlug).get();
    expect(doc.data()!['studio'], isTrue, reason: 'the phone\'s project list leaves it out');
    expect((doc.data()!['session'] as Map)['mode'], 'idle');

    // The phone sends a message: the orchestrator is started for it, the message reaches it.
    final phone = CommandSender(db, kOrchestratorSlug);
    await phone.send({'type': 'send', 'text': '/autopilot-status'}, from: 'phone');
    await settle();
    await fake.writtenLines(1);
    expect(fake.written.single, contains('/autopilot-status'));
    final sent = await db.collection('projects').doc(kOrchestratorSlug).collection('commands').get();
    expect(sent.docs.single.data()['result'], 'sent');

    // An ask: published for the phone; the phone's answer reaches the CLI.
    fake.emitJson({'type': 'control_request', 'request_id': 'r1', 'request': {'subtype': 'can_use_tool', 'tool_name': 'Bash', 'input': {'command': 'touch control/PAUSE-c'}, 'tool_use_id': 't1'}});
    await settle();
    final ask = await db.collection('projects').doc(kOrchestratorSlug).collection('asks').doc('r1').get();
    expect(ask.exists, isTrue);
    await phone.answer(Ask.fromMap(ask.data()!), AskAnswer.allow(Ask.fromMap(ask.data()!)), from: 'phone');
    await settle();
    await fake.writtenLines(2);
    expect(fake.written.last, contains('"behavior":"allow"'));
    expect((await db.collection('projects').doc(kOrchestratorSlug).collection('asks').doc('r1').get()).data()!['answeredAt'], isNotNull);

    // The bar: the loop and a timed order, set from the phone.
    await phone.send({'type': 'studio', 'action': 'loop', 'on': true}, from: 'phone');
    await phone.send({'type': 'studio', 'action': 'schedule-add', 'order': TimedOrder(id: 'p1', at: DateTime(2030, 1, 1, 19), text: '/wait-at-the-next-stop c').toJson()}, from: 'phone');
    await settle();
    expect(loop.on, isTrue);
    expect(schedule.orders.single.text, '/wait-at-the-next-stop c');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await settle();

    // The phone's view reads them back.
    final view = RemoteOrchestrator(db)..start();
    await settle();
    expect(view.published, isTrue);
    expect(view.on, isTrue);
    expect(view.orders.single.text, '/wait-at-the-next-stop c');
    expect(view.upcoming, 1);
    view.dispose();
    relay.stop();
    loop.dispose();
    await b.stop();
  });

  test('a command the orchestrator does not take is said so', () async {
    final db = FakeFirebaseFirestore();
    final b = fakeSession(FakeClaude(), dir: proj.path, home: home.path);
    final relay = OrchestratorRelay(db: db, bridge: b, machine: 'm', dir: proj.path, schedule: StudioSchedule(file: p.join(files.path, 's.json')));
    expect(await relay.apply({'type': 'build', 'action': 'start'}), 'not on the orchestrator: build');
    expect(await relay.apply({'type': 'studio', 'action': 'loop', 'on': true}), 'no review loop here');
  });
}
