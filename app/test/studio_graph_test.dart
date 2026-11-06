// The constellations as data and on screen: `after:` tags become links
// (across lanes too), "lane C 468" mentions become suggestions, every lane's
// NOW lines up, the roadmap's items orbit their milestone — and a tap on a
// ring opens its panel.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/studio/studio_constellation.dart';
import 'package:kit_app/src/studio/studio_data.dart';
import 'package:kit_app/src/studio/studio_graph.dart';
import 'package:kit_app/src/studio/studio_plans.dart';
import 'package:kit_app/src/theme.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  test('after: tags — lanes, bare ids, several, and where the tag stops', () {
    expect(parseAfterTag('ROOMLAB-1C: Play (after: lane-b/PIT-LINER, ROOMLAB-1B)'), [const DepRef(lane: 'b', id: 'PIT-LINER'), const DepRef(id: 'ROOMLAB-1B')]);
    expect(parseAfterTag('X — after: c/476; then more'), [const DepRef(lane: 'c', id: '476')]);
    expect(parseAfterTag('Y — after: `a/ROOMLAB-1A` — the rest of the line'), [const DepRef(lane: 'a', id: 'ROOMLAB-1A')]);
    expect(parseAfterTag('nothing here, after the hotfix'), isEmpty);
  });

  test('lane mentions and roadmap ids in a step', () {
    expect(parseLaneMentions('PLAY-BUILD-CHECK (run 1067; lane C 468): clean; lane B run 674 merged', ownLane: 'a'), [const DepRef(lane: 'c', run: '468'), const DepRef(lane: 'b', run: '674')]);
    expect(parseLaneMentions('lane A 1081 request', ownLane: 'a'), isEmpty, reason: 'its own lane is not a link');
    expect(parseRoadmapIds('M3.41 descent; SR.6 telemetry; M3.41 again'), ['M3.41', 'SR.6']);
  });

  final tracks = {
    'a': LaneTrack.from(parseStepList('''
- [x] A1 (run 10): first
- [x] A2 (run 11): second, with lane C 468
- [ ] A3: third (after: lane-b/B2)
- [ ] A4: fourth (after: A3, c/999)
'''), running: true, lastDoneId: 'A2'),
    'b': LaneTrack.from(parseStepList('- [x] B1 (run 5): one\n- [ ] B2: two\n'), running: false),
    'c': LaneTrack.from(parseStepList('- [x] step 468: the package read\n- [x] step 469: next\n'), running: false),
  };

  test('LaneGraph: NOW lines up, rails, real links across lanes, suggestions, links out of view', () {
    final g = LaneGraph.build(tracks);
    expect(g.lanes, ['a', 'b', 'c']);
    expect(g.node('a/A3')!.col, 0, reason: 'lane A works on A3: it sits on NOW');
    expect(g.node('a/A3')!.kind, NodeKind.current);
    expect(g.node('b/B2')!.col, 0, reason: 'lane B waits: its next open step sits on NOW');
    expect(g.node('c/469')!.col, -1);
    expect(g.edges.where((e) => e.kind == EdgeKind.rail).length, 3 + 1 + 1);
    final after = g.edges.where((e) => e.kind == EdgeKind.after).map((e) => '${e.from}>${e.to}').toList();
    expect(after, containsAll(['b/B2>a/A3', 'a/A3>a/A4']));
    expect(g.edges.firstWhere((e) => e.to == 'a/A3' && e.kind == EdgeKind.after).crossLane, isTrue);
    final sug = g.edges.where((e) => e.kind == EdgeKind.suggested).single;
    expect('${sug.from}>${sug.to}', 'c/468>a/A2');
    expect(g.offscreen['a/A4'], [const DepRef(lane: 'c', id: '999')], reason: 'c/999 is in no list: said, not drawn');
  });

  test('LaneGraph keeps a window around NOW unless all is asked for', () {
    final long = {'a': LaneTrack.from(parseStepList([for (var i = 0; i < 30; i++) '- [${i < 20 ? 'x' : ' '}] S$i: s'].join('\n')), running: true)};
    final g = LaneGraph.build(long, before: 3, after: 4);
    expect(g.nodes.map((n) => n.item.id), ['S17', 'S18', 'S19', 'S20', 'S21', 'S22', 'S23', 'S24']);
    expect(LaneGraph.build(long, all: true).nodes, hasLength(30));
  });

  final milestones = parseRoadmap('''
## Milestone ladder

| # | Milestone | Goal | Exit | Status |
|---|---|---|---|---|
| M2 | **Pre-alpha** (v0.3) | One full run | x | Closed |
| M3 | **Alpha** (v0.4) | Run engine complete | x | In progress |

## Open work

### M3 — Alpha

| ID | Task | Size | Owner | Status | Summary |
|---|---|---|---|---|---|
| M3.21 | Run-breaking bugs | M | Dev | In progress — stage B | x |
| M3.22 | Reference area | L | Dev | In progress — after M3.21 | y |
| M3.2 | Themes | L | Dev | Not started | z |

## Done

### M2 — Pre-alpha

| ID | Task | Size | Owner | Done | Summary |
|---|---|---|---|---|---|
| M2.1 | One run | S | Dev | 2026-10-01 | s |
''');

  test('RoadmapLayout: stars left to right, items around their star, links from the text, the current star', () {
    final lay = RoadmapLayout.build(milestones);
    expect(lay.stars.keys, ['M2', 'M3']);
    expect(lay.stars['M3']!.dx, greaterThan(lay.stars['M2']!.dx));
    for (final id in ['M3.21', 'M3.22', 'M3.2']) {
      final d = (lay.items[id]!.at - lay.stars['M3']!).distance;
      expect(d, closeTo(74, 0.5), reason: '$id on the first ring of M3');
    }
    expect(lay.links, [('M3.21', 'M3.22')]);
    expect(lay.current, 'M3');
    expect(lay.size.width, greaterThan(lay.stars['M3']!.dx));
  });

  Widget app(Widget child) => MaterialApp(theme: kitTheme(KitTokens.light), home: Scaffold(body: child));

  testWidgets('the lane sky: a tap on a ring opens its panel with what it waits on; a link jumps', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final g = LaneGraph.build(tracks);
    final asked = <String>[];
    await tester.pumpWidget(app(LaneConstellation(graph: g, lanes: [Lane(id: 'a', status: LaneStatus.parse('2026-11-07 09:00:00  running step 12 (claude m/high)'), history: const [])], onAsk: (l, i) => asked.add('$l/${i.id}'))));
    await settle(tester);
    expect(find.text('DEPENDS ON'), findsOneWidget);
    final sky = tester.renderObject<RenderBox>(find.byKey(const Key('lane-sky')));
    await tester.tapAt(sky.localToGlobal(LaneConstellation.positionOf(g, g.node('a/A3')!)));
    await settle(tester);
    expect(find.text('LANE A · A3'), findsOneWidget);
    expect(find.text('WAITS ON'), findsOneWidget);
    expect(find.text('LANE B · B2'), findsOneWidget);
    expect(find.text('UNLOCKS'), findsOneWidget);
    await tester.tap(find.text('ASK A QUESTION'));
    expect(asked, ['a/A3']);
    await tester.tap(find.text('LANE B · B2'));
    await settle(tester);
    expect(find.text('LANE B · B2'), findsWidgets, reason: 'the panel is on B2 now');
    expect(find.text('NEXT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lane with no steps says so in its row; the effects stop when the app is not active', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final g = LaneGraph.build({...tracks, 'd': LaneTrack.empty});
    expect(g.lanes, contains('d'));
    expect(g.nodes.where((n) => n.lane == 'd'), isEmpty);
    await tester.pumpWidget(app(LaneConstellation(graph: g, lanes: [Lane(id: 'a', status: LaneStatus.parse('2026-11-07 09:00:00  running step 12 (claude m/high)'), history: const [])])));
    await settle(tester);
    // Background: the timers stop, nothing repaints.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 200));
    final before = tester.binding.hasScheduledFrame;
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'no frames while the app is in the background (was $before)');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the mouse wheel zooms around the pointer, eased over frames; Shift + wheel pans sideways', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final g = LaneGraph.build(tracks);
    await tester.pumpWidget(app(LaneConstellation(graph: g, lanes: const [])));
    await settle(tester);
    Matrix4 m() => tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value;
    expect(m().getMaxScaleOnAxis(), closeTo(1, 0.001));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final at = tester.getCenter(find.byKey(const Key('lane-sky')));
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final mid = m().getMaxScaleOnAxis();
    final end = 1.6487; // e^(120/240)
    expect(mid, greaterThan(1.0), reason: 'on its way in');
    expect(mid, lessThan(end - 0.1), reason: 'eased, not jumped');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(m().getMaxScaleOnAxis(), closeTo(end, 0.01));
    // The point under the pointer stays under it.
    final scene = MatrixUtils.transformPoint(Matrix4.inverted(m()), at);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(m().getMaxScaleOnAxis(), closeTo(1, 0.01), reason: 'back out');
    final again = MatrixUtils.transformPoint(Matrix4.inverted(m()), at);
    expect((again - scene).distance, lessThan(1.5));

    final x0 = m().storage[12];
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 80)));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(m().storage[12], closeTo(x0 - 80, 0.6), reason: 'Shift + wheel pans sideways');

    // Out, and out again: the zoom stops at its floor (30 %) — below 100 % the
    // zoom is read from the x scale, not getMaxScaleOnAxis (which counts z).
    for (final _ in [1, 2]) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 240)));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    expect(m().storage[0], closeTo(0.3, 0.005));
    expect(m().getMaxScaleOnAxis(), closeTo(1, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the roadmap sky: WE ARE HERE in the legend of states; a tap on an item opens it, on a star its milestone', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final lay = RoadmapLayout.build(milestones);
    await tester.pumpWidget(app(RoadmapConstellation(milestones: milestones, onAskItem: (_) {})));
    await settle(tester);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    final sky = tester.renderObject<RenderBox>(find.byKey(const Key('road-sky')));
    await tester.tapAt(sky.localToGlobal(lay.items['M3.22']!.at));
    await settle(tester);
    expect(find.text('M3.22 · Reference area'), findsOneWidget);
    expect(find.text('WAITS ON'), findsOneWidget);
    expect(find.text('M3.21'), findsOneWidget);
    await tester.tapAt(sky.localToGlobal(lay.stars['M3']!));
    await settle(tester);
    expect(find.text('M3 · ALPHA'), findsOneWidget);
    expect(find.text('WE ARE HERE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
