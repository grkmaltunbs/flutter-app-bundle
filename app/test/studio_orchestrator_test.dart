// The orchestrator inside the Studio: the review loop the app runs in place
// of the session's cron job, the autopilot command lines, the step prompt —
// all on a fake `claude` (no quota spent).
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/studio/studio_data.dart';
import 'package:kit_app/src/studio/studio_orchestrator.dart';
import 'package:kit_app/src/studio/studio_plans.dart';
import 'package:kit_app/src/theme.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_claude.dart';

void main() {
  late Directory home;
  late Directory project;
  late Directory auto;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    home = Directory.systemTemp.createTempSync('studio_orch_home_');
    project = Directory.systemTemp.createTempSync('studio_orch_project_');
    auto = Directory.systemTemp.createTempSync('studio_orch_auto_');
  });
  tearDown(() {
    for (final d in [home, project, auto]) {
      d.deleteSync(recursive: true);
    }
  });

  void w(String rel, String text) => (File(p.join(auto.path, rel))..createSync(recursive: true)).writeAsStringSync(text);

  group('ReviewLoop', () {
    test('sends /autopilot-review only when on, the mode is on, the pass is due and the session is between turns', () async {
      final fake = FakeClaude();
      final b = fakeSession(fake, dir: project.path, home: home.path);
      var clock = DateTime(2026, 11, 7, 10, 0);
      final loop = ReviewLoop(bridge: b, autopilotDir: auto.path, now: () => clock);
      addTearDown(loop.dispose);

      expect(loop.tick(), isFalse, reason: 'off');
      loop.set(true, persist: false);

      w('review/mode', 'off\n');
      expect(loop.tick(), isFalse);
      expect(loop.why, contains('review/mode is off'));

      w('review/mode', 'afk\n');
      w('review/last-review', '2026-11-07 09:50:00\n');
      expect(loop.tick(), isFalse);
      expect(loop.why, 'next pass at 10:10');

      clock = DateTime(2026, 11, 7, 10, 11);
      expect(loop.tick(), isFalse);
      expect(loop.why, contains('not running'), reason: 'it never starts a session on its own');

      await b.start();
      await pumpEventQueue();
      expect(b.state, BridgeState.ready);
      expect(loop.tick(), isTrue);
      await fake.writtenLines(1);
      expect(fake.written.single, contains('/autopilot-review'));
      expect(loop.lastSent, clock);

      // Not again until the period has run from the send.
      clock = DateTime(2026, 11, 7, 10, 20);
      expect(loop.tick(), isFalse);
      expect(loop.why, 'next pass at 10:31');
      await b.stop();
    });

    test('remembers it was on', () async {
      SharedPreferences.setMockInitialValues({'studio.reviewLoop': true});
      final loop = ReviewLoop(bridge: fakeSession(FakeClaude(), dir: project.path, home: home.path), autopilotDir: auto.path);
      addTearDown(loop.dispose);
      await loop.restore();
      expect(loop.on, isTrue);
    });
  });

  test('the brief tells the session the app runs the loop and how step orders arrive', () {
    final brief = orchestratorBrief(autopilotDir: '/x/sivas-autopilot');
    expect(brief, contains('/x/sivas-autopilot'));
    expect(brief, contains('do not create a cron job'));
    expect(brief, contains('[Studio · lane <x> · <step id>]'));
    expect(brief, contains('after: <lane>/<STEP-ID>'));
  });

  test('a step prompt names the lane and the step, and carries the item', () {
    final item = parseStepList('## Room Lab\n- [ ] ROOMLAB-1C: Play in that room\n  - solo host\n').single;
    final text = stepPrompt(lane: 'a', item: item, text: 'Why is this next?');
    expect(text, startsWith('[Studio · lane A · ROOMLAB-1C] Why is this next?'));
    expect(text, contains('(under "Room Lab")'));
    expect(text, contains('[ ] ROOMLAB-1C: Play in that room\n  - solo host'));
  });

  group('command lines', () {
    final lanes = [
      Lane(id: 'a', status: LaneStatus.parse(''), history: const []),
      Lane(id: 'c', status: LaneStatus.parse(''), history: const []),
    ];
    Future<String?> pick(WidgetTester tester, AutopilotCommand c, Future<void> Function() fill) async {
      String? got;
      await tester.pumpWidget(MaterialApp(
        theme: kitTheme(KitTokens.light),
        home: Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () async => got = await askCommandText(context, c, lanes), child: const Text('GO'))))),
      ));
      await tester.tap(find.text('GO'));
      await tester.pumpAndSettle();
      await fill();
      return got;
    }

    testWidgets('a plain command needs nothing', (tester) async {
      expect(await pick(tester, kAutopilotCommands.firstWhere((c) => c.label == 'STATUS'), () async {}), '/autopilot-status');
    });

    testWidgets('TELL asks for a lane and a note', (tester) async {
      final c = kAutopilotCommands.firstWhere((c) => c.label == 'TELL A LANE');
      final got = await pick(tester, c, () async {
        expect(find.text('ALL LANES'), findsNothing, reason: 'tell needs one lane');
        await tester.tap(find.text('LANE C'));
        await tester.enterText(find.byType(TextField), 'stop before the 19:00 play session');
        await tester.pump();
        expect(find.text('/autopilot-tell c stop before the 19:00 play session'), findsOneWidget);
        await tester.tap(find.text('SEND'));
        await tester.pumpAndSettle();
      });
      expect(got, '/autopilot-tell c stop before the 19:00 play session');
    });

    testWidgets('CONTINUE offers all lanes; MESHY takes a number', (tester) async {
      final cont = kAutopilotCommands.firstWhere((c) => c.label == 'CONTINUE');
      expect(await pick(tester, cont, () async {
        await tester.tap(find.text('SEND'));
        await tester.pumpAndSettle();
      }), '/autopilot-continue');
      final meshy = kAutopilotCommands.firstWhere((c) => c.label == 'APPROVE MESHY');
      expect(await pick(tester, meshy, () async {
        await tester.enterText(find.byType(TextField), '150');
        await tester.pump();
        await tester.tap(find.text('SEND'));
        await tester.pumpAndSettle();
      }), '/autopilot-approve-meshy 150');
    });
  });
}
