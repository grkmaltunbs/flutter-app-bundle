// Autopilot: the loop against a scripted claude and a plan on disk, the
// toggle, the sheet and the line on the Deck, and the same over the relay.
import 'dart:async';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/autopilot.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/relay.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/theme.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_claude.dart';

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this.callback);
  final Duration duration;
  final void Function() callback;
  bool _active = true;
  @override
  void cancel() => _active = false;
  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }
}

/// A scratch project: a plan with two ready steps, a bridge on a fake
/// claude, and the loop over both — wired as the host wires them.
class _Rig {
  _Rig({bool each = false}) {
    home = Directory.systemTemp.createTempSync('kit_auto_home_');
    project = Directory.systemTemp.createTempSync('kit_auto_project_');
    store = PlanStore(p.join(project.path, 'plan'));
    store.writeManifest(Manifest(projectName: 'Demo'));
    store.writeStep(Step(id: 'a', title: 'A', number: '1', rank: 1, gates: {'tests': Gate('tests')}));
    store.writeStep(Step(id: 'b', title: 'B', number: '2', rank: 2, gates: {'tests': Gate('tests')}));
    if (each) {
      bridge = fakeSessionEach(spawned, dir: project.path, home: home.path);
    } else {
      final f = FakeClaude();
      spawned.add(f);
      bridge = fakeSession(f, dir: project.path, home: home.path);
    }
    auto = Autopilot(
      bridge: bridge,
      loadPlan: () => store.load(),
      push: pushes.add,
      now: () => clock,
      timer: (d, f) {
        final t = _FakeTimer(d, f);
        timers.add(t);
        return t;
      },
    );
    bridge.addListener(auto.check);
  }

  late final Directory home;
  late final Directory project;
  late final PlanStore store;
  late final BridgeSession bridge;
  late final Autopilot auto;
  final spawned = <FakeClaude>[];
  final pushes = <String>[];
  final timers = <_FakeTimer>[];
  /// Whole seconds: the CLI's reset times are epoch seconds.
  DateTime clock = DateTime.fromMillisecondsSinceEpoch((DateTime.now().millisecondsSinceEpoch ~/ 1000) * 1000);

  FakeClaude get fake => spawned.last;

  /// Claude finished the step: `kit step done` on disk.
  void flip(String id) => store.patch(store.stepPath(id), ['status'], 'done');
  void failGate(String id) => store.appendTo(store.stepPath(id), ['history'], {'at': '2026-09-06', 'event': 'gate tests failed'});

  Future<void> endTurn({bool error = false, String text = 'done'}) async {
    fake.emitJson({'type': 'result', 'subtype': error ? 'error_during_execution' : 'success', 'is_error': error, 'duration_ms': 900, 'num_turns': 2, 'result': text, 'session_id': bridge.sessionId});
    await pumpEventQueue();
  }

  /// The loop clears the context before the next step: its `/clear` is
  /// the [n]th line written (1-based); the CLI answers with a reset and
  /// an empty result.
  Future<void> clearTurn(int n) async {
    await fake.writtenLines(n);
    expect(fake.written[n - 1], contains('"/clear"'), reason: 'a clean context before the next step');
    expect(autoRows.last, '/clear');
    fake.emitJson({'type': 'conversation_reset'});
    fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 3, 'num_turns': 0, 'result': '', 'session_id': bridge.sessionId});
    await pumpEventQueue();
  }

  Future<void> refuse({required DateTime resetsAt}) async {
    final epoch = resetsAt.millisecondsSinceEpoch ~/ 1000;
    fake.emitJson({'type': 'rate_limit_event', 'rate_limit_info': {'status': 'rejected', 'resetsAt': epoch, 'rateLimitType': 'five_hour', 'unifiedWindows': {'five_hour': {'utilization': 1.0, 'resetsAt': epoch}}}});
    await pumpEventQueue();
  }

  List<String> get autoRows => [for (final m in bridge.transcript.messages) if (m.role == DeckRole.user && m.by == 'autopilot') m.text];
  List<String> get notes => [for (final m in bridge.transcript.messages) if (m.role == DeckRole.note) m.text];

  Future<void> close() async {
    auto.dispose();
    if (bridge.running) await bridge.stop();
    home.deleteSync(recursive: true);
    project.deleteSync(recursive: true);
  }
}

Widget _app(Widget child, {required double scale}) => MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: child)),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

DeckView _deck({required AutopilotState auto, required Future<String?> Function({required bool on, int? budget, bool? nightShift}) onAutopilot, BridgeState state = BridgeState.busy, List<DeckMessage> messages = const [], bool? foldOnScroll = false}) => DeckView(
      state: state,
      title: 'Nahmatik',
      facts: const ['session abcd1234', 'claude-fable-5-1'],
      messages: messages,
      running: true,
      canResume: false,
      turnOpen: state == BridgeState.busy || state == BridgeState.waiting,
      onStart: () {},
      onResume: () {},
      onStop: () {},
      onSend: (_, _) async {},
      onInterrupt: () {},
      onOptions: ({mode, chrome, model, effort}) {},
      foldOnScroll: foldOnScroll,
      autopilot: auto,
      onAutopilot: onAutopilot,
    );

void main() {
  group('the loop', () {
    test('budget 2, two ready steps: two /steps in sequence, then budget reached — three pushes', () async {
      final r = _Rig();
      await r.bridge.start();
      expect(await r.auto.start(budget: 2), 'sent /step a · 1 of 2');
      expect(r.auto.on, isTrue);
      expect(r.auto.state.step, 'a');
      expect(r.auto.state.stepNumber, '1');
      await r.fake.writtenLines(1);
      expect(r.fake.written.single, contains('"/step a"'));
      expect(r.autoRows, ['/step a'], reason: 'the row is labelled as the loop\'s');
      expect(r.notes, ['Autopilot on · budget 2 · night shift off']);

      r.flip('a');
      await r.endTurn();
      expect(r.auto.done, 1);
      expect(r.auto.sent, 1, reason: 'the next /step waits for the clear');
      expect(r.pushes, ['Started · budget 2 · night shift off', 'Step 1 done · 1 of 2']);
      await r.clearTurn(2);
      expect(r.notes, contains('Context cleared.'));
      expect(r.auto.sent, 2);
      await r.fake.writtenLines(3);
      expect(r.fake.written[2], contains('"/step b"'));
      expect(r.auto.state.step, 'b');

      r.flip('b');
      await r.endTurn();
      expect(r.auto.on, isFalse);
      expect(r.auto.stoppedFor, 'budget reached');
      expect(r.pushes, ['Started · budget 2 · night shift off', 'Step 1 done · 1 of 2', 'Stopped · budget reached · Step 2 done · 2 of 2']);
      expect(r.notes.last, 'Autopilot stopped · budget reached · Step 2 done · 2 of 2');
      expect(r.fake.written.length, 3, reason: 'nothing more was sent');
      expect(r.autoRows, ['/step a', '/clear', '/step b']);
      expect(r.auto.state.toMap()['stoppedFor'], 'budget reached');
      await r.close();
    });

    test('a step that is still active after its turn gets another /step, on the budget', () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 3);
      await r.fake.writtenLines(1);
      r.store.patch(r.store.stepPath('a'), ['status'], 'active');
      await r.endTurn();
      await r.clearTurn(2);
      await r.fake.writtenLines(3);
      expect(r.fake.written[2], contains('"/step a"'), reason: 'the active step is what kit next names');
      expect(r.auto.sent, 2);
      expect(r.pushes, ['Started · budget 3 · night shift off'], reason: 'nothing flipped: no push');
      await r.close();
    });

    test('a step whose gate fails twice stops the loop, and the push names the step', () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 5);
      await r.fake.writtenLines(1);
      r.failGate('a');
      r.failGate('a');
      await r.endTurn();
      expect(r.auto.on, isFalse);
      expect(r.auto.stoppedFor, 'step 1 failed a gate twice');
      expect(r.pushes.last, 'Stopped · step 1 failed a gate twice');
      expect(r.fake.written.length, 1);
      await r.close();
    });

    test('one failed gate is not two: the loop carries on with the same step', () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 5);
      await r.fake.writtenLines(1);
      r.failGate('a');
      r.store.patch(r.store.stepPath('a'), ['status'], 'active');
      await r.endTurn();
      expect(r.auto.on, isTrue);
      await r.clearTurn(2);
      await r.fake.writtenLines(3);
      expect(r.fake.written[2], contains('"/step a"'));
      await r.close();
    });

    test('an ask mid-loop: the loop waits, the answer lets the turn go on, the loop continues', () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 3);
      await r.fake.writtenLines(1);
      scriptBashAsk(r.fake);
      await pumpEventQueue();
      expect(r.bridge.state, BridgeState.waiting);
      expect(r.auto.on, isTrue);
      expect(autopilotLine(r.auto.state, needsYou: true), 'Autopilot · step 1 · 1 of 3 · needs you');
      r.bridge.answer(AskAnswer.allow(r.bridge.transcript.pending!));
      await r.fake.writtenLines(2);
      expect(r.bridge.state, BridgeState.busy);
      r.flip('a');
      await r.endTurn();
      await r.clearTurn(3);
      await r.fake.writtenLines(4);
      expect(r.fake.written[3], contains('"/step b"'));
      expect(r.pushes.last, 'Step 1 done · 1 of 3');
      await r.close();
    });

    test('night shift: the pool refuses, the loop waits until the reset plus a minute, resumes the dead session and sends again', () async {
      final r = _Rig(each: true);
      await r.bridge.start();
      await r.auto.start(budget: 3, nightShift: true);
      await r.fake.writtenLines(1);
      final first = r.fake;
      final resets = r.clock.add(const Duration(minutes: 30));
      await r.refuse(resetsAt: resets);
      await r.endTurn(error: true, text: "You've hit your limit");
      expect(r.auto.on, isTrue);
      expect(r.auto.waitingUntil, isNotNull);
      expect(r.auto.waitingUntil!.difference(resets), const Duration(minutes: 1));
      expect(r.auto.sent, 0, reason: 'the refused send did not run');
      expect(r.timers.single.duration.inMinutes, 31);
      expect(autopilotLine(r.auto.state, now: r.clock), 'Autopilot · waiting for the pool · 0:31:00');
      expect(r.notes.last, startsWith('Autopilot · waiting for the pool until '));
      // The process dies meanwhile: expected, nothing stops.
      first.exit(1);
      await pumpEventQueue();
      expect(r.bridge.state, BridgeState.failed);
      expect(r.auto.on, isTrue);
      expect(r.auto.waitingUntil, isNotNull);
      // The reset: resumed on the same id, and /step a goes again.
      r.clock = r.auto.waitingUntil!;
      r.timers.single.fire();
      await pumpEventQueue();
      for (var i = 0; i < 50 && r.spawned.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(r.spawned.length, 2);
      expect(r.spawned[1].startedWith, containsAllInOrder(['--resume', r.bridge.sessionId]));
      await r.fake.writtenLines(1);
      expect(r.fake.written.single, contains('"/step a"'));
      expect(r.auto.waitingUntil, isNull);
      expect(r.auto.sent, 1);
      expect(r.notes, contains('Autopilot · the pool reset — carrying on'));
      expect(r.pushes, ['Started · budget 3 · night shift on'], reason: 'the wait is a line on the Deck, not a push');
      await r.close();
    });

    test('night shift off: the pool refuses and the loop stops, saying until when', () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 3, nightShift: false);
      await r.fake.writtenLines(1);
      final resets = r.clock.add(const Duration(minutes: 30));
      await r.refuse(resetsAt: resets);
      await r.endTurn(error: true, text: "You've hit your limit");
      expect(r.auto.on, isFalse);
      expect(r.auto.stoppedFor, 'the pool is empty until ${hmLabel(resets)}');
      expect(r.pushes.last, 'Stopped · the pool is empty until ${hmLabel(resets)}');
      expect(r.timers, isEmpty);
      await r.close();
    });

    test('a pool already dry when the next step is due: the same wait', () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 3, nightShift: true);
      await r.fake.writtenLines(1);
      r.flip('a');
      // The event lands before the result, and the reset is still ahead.
      await r.refuse(resetsAt: r.clock.add(const Duration(minutes: 5)));
      await r.endTurn();
      expect(r.auto.on, isTrue);
      expect(r.auto.waitingUntil, isNotNull);
      expect(r.auto.sent, 0);
      expect(r.auto.done, 0, reason: 'a refused turn counts nothing');
      await r.close();
    });

    test('INTERRUPT ends the loop; so does Stop; the toggle reads off afterwards', () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 3);
      await r.fake.writtenLines(1);
      expect(r.bridge.interrupt(), isTrue);
      await r.endTurn();
      expect(r.auto.on, isFalse);
      expect(r.auto.stoppedFor, 'interrupted');
      expect(r.pushes.last, 'Stopped · interrupted');
      expect(autopilotPill(r.auto.state), 'AUTOPILOT · OFF');

      r.pushes.clear();
      await r.auto.start(budget: 3);
      await r.fake.writtenLines(2);
      expect(r.auto.on, isTrue);
      await r.bridge.stop();
      await pumpEventQueue();
      expect(r.auto.on, isFalse);
      expect(r.auto.stoppedFor, 'the session stopped');
      await r.close();
    });

    test('stopped by hand: no push, a note, off', () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 3);
      expect(r.auto.stop(by: 'the phone'), 'autopilot stopped · stopped by the phone');
      expect(r.auto.on, isFalse);
      expect(r.pushes, ['Started · budget 3 · night shift off']);
      expect(r.notes.last, 'Autopilot stopped · stopped by the phone');
      expect(r.auto.stop(), 'autopilot is off');
      await r.close();
    });

    test("the human's move stops the loop with the item's name", () async {
      final r = _Rig();
      r.store.writeStep(Step(id: 'a', title: 'A', number: '1', rank: 1, status: StepStatus.active, gates: {'tests': Gate('tests', status: GateStatus.passed)}));
      r.store.writeStep(Step(id: 'b', title: 'B', number: '2', rank: 2, dependsOn: const ['a'], gates: {'tests': Gate('tests')}));
      r.store.writeItem(Item(id: 'iphone', title: 'Register the iPhone', needs: const ['device'], blocks: const ['a']));
      await r.bridge.start();
      await r.auto.start(budget: 3);
      expect(r.auto.on, isFalse);
      expect(r.auto.stoppedFor, 'needs you: Register the iPhone');
      expect(r.pushes, ['Started · budget 3 · night shift off', 'Stopped · needs you: Register the iPhone']);
      expect(r.fake.written, isEmpty);
      await r.close();
    });

    test('started with no session running, it brings one up first — resumed where it can be', () async {
      final r = _Rig(each: true);
      await r.bridge.start();
      await r.bridge.stop();
      expect(r.bridge.previous()?.sessionId, isNotNull);
      await r.auto.start(budget: 1);
      expect(r.spawned.length, 2);
      expect(r.spawned[1].startedWith, contains('--resume'));
      await r.fake.writtenLines(1);
      expect(r.fake.written.single, contains('"/step a"'));
      await r.close();
    });

    test("a /step queued behind the person's own turn waits for it, and that turn's result is not the loop's", () async {
      final r = _Rig();
      await r.bridge.start();
      r.bridge.send('hello');
      await r.fake.writtenLines(1);
      expect(await r.auto.start(budget: 2), 'queued /step a · 1 of 2');
      expect(r.fake.written.length, 1);
      await r.endTurn();
      expect(r.auto.on, isTrue);
      expect(r.auto.sent, 1, reason: "hello's result is not the loop's");
      expect(r.pushes, ['Started · budget 2 · night shift off']);
      await r.fake.writtenLines(2);
      expect(r.fake.written[1], contains('"/step a"'), reason: 'released when the turn ended');
      r.flip('a');
      await r.endTurn();
      expect(r.auto.done, 1);
      await r.clearTurn(3);
      await r.fake.writtenLines(4);
      expect(r.fake.written[3], contains('"/step b"'));
      await r.close();
    });

    test('a folder without the /step command stops the loop at once, not at the budget', () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 5);
      await r.fake.writtenLines(1);
      await r.endTurn(text: 'Unknown command: /step');
      expect(r.auto.on, isFalse);
      expect(r.auto.stoppedFor, startsWith('/step is not a command in this folder'));
      expect(r.fake.written.length, 1);
      await r.close();
    });

    test("a dial moved mid-turn: the switch and the loop's next /step both reach the CLI at the turn's end", () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 3);
      await r.fake.writtenLines(1);
      expect(r.bridge.setOptions(mode: 'bypassPermissions'), isTrue);
      expect(r.bridge.modePending, isTrue, reason: 'a turn runs; the switch waits');
      r.flip('a');
      await r.endTurn();
      await r.fake.writtenLines(3);
      expect(r.fake.written.length, 3, reason: 'set_permission_mode, then the clear');
      expect(r.fake.written[1], contains('set_permission_mode'));
      await r.clearTurn(3);
      await r.fake.writtenLines(4);
      expect(r.fake.written[3], contains('"/step b"'));
      expect(r.auto.sent, 2);
      expect(r.bridge.state, BridgeState.busy);
      await r.close();
    });

    test('a /clear that ends in an error stops the loop; with clearing off the steps follow each other', () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 3);
      await r.fake.writtenLines(1);
      r.flip('a');
      await r.endTurn();
      await r.fake.writtenLines(2);
      expect(r.fake.written[1], contains('"/clear"'));
      await r.endTurn(error: true, text: 'no');
      expect(r.auto.on, isFalse);
      expect(r.auto.stoppedFor, '/clear failed — no');
      await r.close();

      final q = _Rig();
      final plain = Autopilot(bridge: q.bridge, loadPlan: () => q.store.load(), clearBetweenSteps: false);
      q.bridge.addListener(plain.check);
      await q.bridge.start();
      await plain.start(budget: 2);
      await q.fake.writtenLines(1);
      q.flip('a');
      await q.endTurn();
      await q.fake.writtenLines(2);
      expect(q.fake.written[1], contains('"/step b"'));
      plain.dispose();
      await q.close();
    });

    test('a turn that ends in an error stops the loop', () async {
      final r = _Rig();
      await r.bridge.start();
      await r.auto.start(budget: 3);
      await r.fake.writtenLines(1);
      await r.endTurn(error: true, text: 'Something broke');
      expect(r.auto.on, isFalse);
      expect(r.auto.stoppedFor, 'the turn ended in an error — Something broke');
      await r.close();
    });
  });

  group('the Deck', () {
    for (final scale in [1.0, 2.0, 3.12]) {
      testWidgets('at ${scale}x: the line, the pill, the sheet, the countdown, no overflow', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final calls = <String>[];
        Future<String?> onAuto({required bool on, int? budget, bool? nightShift}) async {
          calls.add('$on/$budget/$nightShift');
          return null;
        }

        // On: the line under the facts; the pill in the fold stops it.
        const on = AutopilotState(on: true, budget: 3, sent: 1, step: 'blobs', stepNumber: '10');
        final row = DeckMessage(id: 'm1', role: DeckRole.user, text: '/step blobs', at: DateTime(2026, 9, 6), by: 'autopilot');
        await tester.pumpWidget(_app(_deck(auto: on, onAutopilot: onAuto, messages: [row]), scale: scale));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('AUTOPILOT · STEP 10 · 1 OF 3'), findsOneWidget);
        expect(find.text('AUTOPILOT'), findsOneWidget, reason: "the loop's row is labelled");
        await tester.tap(find.byTooltip('Show session controls'));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: 'the fold open');
        await tester.ensureVisible(find.text('AUTOPILOT · 1 OF 3'));
        await tester.pump();
        await tester.tap(find.text('AUTOPILOT · 1 OF 3'));
        await _settle(tester);
        expect(calls, ['false/null/null']);

        // Waiting on an ask: the line says so.
        await tester.pumpWidget(_app(_deck(auto: on, onAutopilot: onAuto, state: BridgeState.waiting), scale: scale));
        await _settle(tester);
        expect(find.text('AUTOPILOT · STEP 10 · 1 OF 3 · NEEDS YOU'), findsOneWidget);

        // Waiting for the pool: the countdown ticks.
        final until = DateTime.now().add(const Duration(minutes: 42, seconds: 10));
        await tester.pumpWidget(_app(_deck(auto: AutopilotState(on: true, budget: 3, sent: 0, nightShift: true, step: 'blobs', stepNumber: '10', waitingUntil: until), onAutopilot: onAuto), scale: scale));
        await _settle(tester);
        expect(find.textContaining('AUTOPILOT · WAITING FOR THE POOL · 0:42:'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(find.textContaining('AUTOPILOT · WAITING FOR THE POOL · 0:42:0'), findsOneWidget, reason: 'two seconds on');
        expect(tester.takeException(), isNull);

        // Off, stopped: the reason beside the pill; a tap opens the sheet; START confirms.
        calls.clear();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(_app(_deck(auto: const AutopilotState(stoppedFor: 'budget reached'), onAutopilot: onAuto, state: BridgeState.ready), scale: scale));
        await _settle(tester);
        expect(find.textContaining('AUTOPILOT · '), findsNothing, reason: 'no line while off');
        await tester.tap(find.byTooltip('Show session controls'));
        await _settle(tester);
        await tester.ensureVisible(find.text('AUTOPILOT · OFF'));
        await tester.pump();
        expect(find.text('stopped · budget reached'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('AUTOPILOT · OFF'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('AUTOPILOT'), findsOneWidget, reason: 'the sheet');
        expect(find.text('START · 3 STEPS'), findsOneWidget);
        await tester.drag(find.byType(Slider).last, const Offset(60, 0));
        await tester.pump();
        expect(find.text('START · 3 STEPS'), findsNothing, reason: 'the slider moved the budget');
        await tester.tap(find.byType(Switch));
        await tester.pump();
        expect(find.textContaining('wait for its reset'), findsOneWidget);
        final label = tester.widget<Text>(find.textContaining('START · ')).data!;
        final budget = int.parse(label.split(' ')[2]);
        await tester.ensureVisible(find.textContaining('START · '));
        await tester.tap(find.textContaining('START · '));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(calls, ['true/$budget/true']);
        expect(find.text('START · $budget STEP${budget == 1 ? '' : 'S'}'), findsNothing, reason: 'the sheet closed');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('folded by a drag, the line stays on the row', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rows = [for (var i = 0; i < 40; i++) DeckMessage(id: 'm$i', role: i.isEven ? DeckRole.user : DeckRole.assistant, text: 'Row $i is here to give the list some length.', at: DateTime(2026, 9, 6))];
      const on = AutopilotState(on: true, budget: 3, sent: 2, step: 'blobs', stepNumber: '10');
      await tester.pumpWidget(_app(_deck(auto: on, onAutopilot: ({required on, budget, nightShift}) async => null, messages: rows, foldOnScroll: true), scale: 1.0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('NAHMATIK · WORKING'), findsOneWidget, reason: 'folded');
      expect(find.text('AUTOPILOT · STEP 10 · 2 OF 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('the phone reads the loop off the session and sends the toggle as a command', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('projects').doc('demo').set({
      'session': {'mode': 'bridge', 'state': 'busy', 'autopilot': const AutopilotState(on: true, budget: 4, sent: 2, done: 1, nightShift: true, step: 'blobs', stepNumber: '10').toMap()},
    });
    final d = RemoteDeck(db, 'demo')..start();
    await pumpEventQueue();
    expect(d.autopilot.on, isTrue);
    expect(d.autopilot.budget, 4);
    expect(d.autopilot.sent, 2);
    expect(d.autopilot.nightShift, isTrue);
    expect(autopilotLine(d.autopilot), 'Autopilot · step 10 · 2 of 4');
    await d.setAutopilot(on: true, budget: 5, nightShift: false);
    await d.setAutopilot(on: false);
    final cmds = await db.collection('projects').doc('demo').collection('commands').orderBy('sentAt').get();
    expect(cmds.docs.length, 2);
    expect(cmds.docs[0].data()['type'], 'autopilot');
    expect(cmds.docs[0].data()['on'], isTrue);
    expect(cmds.docs[0].data()['budget'], 5);
    expect(cmds.docs[0].data()['nightShift'], isFalse);
    expect(cmds.docs[0].data()['from'], 'phone');
    expect(cmds.docs[1].data()['on'], isFalse);
    expect(cmds.docs[1].data().containsKey('budget'), isFalse);
    d.dispose();
  });
}
