// The autopilot's decisions, pure: the next move off a plan, the failed
// gates, the state both devices share, and the lines they draw.
import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

Step step(String id, {int rank = 0, String? number, StepStatus status = StepStatus.pending, List<String> deps = const [], bool gatesPassed = false, List<HistoryEntry> history = const []}) => Step(
      id: id,
      title: 'Step $id',
      number: number,
      rank: rank,
      status: status,
      dependsOn: deps,
      history: history,
      gates: {for (final g in const ['analyze', 'tests']) g: Gate(g, status: gatesPassed || status == StepStatus.done ? GateStatus.passed : GateStatus.pending)},
    );

Plan plan(List<Step> steps, [List<Item> items = const []]) => Plan(manifest: Manifest(projectName: 't'), steps: steps, items: items);

void main() {
  group('nextMove', () {
    test('the active step, else the first ready one in rank order', () {
      final p = plan([step('b', rank: 2), step('a', rank: 1), step('c', rank: 3, deps: ['a'])]);
      expect((nextMove(p) as StepMove).step.id, 'a');
      final q = plan([step('a', rank: 1), step('b', rank: 2, status: StepStatus.active)]);
      expect((nextMove(q) as StepMove).step.id, 'b', reason: 'the active step first');
    });

    test('the plan is done', () {
      expect((nextMove(plan([step('a', status: StepStatus.done)])) as StopMove).reason, 'the plan is done');
    });

    test("the human's move: an open item gates every pending step", () {
      final p = plan(
        [step('a', rank: 1, status: StepStatus.active, gatesPassed: true), step('b', rank: 2, deps: ['a'])],
        [Item(id: 'iphone', title: 'Register the iPhone', needs: const ['device'], blocks: const ['a'])],
      );
      expect(Graph(p).nextStep(), isNull, reason: 'a is code complete, b waits on a');
      expect((nextMove(p) as StopMove).reason, 'needs you: Register the iPhone');
      p.items.add(Item(id: 'key', title: 'Make a key', needs: const ['console'], blocks: const ['b']));
      expect((nextMove(p) as StopMove).reason, 'needs you: Register the iPhone (+1)');
    });

    test('blocked by a step that is not in the plan', () {
      final p = plan([step('b', rank: 2, deps: ['ghost'])]);
      expect((nextMove(p) as StopMove).reason, startsWith('nothing is startable'));
    });
  });

  test('failed gates are counted off the history, whatever the gate', () {
    final s = step('a', history: const [HistoryEntry('2026-09-06', 'started'), HistoryEntry('2026-09-06', 'gate tests failed', '3 failing'), HistoryEntry('2026-09-06', 'gate tests passed'), HistoryEntry('2026-09-06', 'gate qa failed')]);
    expect(failedGateCount(s), 2);
    expect(failedGateCount(step('b')), 0);
  });

  test('the countdown and the clock', () {
    expect(countdownLabel(const Duration(minutes: 42, seconds: 10)), '0:42:10');
    expect(countdownLabel(const Duration(hours: 4, minutes: 5, seconds: 9)), '4:05:09');
    expect(countdownLabel(const Duration(seconds: -5)), '0:00:00');
    expect(hmLabel(DateTime(2026, 9, 6, 1, 30)), '01:30');
  });

  test('the state round-trips through the relay and draws its lines', () {
    final until = DateTime.utc(2026, 9, 6, 1, 31);
    final a = AutopilotState(on: true, budget: 5, sent: 2, done: 1, nightShift: true, step: 'blobs', stepNumber: '10', waitingUntil: until, startedAt: DateTime.utc(2026, 9, 6, 0, 0));
    final back = AutopilotState.fromMap(a.toMap());
    expect(back.on, isTrue);
    expect(back.budget, 5);
    expect(back.sent, 2);
    expect(back.done, 1);
    expect(back.nightShift, isTrue);
    expect(back.step, 'blobs');
    expect(back.stepNumber, '10');
    expect(back.waitingUntil, until);
    expect(back.stoppedFor, isNull);
    expect(back.waiting, isTrue);
    expect(autopilotLine(back, now: until.subtract(const Duration(minutes: 42, seconds: 10))), 'Autopilot · waiting for the pool · 0:42:10');
    expect(autopilotPill(back), 'AUTOPILOT · WAITING');

    const running = AutopilotState(on: true, budget: 3, sent: 1, step: 'blobs', stepNumber: '10');
    expect(autopilotLine(running), 'Autopilot · step 10 · 1 of 3');
    expect(autopilotLine(running, needsYou: true), 'Autopilot · step 10 · 1 of 3 · needs you');
    expect(autopilotPill(running), 'AUTOPILOT · 1 OF 3');
    expect(autopilotLine(const AutopilotState(on: true, budget: 2)), 'Autopilot · starting · 0 of 2');

    final off = AutopilotState.fromMap(const AutopilotState(stoppedFor: 'budget reached').toMap());
    expect(autopilotLine(off), isNull);
    expect(autopilotPill(off), 'AUTOPILOT · OFF');
    expect(off.stoppedFor, 'budget reached');
    expect(AutopilotState.fromMap(const {}).budget, 3, reason: 'a relay without the field reads as off, three steps');
  });

  test('/clear: the reset line becomes a note and the context reading drops', () {
    final t = Transcript()..now = () => DateTime.utc(2026, 9, 6);
    t.apply(parseBridgeLine('{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"ok"}],"usage":{"input_tokens":10,"cache_read_input_tokens":30000}}}')!);
    expect(t.contextUsed, 30010);
    final e = parseBridgeLine('{"type":"conversation_reset"}');
    expect(e, isA<ResetEvent>());
    t.apply(e!);
    expect(t.messages.last.text, 'Context cleared.');
    expect(t.contextUsed, 0);
  });

  test('a row keeps who sent it, and the transcript knows whose turn a result ended', () {
    final t = Transcript()..now = () => DateTime.utc(2026, 9, 6);
    final mine = t.addUser('hello');
    expect(DeckMessage.fromMap(mine.toMap()).by, isNull);
    t.apply(const ResultEvent(subtype: 'success', sessionId: 's'));
    expect(t.lastTurnRowId, mine.id);
    final auto = t.addUser('/step blobs', by: 'autopilot');
    expect(DeckMessage.fromMap(auto.toMap()).by, 'autopilot');
    expect(t.lastTurnRowId, mine.id, reason: 'the open turn has not ended');
    // A message queued behind it opens its own turn only when released.
    final queued = t.addUser('and then', queued: true);
    t.apply(const ResultEvent(subtype: 'success', sessionId: 's'));
    expect(t.lastTurnRowId, auto.id);
    t.release(queued);
    t.apply(const ResultEvent(subtype: 'success', sessionId: 's'));
    expect(t.lastTurnRowId, queued.id);
  });
}
