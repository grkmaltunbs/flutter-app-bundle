// Editing on the graphs: every change is a draft order — link, unlink,
// accept a suggestion, add, edit, remove — drawn in violet, kept across a
// relaunch, and sent to the orchestrator as one message by SEND TO
// ORCHESTRATOR. The app never writes a step list itself.
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/studio/studio_constellation.dart';
import 'package:kit_app/src/studio/studio_data.dart';
import 'package:kit_app/src/studio/studio_draft.dart';
import 'package:kit_app/src/studio/studio_graph.dart';
import 'package:kit_app/src/studio/studio_orchestrator.dart';
import 'package:kit_app/src/studio/studio_plans.dart';
import 'package:kit_app/src/studio/studio_screen.dart';
import 'package:kit_app/src/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_claude.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('StudioDraft', () {
    test('a link and its unlink cancel; a second edit replaces the first; duplicates are dropped', () {
      final d = StudioDraft(persist: false);
      d.add(const DraftOrder(kind: DraftKind.link, lane: 'a', target: 'A4', other: 'lane-b/B1'));
      d.add(const DraftOrder(kind: DraftKind.link, lane: 'a', target: 'A4', other: 'lane-b/B1'));
      expect(d.length, 1);
      d.add(const DraftOrder(kind: DraftKind.unlink, lane: 'a', target: 'A4', other: 'lane-b/B1'));
      expect(d.isEmpty, isTrue, reason: 'unlinking a pending link takes it back');
      d.add(const DraftOrder(kind: DraftKind.edit, lane: 'a', target: 'A4', text: 'one'));
      d.add(const DraftOrder(kind: DraftKind.edit, lane: 'a', target: 'A4', text: 'two'));
      expect(d.orders.single.text, 'two');
      d.add(const DraftOrder(kind: DraftKind.remove, lane: 'a', target: 'A4'));
      expect(d.orders.single.kind, DraftKind.remove, reason: 'removing a step drops its pending edit');
    });

    test('what the graph draws: links and unlinks by key, removed, edited, added', () {
      final d = StudioDraft(persist: false)
        ..add(const DraftOrder(kind: DraftKind.link, lane: 'a', target: 'A4', other: 'lane-b/B1'))
        ..add(const DraftOrder(kind: DraftKind.link, lane: 'a', target: 'A4', other: 'A2'))
        ..add(const DraftOrder(kind: DraftKind.unlink, lane: 'a', target: 'A3', other: 'lane-b/B2'))
        ..add(const DraftOrder(kind: DraftKind.add, lane: 'b', target: 'B2', newId: 'B3', text: 'three'))
        ..add(const DraftOrder(kind: DraftKind.edit, lane: 'c', target: '469', text: 'x'))
        ..add(const DraftOrder(kind: DraftKind.link, target: 'M3.22', other: 'M3.2'));
      expect(d.laneLinks, [('b/B1', 'a/A4'), ('a/A2', 'a/A4')]);
      expect(d.laneUnlinks, {'b/B2>a/A3'});
      expect(d.added, [('b/B2', 'B3')]);
      expect(d.edited, {'c/469'});
      expect(d.roadmapLinks, [('M3.2', 'M3.22')]);
      expect(d.roadmapTouched, {'M3.22'});
    });

    test('the message: numbered orders, the after: tag written as the parser reads it', () {
      final text = draftPrompt([
        const DraftOrder(kind: DraftKind.link, lane: 'a', target: 'A4', other: 'lane-b/B1'),
        const DraftOrder(kind: DraftKind.add, lane: 'b', target: 'B2', newId: 'B3', text: 'three\n  - a substep'),
        const DraftOrder(kind: DraftKind.remove, target: 'M3.2'),
      ]);
      expect(text, startsWith('[Studio · plan changes] The user sends 3 changes'));
      expect(text, contains('1. Lane A · A4 — make it wait on lane-b/B1: append ` (after: lane-b/B1)`'));
      expect(text, contains('2. Lane B — add a new open step right after B2:\n    - [ ] B3: three\n      - a substep'));
      expect(text, contains('3. Roadmap · M3.2 — remove this item.'));
      // What the orchestrator is asked to write is what the graph reads back.
      expect(parseAfterTag('A4: fourth (after: lane-b/B1)'), [const DepRef(lane: 'b', id: 'B1')]);
    });

    test('kept across a relaunch', () async {
      StudioDraft().add(const DraftOrder(kind: DraftKind.remove, lane: 'a', target: 'A4'));
      await pumpEventQueue();
      final again = StudioDraft();
      await again.restore();
      expect(again.orders.single.summary, 'Lane A · A4 — remove');
    });
  });

  final tracks = {
    'a': LaneTrack.from(parseStepList('''
- [x] A1 (run 10): first
- [x] A2 (run 11): second, with lane C 468
- [ ] A3: third (after: lane-b/B2)
- [ ] A4: fourth
'''), running: true, lastDoneId: 'A2'),
    'b': LaneTrack.from(parseStepList('- [x] B1 (run 5): one\n- [ ] B2: two\n'), running: false),
    'c': LaneTrack.from(parseStepList('- [x] step 468: the package read\n'), running: false),
  };

  testWidgets('on the lane graph: WAITS ON… then a tap links; ✓ accepts a suggestion; × unlinks; REMOVE and ADD AFTER; the bar sends it all', (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final g = LaneGraph.build(tracks);
    final draft = StudioDraft(persist: false);
    final home = Directory.systemTemp.createTempSync('studio_draft_home_');
    final proj = Directory.systemTemp.createTempSync('studio_draft_proj_');
    addTearDown(() {
      home.deleteSync(recursive: true);
      proj.deleteSync(recursive: true);
    });
    final fake = FakeClaude();
    final bridge = fakeSession(fake, dir: proj.path, home: home.path);
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: Scaffold(body: LaneConstellation(graph: g, lanes: const [], draft: draft), bottomNavigationBar: DraftBar(draft: draft, send: (text) => sendToOrchestrator(bridge, text))),
    ));
    await settle(tester);
    final sky = tester.renderObject<RenderBox>(find.byKey(const Key('lane-sky')));
    Future<void> tapRing(String key) async {
      await tester.tapAt(sky.localToGlobal(LaneConstellation.positionOf(g, g.node(key)!)));
      await settle(tester);
    }

    // Link: A4 waits on B1.
    await tapRing('a/A4');
    await tester.tap(find.text('WAITS ON…'));
    await settle(tester);
    expect(find.text('Tap the step LANE A · A4 waits on'), findsOneWidget);
    await tapRing('b/B1');
    expect(draft.orders.single.instruction, contains('(after: lane-b/B1)'));
    expect(find.text('1 CHANGE IN THE DRAFT'), findsOneWidget);
    expect(find.text('YOUR CHANGES'), findsOneWidget);

    // Accept the suggestion on A2 (lane C 468), unlink A3 from B2.
    await tapRing('a/A2');
    await tester.tap(find.byTooltip('Accept: make it a real link'));
    await settle(tester);
    expect(draft.orders.last.summary, 'Lane A · A2 waits on lane-c/468');
    await tapRing('a/A3');
    await tester.tap(find.byTooltip('Unlink'));
    await settle(tester);
    expect(draft.orders.last.summary, 'Lane A · A3 no longer waits on lane-b/B2');

    // Remove A4, then think better of it; add a step after B2.
    await tapRing('a/A4');
    await tester.tap(find.text('REMOVE'));
    await settle(tester);
    expect(draft.removed, {'a/A4'});
    await tester.tap(find.text('KEEP IT'));
    await settle(tester);
    expect(draft.removed, isEmpty);
    await tapRing('b/B2');
    expect(find.text('LANE B · B2'), findsOneWidget, reason: 'the B2 panel');
    await tester.tap(find.text('ADD AFTER'));
    await settle(tester);
    expect(find.text('New step after B2'), findsOneWidget, reason: 'the dialog');
    await tester.enterText(find.widgetWithText(TextField, 'Step id (e.g. ROOMLAB-2A)'), 'B3');
    await tester.enterText(find.widgetWithText(TextField, 'What the step does'), 'three\n  - a substep');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'ADD TO DRAFT')).onPressed, isNotNull, reason: 'the dialog accepts it');
    await tester.tap(find.text('ADD TO DRAFT'));
    await settle(tester);
    expect(draft.added, [('b/B2', 'B3')]);
    expect(find.text('4 CHANGES IN THE DRAFT'), findsOneWidget);

    // Send: one message, the draft clears.
    // The fake process lives on real time: start and read it outside the
    // test's fake clock.
    await tester.runAsync(() async {
      await bridge.start();
      await pumpEventQueue();
    });
    await tester.tap(find.text('SEND TO ORCHESTRATOR'));
    await settle(tester);
    await tester.runAsync(() => fake.writtenLines(1).timeout(const Duration(seconds: 5)));
    expect(fake.written.single, contains('[Studio · plan changes] The user sends 4 changes'));
    expect(draft.isEmpty, isTrue);
    expect(find.text('4 CHANGES IN THE DRAFT'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(bridge.stop);
  });

  testWidgets('on the roadmap: WAITS ON… then a tap links two items; × unlinks', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ms = parseRoadmap('''
## Open work

### M3 — Alpha

| ID | Task | Size | Owner | Status | Summary |
|---|---|---|---|---|---|
| M3.21 | Bugs | M | Dev | In progress | x |
| M3.22 | Area | L | Dev | In progress — after M3.21 | y |
| M3.2 | Themes | L | Dev | Not started | z |
''');
    final lay = RoadmapLayout.build(ms);
    final draft = StudioDraft(persist: false);
    await tester.pumpWidget(MaterialApp(theme: kitTheme(KitTokens.light), home: Scaffold(body: RoadmapConstellation(milestones: ms, draft: draft))));
    await settle(tester);
    final sky = tester.renderObject<RenderBox>(find.byKey(const Key('road-sky')));
    await tester.tapAt(sky.localToGlobal(lay.items['M3.2']!.at));
    await settle(tester);
    await tester.tap(find.text('WAITS ON…'));
    await settle(tester);
    expect(find.text('Tap the item M3.2 waits on'), findsOneWidget);
    await tester.tapAt(sky.localToGlobal(lay.items['M3.22']!.at));
    await settle(tester);
    expect(draft.orders.single.summary, 'Roadmap · M3.2 waits on M3.22');
    await tester.tapAt(sky.localToGlobal(lay.items['M3.22']!.at));
    await settle(tester);
    await tester.tap(find.byTooltip('Unlink'));
    await settle(tester);
    expect(draft.orders.last.summary, 'Roadmap · M3.22 no longer waits on M3.21');
    expect(tester.takeException(), isNull);
  });

  test('a lane with nothing in the draft draws as before', () {
    expect(StudioDraft(persist: false).laneLinks, isEmpty);
    expect(Lane(id: 'a', status: LaneStatus.parse(''), history: const []).name, 'Lane A');
  });
}
