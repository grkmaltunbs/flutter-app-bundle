// The Studio on the phone: the Mac publishes the raw files, the phone parses
// them with the same code — so the same lanes, steps, roadmap, mail and
// docs come out — and a change on the Mac reaches the phone.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/studio/studio_data.dart';
import 'package:kit_app/src/studio/studio_relay.dart';
import 'package:kit_app/src/studio/studio_screen.dart';
import 'package:kit_app/src/studio/studio_source.dart';
import 'package:kit_app/src/theme.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory auto, game;
  setUp(() {
    auto = Directory.systemTemp.createTempSync('relay_auto_');
    game = Directory.systemTemp.createTempSync('relay_game_');
    void w(Directory d, String rel, String text) => (File(p.join(d.path, rel))..createSync(recursive: true)).writeAsStringSync(text);
    w(auto, 'run-lane.sh', '  c) REPO="\$CTL"; WHOST=sivas-win; WCTL=x ;;\n');
    w(auto, 'lane-a/status', '2026-11-06 22:17:50  running step 1100 (claude claude-opus-5-5/high)  (tail -f /x)\n');
    w(auto, 'lane-a/history.log', '2026-11-06 22:17:50  step 1099  DONE ROOMLAB-1B: the window\n2026-11-06 22:17:50  step 1100 started (claude claude-opus-5-5/high)\n');
    w(auto, 'lane-a/engine', 'claude');
    w(auto, 'lane-a/model', 'claude-opus-5-5');
    w(auto, 'prompts/lane-a.md', 'list: `production/autopilot/lane-a-steps.md`');
    w(game, 'production/autopilot/lane-a-steps.md', '- [x] ROOMLAB-1B (run 1099): the window\n- [ ] ROOMLAB-1C: Play in that room\n- [ ] ROOMLAB-1D: tests\n');
    w(auto, 'lane-c/status', '2026-11-05 02:47:52  waiting: new mail in /x/mail/to-c (nothing to test)\n');
    w(auto, 'lane-c/steps.md', '- [x] step 476: copied the log lines\n');
    w(auto, 'mail/to-user/20261106-2230-roomlab-1b-ready.md', '# Lane A run 1099: Room Lab 1B is in\n\nTry it.');
    w(auto, 'review/digest.md', '## 2026-11-06 20:00 — old\nx\n## 2026-11-06 22:37 — user away\n\n**Waiting for the user**\n- Try Room Lab 1B.\n');
    w(auto, 'review/afk-decisions.md', '## 2026-11-06 22:40 — acked the landing line\n- Decided.\n');
    w(auto, 'review/open-issues.md', '- A ROOM-LAB: phases ordered\n- B old · closed 2026-11-01 10:00\n');
    w(auto, 'review/mode', 'afk');
    w(auto, 'review/last-review', '2026-11-06 22:40:01');
    w(game, 'production/production-plan.md', '## Milestone ladder\n\n| # | Milestone | Goal | Exit | Status |\n|---|---|---|---|---|\n| M3 | **Alpha** (v0.4) | Run engine complete | x | In progress |\n\n## Open work\n\n### M3 — Alpha\n\n| ID | Task | Size | Owner | Status | Summary |\n|---|---|---|---|---|---|\n| M3.17 | Loading | L | Dev | In progress — stage 0 | left |\n');
    w(game, 'CLAUDE.md', '# Rules\nbe kind');
    w(game, 'design/gdd/00-game-overview.md', '# Overview\nrobots');
  });
  tearDown(() {
    auto.deleteSync(recursive: true);
    game.deleteSync(recursive: true);
  });

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await pumpEventQueue();
    }
  }

  test('what the phone parses is what the Mac read', () async {
    final db = FakeFirebaseFirestore();
    final mac = StudioSource(autopilotDir: auto.path, gameDir: game.path);
    await mac.refresh();
    final pub = StudioPublisher(db: db, source: mac, machine: 'Gorkems-Mac-Mini');
    await pub.publish();
    expect(pub.error, isNull);
    final phone = RemoteStudioData(db)..start();
    await settle();
    final a = mac.snapshot, b = phone.snapshot;
    expect(b.lanes.map((l) => l.id), a.lanes.map((l) => l.id));
    expect(b.lanes.first.status.text, 'running step 1100');
    expect(b.lanes.first.lastDone!.step, '1099');
    expect(b.lanes.first.engineLine, a.lanes.first.engineLine);
    expect(b.lanes.last.machine, 'Windows PC');
    expect(b.tracks['a']!.current!.id, 'ROOMLAB-1C', reason: 'the same track logic, from the published list');
    expect(b.tracks['c']!.done.single.id, '476');
    expect(b.roadmap.single.items.single.id, 'M3.17');
    expect(b.userMail.single.title, 'Lane A run 1099: Room Lab 1B is in');
    expect(b.waitingForUser, ['Try Room Lab 1B.']);
    expect(b.decisions.single.title, 'acked the landing line');
    expect(b.openIssues.map((i) => i.text), ['A ROOM-LAB: phases ordered']);
    expect(b.mode, 'afk');
    expect(b.lastReview, DateTime(2026, 11, 6, 22, 40, 1));
    expect(phone.machine, 'Gorkems-Mac-Mini');
    expect(phone.gameDir, isNotNull);
    expect(phone.gameFile('CLAUDE.md'), '# Rules\nbe kind');
    expect(phone.gddFiles(), ['design/gdd/00-game-overview.md']);

    // A lane moves on the Mac: the phone hears it.
    File(p.join(auto.path, 'lane-a/status')).writeAsStringSync('2026-11-07 09:00:00  paused, waiting for the user (/autopilot-continue)\n');
    await mac.refresh();
    await pub.publish();
    await settle();
    expect(phone.snapshot.lanes.first.status.state, LaneState.paused);
    phone.dispose();
  });

  test('nothing changed, nothing written again', () async {
    final db = FakeFirebaseFirestore();
    final mac = StudioSource(autopilotDir: auto.path, gameDir: game.path);
    await mac.refresh();
    final pub = StudioPublisher(db: db, source: mac, machine: 'm');
    await pub.publish();
    final first = (await db.collection('studio').doc('main').collection('files').doc('plan').get()).data()!['hash'];
    await db.collection('studio').doc('main').collection('files').doc('plan').update({'text': 'tampered'});
    await pub.publish();
    final again = await db.collection('studio').doc('main').collection('files').doc('plan').get();
    expect(again.data()!['text'], 'tampered', reason: 'the plan did not change on the Mac, so it was not written again');
    expect(again.data()!['hash'], first);
    // A second publisher (an app relaunch) starts from the hashes on the main document.
    final relaunched = StudioPublisher(db: db, source: mac, machine: 'm');
    await relaunched.publish();
    expect((await db.collection('studio').doc('main').collection('files').doc('plan').get()).data()!['text'], 'tampered');
  });

  testWidgets('the phone Studio: lanes on NOW, the orchestrator coming next, no editing', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final mac = StudioSource(autopilotDir: auto.path, gameDir: game.path);
    await tester.runAsync(mac.refresh);
    await tester.runAsync(() => StudioPublisher(db: db, source: mac, machine: 'm').publish());
    final phone = RemoteStudioData(db)..start();
    await tester.runAsync(settle);
    await tester.pumpWidget(MaterialApp(theme: kitTheme(KitTokens.light), home: StudioScreen(source: phone, remote: true, mediaTab: const Text('PHONE MEDIA'))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('WAITING FOR YOU · 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('running step 1100'), 300, scrollable: find.descendant(of: find.byKey(const Key('studio-now')), matching: find.byType(Scrollable)).first);
    expect(find.text('LANE A'), findsOneWidget);
    DefaultTabController.of(tester.element(find.byType(TabBarView))).animateTo(1);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.textContaining('come to the phone in the next update'), findsOneWidget);
    DefaultTabController.of(tester.element(find.byType(TabBarView))).animateTo(5);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('PHONE MEDIA'), findsOneWidget);
    expect(find.text('SEND TO ORCHESTRATOR'), findsNothing);
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue, reason: 'a phone scrolls the tabs so every name reads whole');
    expect(tester.takeException(), isNull);
    phone.dispose();
  });
}
