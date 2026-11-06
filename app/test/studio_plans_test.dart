// The lane step lists and the roadmap, as the real files of 2026-11-06
// write them: lane A's `- [x] ID (run N): …`, lane C's `- [x] step N: …`,
// held items left unchecked above the one being worked on, and the
// production plan's ladder, Open work and Done tables.
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/studio/studio_data.dart';
import 'package:kit_app/src/studio/studio_plans.dart';

void main() {
  const laneA = '''
# Lane A autopilot: step list

Standing rules, prose, not items.

## The procedural hangar (G-A · HANGAR-GEN)

- [x] CARGO-DECK-FLOOR (run 1052): case (a), every LOD keeps its plate
  - a sub-bullet that belongs to it
- [ ] GUEST-RIDE-HOLD — run 1075: stops at the guest's `Begin`; HOLD until the reviewer's ack
- [x] ROOMLAB-1A (run 1098): dev-only force hooks
- [x] ROOMLAB-1B (run 1099): the **Room Lab** window
- [ ] ROOMLAB-1C: Play in that room
- [ ] ROOMLAB-1D: feature tests onto the Lab

## Later

- [ ] HOLD-EXTRACT: waits on Fırat
''';

  test('items, sections, runs, sub-bullets and held items', () {
    final items = parseStepList(laneA);
    expect(items.map((i) => i.id), ['CARGO-DECK-FLOOR', 'GUEST-RIDE-HOLD', 'ROOMLAB-1A', 'ROOMLAB-1B', 'ROOMLAB-1C', 'ROOMLAB-1D', 'HOLD-EXTRACT']);
    expect(items[0].done, isTrue);
    expect(items[0].run, '1052');
    expect(items[0].title, 'case (a), every LOD keeps its plate');
    expect(items[0].text, contains('a sub-bullet'));
    expect(items[0].section, 'The procedural hangar (G-A · HANGAR-GEN)');
    expect(items[3].title, 'the Room Lab window');
    expect(items[1].held, isTrue);
    expect(items[6].held, isTrue);
    expect(items[4].held, isFalse);
    expect(items[6].section, 'Later');
  });

  test('lane C writes "step N:" — the number is the id', () {
    final items = parseStepList('- [x] C01 **Setup — baseline recorded.** [Evidence](x)\n- [x] step 476: lane A 1081 request: copied the log lines\n');
    expect(items[0].id, 'C01');
    expect(items[0].title, 'Setup — baseline recorded.');
    expect(items[1].id, '476');
    expect(items[1].run, '476');
    expect(items[1].title, 'lane A 1081 request: copied the log lines');
    final b = parseStepList('- [x] run 657: door-drop LOD2 fix (lane A mail 06:40)\n').single;
    expect(b.id, '657', reason: 'lane B writes "run N:" the same way');
    expect(b.title, 'door-drop LOD2 fix (lane A mail 06:40)');
  });

  group('LaneTrack', () {
    final items = parseStepList(laneA);
    test('running: the first open item after the last one done, not the held one above', () {
      final t = LaneTrack.from(items, running: true, lastDoneId: 'ROOMLAB-1B');
      expect(t.current!.id, 'ROOMLAB-1C');
      expect(t.done.map((i) => i.id), ['CARGO-DECK-FLOOR', 'ROOMLAB-1A', 'ROOMLAB-1B']);
      expect(t.next.map((i) => i.id), ['GUEST-RIDE-HOLD', 'ROOMLAB-1D', 'HOLD-EXTRACT']);
      expect(t.total, 7);
    });
    test('running, last done unknown: the first open item that is not held', () {
      expect(LaneTrack.from(items, running: true).current!.id, 'ROOMLAB-1C');
    });
    test('waiting: no current item', () {
      final t = LaneTrack.from(items, running: false);
      expect(t.current, isNull);
      expect(t.next, hasLength(4));
    });
  });

  test('leadingId reads the id a DONE verdict starts with', () {
    expect(leadingId('ROOMLAB-1B: Sivas/Room Lab window builds one room'), 'ROOMLAB-1B');
    expect(leadingId('AI-S4c-report: S4 on the PC read'), 'AI-S4c-report');
    expect(leadingId('copied the loot-throw context lines'), isNull);
    expect(leadingId(null), isNull);
  });

  test('run-lane.sh repos and the prompt\'s step list', () {
    final repos = laneRepos('''
case "\$LANE" in
  a) REPO=/Users/ren/StudioProjects/sivas-the-game ;;
  b) REPO=/Users/ren/StudioProjects/sivas-the-game-assets ;;
  c) REPO="\$CTL"; WHOST=sivas-win; WCTL=C:/dev/autopilot; WREPO='C:\\dev\\sivas-habitat'; WBRANCH=codex/lane-c ;;
  d) REPO="\$CTL"; WHOST=mac-mini; WCTL=/Users/grkmaltunbs/autopilot; WREPO=/Users/grkmaltunbs/StudioProjects/sivas-the-game
     WBRANCH=claude/editor-lane-d; WUNITY=/Applications/Unity/Hub/Editor/6000.4.0f1/Unity.app ;;
esac
''');
    expect(repos['a'], ['/Users/ren/StudioProjects/sivas-the-game']);
    expect(repos['c'], ['C:\\dev\\sivas-habitat']);
    expect(repos['d'], ['/Users/grkmaltunbs/StudioProjects/sivas-the-game']);
    expect(stepsFileIn('Your list is `production/autopilot/lane-a-steps.md`; decisions go in lane-a-decisions.md.'), 'production/autopilot/lane-a-steps.md');
  });

  test('the roadmap: ladder names, open and done rows under their milestones', () {
    final ms = parseRoadmap('''
## Milestone ladder

| # | Milestone (Notion name) | Goal — "done means" | Exit criteria | Status 2026-10-20 |
|---|---|---|---|---|
| M2 | **Pre-alpha** (v0.3) | **One full run** | A new player completes | Closed 2026-10-20 |
| M3 | **Alpha** (v0.4) | **Run engine complete** | Feature freeze | In progress |
| R | **Release** (v1.0) | **Live on Steam** | Release button | Not started |

## Open work

### M3 — Alpha: Run Engine Complete (3 open of 4)

| ID | Task | Size | Owner | Status | Summary |
|---|---|---|---|---|---|
| M3.17 | Loading and frame-time optimisation | L | Dev | In progress — stage 0 built | what is left |
| M3.1 | Map-set ladder *(was Environment ladder; code keeps `X`)* | M | Dev | **In progress — stage A ON DEVELOP** | x |
| M3.2 | Refinery and Habitat themes | L | Dev+Artist | Not started | y |
| M3.45 | Something | S | Dev | Built 2026-10-30 and on develop | z |

### Release — Live on Steam (1 open of 1)

| ID | Task | Size | Owner | Status | Summary |
|---|---|---|---|---|---|
| SR.11 | Steam Input & Deck pass | M | Dev | Not started | Deck Playable |

## Done

### M3 — Alpha (1 of 4)

| ID | Task | Size | Owner | Done | Summary |
|---|---|---|---|---|---|
| M3.6 | Mods & rarity | M | Dev | 2026-10-15 | A weapon copy carries a mod set |
''');
    expect(ms.map((m) => m.key), ['M2', 'M3', 'R']);
    final m3 = ms[1];
    expect(m3.name, 'Alpha');
    expect(m3.goal, 'Run engine complete');
    expect(m3.items.map((i) => i.id), ['M3.17', 'M3.1', 'M3.2', 'M3.45', 'M3.6']);
    expect(m3.items.map((i) => i.status), [ItemStatus.inProgress, ItemStatus.inProgress, ItemStatus.notStarted, ItemStatus.built, ItemStatus.done]);
    expect(m3.items[1].task, 'Map-set ladder');
    expect(m3.items[4].statusText, '2026-10-15');
    expect(m3.doneCount, 1);
    expect(m3.inProgressCount, 2);
    expect(ms[0].items, isEmpty);
    expect(ms[2].items.single.id, 'SR.11');
  });
}
