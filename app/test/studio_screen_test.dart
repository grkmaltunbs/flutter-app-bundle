// The Studio on a folder shaped like the real autopilot: NOW leads with what
// waits on the person, then a card per lane; LANES, INBOX and DOCS open what
// they list — at phone width and every text scale, no overflow.
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/studio/studio_screen.dart';
import 'package:kit_app/src/studio/studio_source.dart';
import 'package:kit_app/src/theme.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_claude.dart';

/// The working lane's glyph never stops moving, so pumpAndSettle would wait forever.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Switches tab through the controller: at large text the tab bar scrolls
/// and a tab can sit off-screen.
Future<void> goTab(WidgetTester tester, int index) async {
  DefaultTabController.of(tester.element(find.byType(TabBarView))).animateTo(index);
  await settle(tester);
}

void main() {
  late Directory auto;
  late Directory game;
  final now = DateTime(2026, 11, 6, 23, 0);

  setUp(() {
    auto = Directory.systemTemp.createTempSync('studio_auto_');
    game = Directory.systemTemp.createTempSync('studio_game_');
    void w(Directory root, String rel, String text) => (File(p.join(root.path, rel))..createSync(recursive: true)).writeAsStringSync(text);
    w(auto, 'run-lane.sh', '  c) REPO="\$CTL"; WHOST=sivas-win; WCTL=C:/dev/autopilot ;;\n  d) REPO="\$CTL"; WHOST=mac-mini; WCTL=/x\n');
    w(auto, 'lane-a/status', '2026-11-06 22:17:50  running step 1100 (claude claude-opus-5-5/high)  (tail -f /x)\n');
    w(auto, 'lane-a/history.log', '2026-11-06 21:30:08  step 1098  DONE ROOMLAB-1A: dev-only force hooks for one feature in one room\n2026-11-06 22:17:50  step 1099  DONE ROOMLAB-1B: Sivas/Room Lab window builds one room with a forced feature in 2.6-5.4 s\n2026-11-06 22:17:50  step 1100 started (claude claude-opus-5-5/high)\n');
    w(auto, 'prompts/lane-a.md', 'Your list: `production/autopilot/lane-a-steps.md`.');
    w(game, 'production/autopilot/lane-a-steps.md', '## Room Lab\n- [x] ROOMLAB-1A (run 1098): force hooks\n- [x] ROOMLAB-1B (run 1099): the window\n- [ ] ROOMLAB-1C: Play in that room\n- [ ] ROOMLAB-1D: feature tests onto the Lab\n');
    w(auto, 'lane-a/engine', 'claude');
    w(auto, 'lane-a/model', 'claude-opus-5-5');
    w(auto, 'lane-a/effort', 'high');
    w(auto, 'lane-a/logs/step-1099.log', 'the readable log of step 1099\n');
    w(auto, 'lane-c/status', '2026-11-05 02:47:52  waiting: new mail in /x/mail/to-c (nothing to test until lane A sends a package)\n');
    w(auto, 'lane-c/history.log', '2026-11-05 02:47:52  step 477  WAIT-FOR-MAIL no unchecked steps and the inbox is empty\n');
    w(auto, 'lane-d/status', '2026-11-05 22:44:23  not started: scaffolding only; waiting for the user\'s first order (no steps yet)\n');
    w(auto, 'mail/to-user/20261106-2230-roomlab-1b-ready.md', '# Lane A run 1099: Room Lab 1B is in\n\nTry **Sivas → Room Lab**.\n');
    w(auto, 'review/digest.md', '## 2026-11-06 22:37 — user away\n\n**Waiting for the user**\n- Room Lab 1B can already be tried (lane A\'s `20261106-2230-roomlab-1b-ready.md`).\n- YARD-LINE-ORDER (I recommend yes).\n\n### 22:40 review\n- **Lane A:** Room Lab 1A and 1B are in.\n');
    w(auto, 'review/afk-decisions.md', '## 2026-11-06 22:40 — acked lane A\'s Room Lab landing line\n- **Decided:** ack it.\n');
    w(auto, 'review/open-issues.md', '- A ROOM-LAB (the user 11-06): phases 1-3 ordered\n');
    w(auto, 'review/mode', 'afk');
    w(auto, 'review/last-review', '2026-11-06 22:40:01');
    w(game, 'production/production-plan.md', '# Plan\nintro\n## Who is on what\nFırat and Görkem.\n## Waiting on a person\nverdicts\n'
        '## Milestone ladder\n\n| # | Milestone | Goal | Exit | Status |\n|---|---|---|---|---|\n| M2 | **Pre-alpha** (v0.3) | One full run | x | Closed |\n| M3 | **Alpha** (v0.4) | Run engine complete | x | In progress |\n\n'
        '## Open work\n\n### M3 — Alpha (2 open of 3)\n\n| ID | Task | Size | Owner | Status | Summary |\n|---|---|---|---|---|---|\n| M3.17 | Loading and frame-time | L | Dev | In progress — stage 0 | left |\n| M3.2 | Refinery and Habitat themes | L | Dev | Not started | y |\n\n'
        '## Done\n\n### M2 — Pre-alpha (1 of 1)\n\n| ID | Task | Size | Owner | Done | Summary |\n|---|---|---|---|---|---|\n| M2.1 | One run | M | Dev | 2026-10-01 | s |\n\n### M3 — Alpha (1 of 3)\n\n| ID | Task | Size | Owner | Done | Summary |\n|---|---|---|---|---|---|\n| M3.6 | Mods & rarity | M | Dev | 2026-10-15 | m |\n');
    w(game, 'production/timetable-2027.md', '# Timetable\n');
    w(game, 'CLAUDE.md', '# Rules\n');
    w(game, 'design/gdd/00-game-overview.md', '# Overview\n');
  });
  tearDown(() {
    auto.deleteSync(recursive: true);
    game.deleteSync(recursive: true);
  });

  Future<StudioSource> pumpStudio(WidgetTester tester, double scale, {Size size = const Size(360, 780), Widget Function(StudioSource)? build}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = StudioSource(autopilotDir: auto.path, gameDir: game.path, now: () => now);
    await tester.runAsync(source.refresh);
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)), child: build?.call(source) ?? StudioScreen(source: source, now: () => now)),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    return source;
  }

  for (final scale in [1.0, 2.0, 3.12]) {
    testWidgets('at ${scale}x: NOW leads with what waits on you, then the lanes — no overflow', (tester) async {
      await pumpStudio(tester, scale);
      expect(find.text('WAITING FOR YOU · 2'), findsOneWidget);
      expect(find.textContaining('YARD-LINE-ORDER', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('running step 1100'), 300, scrollable: find.descendant(of: find.byKey(const Key('studio-now')), matching: find.byType(Scrollable)).first);
      expect(find.text('LANE A'), findsOneWidget);
      expect(find.text('WORKING'), findsOneWidget);
      expect(find.text('running step 1100'), findsOneWidget);
      expect(find.text('MACBOOK · CLAUDE · OPUS-5-5 · HIGH'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('LANE D'), 300, scrollable: find.descendant(of: find.byKey(const Key('studio-now')), matching: find.byType(Scrollable)).first);
      expect(find.text('NOT STARTED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a lane card opens the lane; a step opens its log', (tester) async {
    await pumpStudio(tester, 1.0, size: const Size(900, 1000));
    await tester.tap(find.text('LANE A'));
    await settle(tester);
    expect(find.text('FINISHED'), findsOneWidget);
    await tester.tap(find.textContaining('STEP 1099 · DONE'));
    await settle(tester);
    expect(find.text('LANE A · STEP 1099'), findsOneWidget);
    expect(find.text('the readable log of step 1099\n'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lane card draws its track; the step on NOW opens', (tester) async {
    await pumpStudio(tester, 1.0, size: const Size(900, 1400));
    expect(find.text('ROOMLAB-1C'), findsOneWidget);
    expect(find.text('NOW'), findsWidgets);
    expect(find.text('2 of 4 ticked · on ROOMLAB-1C'), findsOneWidget);
    await tester.tap(find.text('ROOMLAB-1C'));
    await settle(tester);
    expect(find.text('LANE A · ROOMLAB-1C'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 3.12]) {
    testWidgets('at ${scale}x: ROADMAP is the ladder, the open milestone marked; an item opens', (tester) async {
      await pumpStudio(tester, scale);
      await goTab(tester, 3);
      expect(find.byKey(const Key('road-sky')), findsOneWidget, reason: 'ROADMAP opens on the constellation');
      await tester.tap(find.byTooltip('Ladder'));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('M3.17'), 200, scrollable: find.descendant(of: find.byKey(const Key('studio-roadmap')), matching: find.byType(Scrollable)).first);
      expect(find.text('WE ARE HERE'), findsOneWidget);
      expect(find.text('1 of 3 done · 1 in progress'), findsOneWidget);
      expect(find.text('M3.17'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('M3.17'));
      await settle(tester);
      await tester.tap(find.text('M3.17'));
      await settle(tester);
      expect(find.text('Loading and frame-time'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 3.12]) {
    testWidgets('at ${scale}x: ORCHESTRATOR is the autopilot bar over the Deck — no overflow', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final home = Directory.systemTemp.createTempSync('studio_deck_home_');
      addTearDown(() => home.deleteSync(recursive: true));
      final bridge = fakeSession(FakeClaude(), dir: game.path, home: home.path);
      await pumpStudio(tester, scale, build: (src) => StudioScreen(source: src, orchestrator: bridge, now: () => now));
      await goTab(tester, 1);
      expect(find.text('AUTOPILOT'), findsOneWidget);
      expect(find.text('ORCHESTRATOR'), findsWidgets);
      if (scale > 1.5) {
        expect(find.text('STATUS'), findsNothing, reason: 'folded at large text so the Deck keeps its room');
        await tester.tap(find.byTooltip('Show the commands'));
        await settle(tester);
      }
      // Every command is on screen at phone width — wrapped, not scrolled away.
      for (final label in ['STATUS', 'CHECK', 'TELL A LANE', 'WAIT AT NEXT STOP', 'CONTINUE', 'WATCH', 'AWAY', 'STOP WATCHING', 'APPROVE MESHY']) {
        await tester.ensureVisible(find.text(label));
        final r = tester.getRect(find.text(label));
        expect(r.right <= 360 && r.left >= 0, isTrue, reason: '$label is inside the window');
      }
      await tester.tap(find.byTooltip('Fold the commands'));
      await settle(tester);
      expect(find.text('STATUS'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('without an orchestrator folder the tab says how to set one', (tester) async {
    await pumpStudio(tester, 1.0);
    await goTab(tester, 1);
    expect(find.textContaining('orchestrator\'s folder'), findsOneWidget);
  });

  testWidgets('the lane machines come from run-lane.sh', (tester) async {
    await pumpStudio(tester, 1.0, size: const Size(900, 1400));
    await goTab(tester, 2);
    expect(find.text('DEPENDS ON'), findsOneWidget, reason: 'LANES opens on the dependency graph');
    await tester.tap(find.byTooltip('Lane cards'));
    await settle(tester);
    expect(find.text('WINDOWS PC'), findsOneWidget);
    expect(find.text('MAC MINI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 3.12]) {
    testWidgets('at ${scale}x: INBOX lists mail, decisions and issues; a mail opens', (tester) async {
      await pumpStudio(tester, scale);
      await goTab(tester, 4);
      expect(find.text('MAIL · 1'), findsOneWidget);
      expect(find.text('Lane A run 1099: Room Lab 1B is in'), findsOneWidget);
      await tester.tap(find.text('DECIDED · 1'));
      await settle(tester);
      expect(find.textContaining('acked lane A'), findsOneWidget);
      await tester.tap(find.text('ISSUES · 1'));
      await settle(tester);
      expect(find.text('OPEN · LANE A'), findsOneWidget);
      await tester.tap(find.text('MAIL · 1'));
      await settle(tester);
      await tester.tap(find.text('Lane A run 1099: Room Lab 1B is in'));
      await settle(tester);
      expect(find.textContaining('Room Lab', findRichText: true), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('DOCS: the plan opens as its parts, one part at a time', (tester) async {
    await pumpStudio(tester, 1.0);
    await goTab(tester, 5);
    expect(find.text('Production plan'), findsOneWidget);
    expect(find.text('Game overview'), findsOneWidget);
    await tester.tap(find.text('Production plan'));
    await settle(tester);
    expect(find.text('Who is on what'), findsOneWidget);
    expect(find.text('Waiting on a person'), findsOneWidget);
    await tester.tap(find.text('Who is on what'));
    await settle(tester);
    expect(find.textContaining('Fırat and Görkem', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
