// What belongs to a step, found on disk: pictures and folders its text
// names (looked up in the lane's repo, ~/StudioProjects, the game repo),
// mail that mentions it, its decision-log entries and its log; and moving a
// step by hold-and-drag as a draft order.
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/studio/studio_constellation.dart';
import 'package:kit_app/src/studio/studio_desk.dart';
import 'package:kit_app/src/studio/studio_draft.dart';
import 'package:kit_app/src/studio/studio_graph.dart';
import 'package:kit_app/src/studio/studio_plans.dart';
import 'package:kit_app/src/studio/studio_resources.dart';
import 'package:kit_app/src/theme.dart';
import 'package:path/path.dart' as p;

void main() {
  test('namedPaths: files with known kinds and folders, not URLs or prose', () {
    expect(namedPaths('Sheet: `docs/testing/room-lab/1b/builds-sheet.jpg`; how-to `docs/testing/room-lab/README.md`; renders in docs/art/mine-kit/rock-surface/ and see https://x.com/a/b.png'), ['docs/testing/room-lab/1b/builds-sheet.jpg', 'docs/testing/room-lab/README.md', 'docs/art/mine-kit/rock-surface/']);
    expect(namedPaths('[ADR-037](../docs/architecture/ADR-037-combat.md)'), ['../docs/architecture/ADR-037-combat.md']);
    expect(namedPaths('on branch claude/mine-room-layouts'), isEmpty, reason: 'a branch is not a file');
  });

  test('ResourceFinder: pictures (and a folder\'s), docs, mail naming the id, decisions, the log; missing files counted', () {
    final root = Directory.systemTemp.createTempSync('res_root_');
    final auto = Directory.systemTemp.createTempSync('res_auto_');
    addTearDown(() {
      root.deleteSync(recursive: true);
      auto.deleteSync(recursive: true);
    });
    void w(Directory d, String rel, String text) => (File(p.join(d.path, rel))..createSync(recursive: true)).writeAsStringSync(text);
    w(root, 'docs/testing/room-lab/1b/builds-sheet.jpg', 'x');
    w(root, 'docs/art/rock/a.png', 'x');
    w(root, 'docs/art/rock/b.png', 'x');
    w(root, 'docs/testing/room-lab/README.md', '# How to');
    w(root, 'production/autopilot/lane-a-decisions.md', '### 2026-11-06 step run 1099: ROOMLAB-1B - the window\nchose the menu\n### 2026-11-05 step run 1093: HOTPLATE\nother\n');
    w(auto, 'mail/to-user/20261106-2230-roomlab-1b-ready.md', '# Lane A run 1099: Room Lab 1B is in\nROOMLAB-1B window');
    w(auto, 'mail/read/20261101-0000-old.md', '# Old\nnothing');
    w(auto, 'lane-a/logs/step-1099.log', 'log');
    final f = ResourceFinder(roots: [root.path, auto.path], mailDir: p.join(auto.path, 'mail'), logDir: auto.path);
    final r = f.find(
      id: 'ROOMLAB-1B',
      run: '1099',
      lane: 'a',
      text: 'the window; sheet `docs/testing/room-lab/1b/builds-sheet.jpg`, how-to `docs/testing/room-lab/README.md`, renders docs/art/rock/, video docs/clips/tour.mp4',
      decisionsFile: p.join(root.path, 'production/autopilot/lane-a-decisions.md'),
    );
    expect(r.images.map(p.basename), ['builds-sheet.jpg', 'a.png', 'b.png']);
    expect(r.docs.map(p.basename), ['README.md']);
    expect(r.mails.single.title, 'Lane A run 1099: Room Lab 1B is in');
    expect(r.decisions.single.$1, '2026-11-06 step run 1099: ROOMLAB-1B - the window');
    expect(r.log, endsWith('step-1099.log'));
    expect(r.missing, 1, reason: 'the video is not on this machine');
    expect(r.label, '3 PICTURES · 1 DOC · 1 MAIL · 1 DECISION · LOG');
  });

  test('a summary block is the step\'s summary, not an answer', () {
    final parts = splitAnswer('```studio-summary\nIt builds one room on demand. It lets testers try a trap without a whole map.\n```');
    expect(parts.summary, 'It builds one room on demand. It lets testers try a trap without a whole map.');
    expect(parts.prose, isEmpty);
  });

  test('a move order: lane and roadmap wording, and one move per step', () {
    final d = StudioDraft(persist: false)
      ..add(const DraftOrder(kind: DraftKind.move, lane: 'a', target: 'A4', other: '^'))
      ..add(const DraftOrder(kind: DraftKind.move, lane: 'a', target: 'A4', other: 'A3'));
    expect(d.orders.single.summary, 'Lane A · A4 — move after A3');
    expect(d.moved, {'a/A4': 'a/A3'});
    expect(const DraftOrder(kind: DraftKind.move, target: 'M3.2', other: 'milestone:M4').instruction, contains('move this item into milestone M4'));
    expect(const DraftOrder(kind: DraftKind.move, lane: 'b', target: 'B3', other: '^').summary, 'Lane B · B3 — move to the front');
  });

  testWidgets('hold a step and drag it along its lane: a move order lands in the draft', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tracks = {'a': LaneTrack.from(parseStepList('- [x] A1: one\n- [ ] A2: two\n- [ ] A3: three\n- [ ] A4: four\n'), running: true, lastDoneId: 'A1')};
    final g = LaneGraph.build(tracks);
    final draft = StudioDraft(persist: false);
    await tester.pumpWidget(MaterialApp(theme: kitTheme(KitTokens.light), home: Scaffold(body: LaneConstellation(graph: g, lanes: const [], draft: draft))));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    final sky = tester.renderObject<RenderBox>(find.byKey(const Key('lane-sky')));
    final from = sky.localToGlobal(LaneConstellation.positionOf(g, g.node('a/A4')!));
    final to = sky.localToGlobal(LaneConstellation.positionOf(g, g.node('a/A2')!)) + const Offset(-20, 0);
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(draft.orders.single.summary, 'Lane A · A4 — move to the front', reason: 'dropped before A2, the first open step');
    expect(tester.takeException(), isNull);
  });
}
