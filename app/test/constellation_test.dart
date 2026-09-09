// The constellation as a control surface: a step's sheet starts, asks what
// blocks, and marks done; a long-press drag moves a bubble past another
// and the draft keeps it until Apply; the phone's round trip through a
// Mac in miniature.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/draft.dart';
import 'package:kit_app/src/relay.dart';
import 'package:kit_app/src/screens/step_detail.dart';
import 'package:kit_app/src/screens/steps_tab.dart';
import 'package:kit_app/src/theme.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child, {Size size = const Size(360, 780), double scale = 1.0}) => MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)), child: Scaffold(body: child)),
    );

Plan _plan() => Plan(
      manifest: Manifest(projectName: 'T'),
      steps: [
        Step(id: 'a', number: '1', title: 'Alpha', rank: 100, status: StepStatus.done),
        Step(id: 'b', number: '2', title: 'Bravo', rank: 200, status: StepStatus.active, dependsOn: ['a'], gates: {'tests': Gate('tests', status: GateStatus.pending)}),
        Step(id: 'c', number: '3', title: 'Charlie', rank: 300, dependsOn: ['b']),
        Step(id: 'd', number: '4', title: 'Delta', rank: 400, dependsOn: ['a']),
      ],
      items: [Item(id: 'box', title: 'Plug it in', needs: ['device'], blocks: ['b'])],
    );

/// Actions that record what they were asked and answer from a script.
class _Rec {
  final calls = <String>[];
  bool running = false;
  String blocksLine = 'b  (Step 2 — Bravo)  [active]\n  gates not passed: tests (pending)\n  human items open:\n    box  Plug it in  [needs device]';
  String doneLine = 'b: gates not passed: tests. Record them with `kit gate`, or --force.';

  StepActions get actions => StepActions(
        sessionRunning: running,
        startSession: () async {
          calls.add('startSession');
          return 'started';
        },
        startStep: (id) async {
          calls.add('startStep $id');
          return 'sent';
        },
        blocks: (id) async {
          calls.add('blocks $id');
          return blocksLine;
        },
        markDone: (id) async {
          calls.add('done $id');
          return doneLine;
        },
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('draft', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('keeps moves on the device, counts them, batches them as reorders, and reads Apply when that is all it holds', () async {
      final d = Draft('t');
      await d.move('c', 'b');
      await d.move('d', null);
      await d.move('c', 'a'); // the last drag of a bubble wins
      expect(d.moves, const [StepPlace('d', null), StepPlace('c', 'a')]);
      expect(d.count, 2);
      expect(d.hostOnly, isTrue);
      final again = Draft('t');
      await again.load();
      expect(again.moves, d.moves, reason: 'survives a restart');
      expect(again.toBatch()['entries'], [
        {'kind': 'reorder', 'id': 'd', 'before': null},
        {'kind': 'reorder', 'id': 'c', 'before': 'a'},
      ]);
      expect(hostOnlyBatch(again.toBatch()), isTrue);
      again.steps['b'] = 'a note';
      expect(again.hostOnly, isFalse, reason: 'a note needs Claude');
      expect(again.count, 3);
      await again.clear();
      expect(again.moves, isEmpty);
      expect(again.count, 0);
      // A move before itself is nothing.
      await d.move('a', 'a');
      expect(d.moves.where((m) => m.id == 'a'), isEmpty);
    });
  });

  group('controls', () {
    for (final scale in [1.0, 2.0, 3.12]) {
      testWidgets('start, blocks and done at $scale× on a 360 phone — the host\'s line under them, a refusal in red', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final plan = _plan();
        final graph = Graph(plan);
        final rec = _Rec();
        Widget sheet() => _app(StepDetail(plan: plan, graph: graph, step: plan.step('b')!, draft: Draft('t'), onSelectStep: (_) {}, actions: rec.actions), scale: scale);
        await tester.pumpWidget(sheet());
        await tester.pump();
        // No session: Start is offered first.
        expect(find.text('START THE SESSION'), findsOneWidget);
        expect(find.text('START THIS STEP'), findsNothing);
        await tester.tap(find.text('START THE SESSION'), warnIfMissed: false);
        await tester.pump();
        await tester.pump();
        expect(rec.calls, ['startSession']);
        expect(find.text('started'), findsOneWidget);
        rec.running = true;
        await tester.pumpWidget(sheet());
        await tester.pump();
        expect(find.text('START THIS STEP'), findsOneWidget);
        await tester.tap(find.text('START THIS STEP'), warnIfMissed: false);
        await tester.pump();
        await tester.pump();
        expect(rec.calls.last, 'startStep b');
        expect(find.text('sent'), findsOneWidget);
        // Blocks: the rendering as the CLI prints it, in mono.
        await tester.tap(find.text('BLOCKS'), warnIfMissed: false);
        await tester.pump();
        await tester.pump();
        expect(rec.calls.last, 'blocks b');
        expect(find.textContaining('gates not passed: tests (pending)'), findsOneWidget);
        expect(find.textContaining('box  Plug it in'), findsOneWidget);
        // Mark done: refused with the gate's name, shown as an error.
        await tester.tap(find.text('MARK DONE'), warnIfMissed: false);
        await tester.pump();
        await tester.pump();
        expect(rec.calls.last, 'done b');
        final refusal = tester.widget<Text>(find.textContaining('gates not passed: tests. Record them'));
        expect(refusal.style?.color, KitTokens.light.critical);
        // A flip reads as good.
        rec.doneLine = 'b: done.\n  c is now ready to start.';
        await tester.tap(find.text('MARK DONE'), warnIfMissed: false);
        await tester.pump();
        await tester.pump();
        final flipped = tester.widget<Text>(find.textContaining('c is now ready to start'));
        expect(flipped.style?.color, isNot(KitTokens.light.critical));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a done step keeps only Blocks; the panel on the constellation carries the same controls', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final plan = _plan();
      final graph = Graph(plan);
      final rec = _Rec()..running = true;
      await tester.pumpWidget(_app(StepDetail(plan: plan, graph: graph, step: plan.step('a')!, draft: Draft('t'), onSelectStep: (_) {}, actions: rec.actions)));
      await tester.pump();
      expect(find.text('BLOCKS'), findsOneWidget);
      expect(find.text('START THIS STEP'), findsNothing);
      expect(find.text('MARK DONE'), findsNothing);
      // The panel under the bubbles.
      await tester.pumpWidget(_app(StepsTab(plan: plan, graph: graph, selected: 'c', onSelect: (_) {}, actions: rec.actions)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('START THIS STEP'), findsOneWidget);
      expect(find.text('MARK DONE'), findsOneWidget);
      await tester.tap(find.text('BLOCKS'), warnIfMissed: false);
      await tester.pump();
      await tester.pump();
      expect(rec.calls, ['blocks c']);
      expect(tester.takeException(), isNull);
    });
  });

  group('drag to reorder', () {
    Future<Offset> bubble(WidgetTester tester, String title) async => tester.getCenter(find.text(title));

    testWidgets('a hold lifts a bubble; dropped past a later one it goes after it, past an earlier one before it; the draft ring draws', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final plan = _plan();
      final graph = Graph(plan);
      final moves = <(String, String?)>[];
      await tester.pumpWidget(_app(StepsTab(plan: plan, graph: graph, selected: null, onSelect: (_) {}, onReorder: (id, before) => moves.add((id, before)), draftMoved: const {'d'}), size: const Size(400, 800)));
      await tester.pump(const Duration(milliseconds: 100));
      // The title sits under the bubble; a hold there lifts it.
      final from = await bubble(tester, 'Delta');
      final to = await bubble(tester, 'Bravo');
      final g = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 700));
      await g.moveTo(to);
      await tester.pump(const Duration(milliseconds: 50));
      await g.up();
      await tester.pump();
      // d ranks after b: dragging back past b lands before b.
      expect(moves, [('d', 'b')]);
      // b dragged forward past c lands after c — before d.
      final g2 = await tester.startGesture(await bubble(tester, 'Bravo'));
      await tester.pump(const Duration(milliseconds: 700));
      await g2.moveTo(await bubble(tester, 'Charlie'));
      await tester.pump(const Duration(milliseconds: 50));
      await g2.up();
      await tester.pump();
      expect(moves.last, ('b', 'd'));
      // Dropped on nothing — far off to the side of every bubble: no move.
      final g3 = await tester.startGesture(await bubble(tester, 'Alpha'));
      await tester.pump(const Duration(milliseconds: 700));
      await g3.moveBy(const Offset(500, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await g3.up();
      await tester.pump();
      expect(moves.length, 2);
      // A plain tap still selects.
      expect(tester.takeException(), isNull);
    });

    testWidgets('without onReorder a hold is only a tap', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final plan = _plan();
      String? selected;
      await tester.pumpWidget(_app(StepsTab(plan: plan, graph: Graph(plan), selected: null, onSelect: (id) => selected = id), size: const Size(400, 800)));
      await tester.pump(const Duration(milliseconds: 100));
      final g = await tester.startGesture(await bubble(tester, 'Delta'));
      await tester.pump(const Duration(milliseconds: 700));
      await g.up();
      await tester.pump();
      // No drag recognizer: the hold resolved as the bubble's tap.
      expect(selected, 'd');
      expect(tester.takeException(), isNull);
    });
  });

  group('over the relay', () {
    late Directory tmp;
    late PlanStore store;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('constellation-');
      store = PlanStore(p.join(tmp.path, 'plan'));
      store.writeManifest(Manifest(projectName: 'Demo'));
      for (final s in _plan().steps) {
        store.writeStep(s);
      }
      for (final i in _plan().items) {
        store.writeItem(i);
      }
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('blocks and step_done are host commands answered by the Mac; the phone waits for the line', () async {
      final db = FakeFirebaseFirestore();
      final project = db.collection('projects').doc('demo');
      await project.set({'name': 'Demo'});
      // The Mac, in miniature: the kit library behind two host actions.
      final sub = project.collection('commands').snapshots().listen((q) async {
        for (final d in q.docs) {
          final m = d.data();
          if (m['doneAt'] != null || m['type'] != 'host') continue;
          final plan = store.load();
          final id = m['step'] as String;
          String result;
          if (m['action'] == 'blocks') {
            result = plan.step(id) == null ? 'No step "$id"' : renderBlocks(plan, id).trimRight();
          } else {
            try {
              result = stepDone(store, id, today: '2026-09-10').lines;
            } on StepRefused catch (e) {
              result = e.message;
            }
          }
          await d.reference.set({'doneAt': 'now', 'result': result}, SetOptions(merge: true));
        }
      });
      final blocks = await waitedCommand(db, 'demo', {'type': 'host', 'action': 'blocks', 'step': 'c'}, from: 'phone');
      expect(blocks, startsWith('c  (Step 3 — Charlie)  [blocked]'));
      expect(blocks, contains('waiting on you: box  Plug it in'));
      expect(await waitedCommand(db, 'demo', {'type': 'host', 'action': 'step_done', 'step': 'b'}, from: 'phone'), startsWith('b: gates not passed: tests.'));
      expect(await waitedCommand(db, 'demo', {'type': 'host', 'action': 'step_done', 'step': 'd'}, from: 'phone'), 'd: done.');
      expect(store.load().step('d')!.status, StepStatus.done);
      await sub.cancel();
    });

    test('a batch of moves alone is applied by the Mac with no model; the sender reads the lines back', () async {
      final db = FakeFirebaseFirestore();
      final listener = InboxListener(db, 'demo', apply: (batch) async => applyInbox(store, batch, today: '2026-09-10'))..start();
      final d = Draft('t');
      SharedPreferences.setMockInitialValues({});
      await d.move('c', 'b');
      final batch = d.toBatch();
      expect(hostOnlyBatch(batch), isTrue);
      final ref = await InboxSender(db, 'demo').send(batch, from: 'phone');
      final done = await ref.snapshots().firstWhere((s) => s.data()?['appliedAt'] != null);
      expect(done.data()!['lines'], ['reorder c: moved before b (rank 300 → 150)']);
      expect(store.load().steps.map((s) => s.id), ['a', 'c', 'b', 'd']);
      listener.dispose();
    });
  });
}
