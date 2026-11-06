// The Studio's reading of the autopilot folder: every line shape below is
// copied from a real `sivas-autopilot` snapshot (2026-11-06), so a change in
// how run-lane.sh or the reviewer writes shows up here first.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/studio/studio_data.dart';
import 'package:kit_app/src/studio/studio_source.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LaneStatus', () {
    test('running: step, engine, no tail hint', () {
      final s = LaneStatus.parse('2026-11-06 22:17:50  running step 1100 (claude claude-opus-5-5/high)  (tail -f /Users/ren/StudioProjects/sivas-autopilot/lane-a/logs/step-1100.log)\n');
      expect(s.state, LaneState.running);
      expect(s.step, '1100');
      expect(s.engineLabel, 'claude claude-opus-5-5/high');
      expect(s.machine, isNull);
      expect(s.text, 'running step 1100');
      expect(s.at, DateTime(2026, 11, 6, 22, 17, 50));
    });

    test('running on another machine names it', () {
      final s = LaneStatus.parse('2026-11-07 09:00:00  running step 3 (claude claude-opus-5-5/high, Mac mini)  (tail -f /x/step-3.log)');
      expect(s.machine, 'Mac mini');
      expect(s.engineLabel, 'claude claude-opus-5-5/high');
    });

    test('waiting for mail drops the inbox path, keeps the why', () {
      final s = LaneStatus.parse('2026-11-04 21:27:28  waiting: new mail in /Users/ren/StudioProjects/sivas-autopilot/mail/to-b (no unchecked steps; the only mail was the naming FYI, now read)');
      expect(s.state, LaneState.waiting);
      expect(s.text, 'waiting for new mail (no unchecked steps; the only mail was the naming FYI, now read)');
    });

    test('waiting for Unity, paused, not started, empty', () {
      expect(LaneStatus.parse('2026-11-07 09:00:00  waiting for Unity on the Mac mini to be ready').state, LaneState.waiting);
      expect(LaneStatus.parse('2026-11-07 09:00:00  paused, waiting for the user (/autopilot-continue)').state, LaneState.paused);
      expect(LaneStatus.parse('2026-11-05 22:44:23  not started: scaffolding only; waiting for the user\'s first order (no steps yet)').state, LaneState.notStarted);
      expect(LaneStatus.parse('').state, LaneState.unknown);
    });
  });

  group('LaneEvent', () {
    test('a DONE verdict carries its step and summary', () {
      final e = LaneEvent.parse('2026-11-06 22:17:50  step 1099  DONE ROOMLAB-1B: Sivas/Room Lab window builds one room');
      expect(e.kind, EventKind.done);
      expect(e.step, '1099');
      expect(e.summary, 'ROOMLAB-1B: Sivas/Room Lab window builds one room');
      expect(e.isVerdict, isTrue);
    });

    test('every kind the loop writes', () {
      EventKind k(String l) => LaneEvent.parse('2026-11-06 22:17:50  $l').kind;
      expect(k('step 1100 started (claude claude-opus-5-5/high)'), EventKind.started);
      expect(k('step 677  WAIT-FOR-MAIL no unchecked steps'), EventKind.waitForMail);
      expect(k('step 12  WAIT-FOR docs/x.md'), EventKind.waitFor);
      expect(k('step 12  FAILED no verdict line'), EventKind.failed);
      expect(k('step 12  PLAN-COMPLETE'), EventKind.planComplete);
      expect(k('waiting: new mail in /x/mail/to-c (why)'), EventKind.waiting);
      expect(k('wait over: new mail in /x/mail/to-c'), EventKind.waitOver);
      expect(k('push: pushed 11561eb8a'), EventKind.push);
      expect(k('paused'), EventKind.paused);
      expect(k('continued'), EventKind.continued);
      expect(k('stopped (STOP flag)'), EventKind.stopped);
      expect(k('loop started (pid 123)'), EventKind.loopStarted);
      expect(k('delivered lane C mail x.md'), EventKind.mail);
      expect(k('opened Unity on the PC (scheduled task SivasOpenUnity)'), EventKind.unity);
    });
  });

  group('Lane', () {
    final history = parseHistory('''
2026-11-06 21:30:08  step 1098  DONE ROOMLAB-1A: force hooks
2026-11-06 21:30:08  step 1099 started (claude claude-opus-5-5/high)
2026-11-06 22:17:50  step 1099  DONE ROOMLAB-1B: the window
2026-11-06 22:17:50  step 1100 started (claude claude-opus-5-5/high)
''');
    final lane = Lane(
      id: 'a',
      status: LaneStatus.parse('2026-11-06 22:17:50  running step 1100 (claude claude-opus-5-5/high)'),
      history: history,
      engine: 'claude',
      model: 'claude-opus-5-5',
      effort: 'high',
    );

    test('last done, done today, engine line, machine default', () {
      expect(lane.name, 'Lane A');
      expect(lane.lastDone!.step, '1099');
      expect(lane.doneOn(DateTime(2026, 11, 6)), 2);
      expect(lane.doneOn(DateTime(2026, 11, 7)), 0);
      expect(lane.engineLine, 'claude · opus-5-5 · high');
      expect(lane.machine, 'MacBook');
      expect(lane.failStreak, 0);
    });

    test('stale only past the 4-hour step timeout', () {
      expect(lane.staleAt(DateTime(2026, 11, 6, 23, 0)), isFalse);
      expect(lane.staleAt(DateTime(2026, 11, 7, 3, 0)), isTrue);
    });

    test('a fail streak counts trailing FAILED verdicts', () {
      final l = Lane(id: 'c', status: LaneStatus.parse(''), history: parseHistory('''
2026-11-01 10:00:00  step 1  DONE ok
2026-11-01 11:00:00  step 2  FAILED no verdict
2026-11-01 11:00:01  push: pushed abc
2026-11-01 12:00:00  step 2  FAILED Editor did not answer
'''));
      expect(l.failStreak, 2);
    });

    test('the machine comes from run-lane.sh, and a status naming one wins', () {
      final hosts = laneHosts('''
case "\$LANE" in
  a) REPO=/Users/ren/StudioProjects/sivas-the-game ;;
  c) REPO="\$CTL"; WHOST=sivas-win; WCTL=C:/dev/autopilot; WBRANCH=codex/lane-c ;;
  # Lane D works on the user's Mac mini
  d) REPO="\$CTL"; WHOST=mac-mini; WCTL=/Users/grkmaltunbs/autopilot
esac
''');
      expect(hosts, {'c': 'Windows PC', 'd': 'Mac mini'});
      expect(Lane(id: 'd', status: LaneStatus.parse(''), history: const [], hostMachine: hosts['d']).machine, 'Mac mini');
      expect(Lane(id: 'a', status: LaneStatus.parse(''), history: const [], hostMachine: hosts['a']).machine, 'MacBook');
      expect(Lane(id: 'x', status: LaneStatus.parse('2026-11-07 09:00:00  running step 3 (claude m/high, Windows PC)'), history: const []).machine, 'Windows PC');
    });
  });

  group('Mail', () {
    test('title from the heading, stamp from the file name', () {
      final m = Mail.parse('20261106-2230-roomlab-1b-ready.md', '# Lane A run 1099: Room Lab 1B is in\n\nFYI…');
      expect(m.title, 'Lane A run 1099: Room Lab 1B is in');
      expect(m.at, DateTime(2026, 11, 6, 22, 30));
    });

    test('no heading: the slug, readable', () {
      final m = Mail.parse('from-reviewer-20261106-204702-held-items.md', 'plain text');
      expect(m.title, 'held items');
      expect(m.at, DateTime(2026, 11, 6, 20, 47, 2));
    });
  });

  test('open issues skip closed lines and find the lane in both layouts', () {
    final issues = OpenIssue.parseAll('''
# Open issues

- A · 2026-09-27 02:26 · faceted rock · closed 2026-09-27 03:44: step 008
- 2026-11-05 21:27 · F/A · BOARD 21:18 Fırat M3.4-0
- A ROOM-LAB (the user 11-06): phases 1-3 ordered
- MacBook EditorPref Sivas.WholeMapBuild = true
''');
    expect(issues.map((i) => i.lane), ['F/A', 'A', null]);
  });

  group('ReviewSection', () {
    const digest = '''
# While you were away

## 2026-11-06 22:37 — user away (afk mode, reviews every 20 min)

**Lanes now**
- **A (MacBook):** on the Room Lab.

**Waiting for the user**
- Room Lab 1B can already be tried.
- YARD-LINE-ORDER (I recommend yes).
  continued on a second line.

### 22:40 review
- **Lane A:** Room Lab 1A and 1B are in.
''';

    test('sections, the waiting list and the review notes', () {
      final s = ReviewSection.parseAll(digest);
      expect(s, hasLength(1));
      expect(s.single.at, DateTime(2026, 11, 6, 22, 37));
      expect(s.single.title, 'user away (afk mode, reviews every 20 min)');
      expect(s.single.bulletsUnder('Waiting for the user'), ['Room Lab 1B can already be tried.', 'YARD-LINE-ORDER (I recommend yes). continued on a second line.']);
      expect(s.single.subsections.single.title, '22:40 review');
    });
  });

  test('DocPart cuts at ## outside code fences', () {
    final parts = DocPart.split('# Plan\nintro\n## One\na\n```\n## not a heading\n```\n## Two\nb\n');
    expect(parts.map((e) => e.title), ['Overview', 'One', 'Two']);
    expect(parts[1].body, contains('## not a heading'));
  });

  group('StudioSource', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('studio_');
      void w(String rel, String text) => (File(p.join(dir.path, rel))..createSync(recursive: true)).writeAsStringSync(text);
      w('lane-a/status', '2026-11-06 22:17:50  running step 1100 (claude claude-opus-5-5/high)  (tail -f /x)\n');
      w('lane-a/history.log', '2026-11-06 22:17:50  step 1099  DONE the window\n');
      w('lane-a/engine', 'claude\n');
      w('lane-a/model', 'claude-opus-5-5\n');
      w('lane-a/effort', 'high\n');
      w('lane-a/logs/step-1099.log', 'line 1\nline 2\nline 3\n');
      w('lane-b/status', '2026-11-04 21:27:28  waiting: new mail in /x/mail/to-b (nothing)\n');
      w('mail/to-b/20261107-0900-hello.md', '# Hello\n');
      w('mail/to-user/20261106-2135-plan.md', '# Older\n');
      w('mail/to-user/20261106-2230-ready.md', '# Newer\n');
      w('mail/to-user/read/20261101-0000-old.md', '# Read\n');
      w('control/PAUSE-b', '');
      w('review/digest.md', '## 2026-11-06 22:37 — away\n\n**Waiting for the user**\n- Try the Room Lab.\n');
      w('review/afk-decisions.md', '## 2026-11-06 20:00 — first\nx\n## 2026-11-06 22:40 — second\ny\n');
      w('review/open-issues.md', '- A one\n- B two · closed 2026-11-01 10:00\n');
      w('review/mode', 'afk\n');
      w('review/last-review', '2026-11-06 22:40:01\n');
      w('lane-x-not-a-lane/status', 'ignored');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('reads lanes, flags, mail newest first, the digest and decisions newest first', () async {
      final s = await StudioSource(autopilotDir: dir.path, now: () => DateTime(2026, 11, 6, 23)).read();
      expect(s.lanes.map((l) => l.id), ['a', 'b']);
      expect(s.lanes[0].status.step, '1100');
      expect(s.lanes[0].engineLine, 'claude · opus-5-5 · high');
      expect(s.lanes[1].paused, isTrue);
      expect(s.lanes[1].inbox, 1);
      expect(s.userMail.map((m) => m.title), ['Newer', 'Older']);
      expect(s.waitingForUser, ['Try the Room Lab.']);
      expect(s.decisions.map((d) => d.title), ['second', 'first']);
      expect(s.openIssues.map((i) => i.text), ['A one']);
      expect(s.mode, 'afk');
      expect(s.lastReview, DateTime(2026, 11, 6, 22, 40, 1));
    });

    test('a step log, plain or gzipped, tail only', () {
      final src = StudioSource(autopilotDir: dir.path);
      expect(src.stepLog('a', '1099'), 'line 1\nline 2\nline 3\n');
      expect(src.stepLog('a', '1099', lines: 2), 'line 3\n');
      File(p.join(dir.path, 'lane-a/logs/step-1098.log.gz')).writeAsBytesSync(gzip.encode(utf8.encode('zipped ü\n')));
      expect(src.stepLog('a', '1098'), 'zipped ü\n');
      expect(src.stepLog('a', '1097'), '');
    });

    test('an empty steps.md (a failed git show) falls back to the lane\'s repo copy', () async {
      void w(String rel, String text) => (File(p.join(dir.path, rel))..createSync(recursive: true)).writeAsStringSync(text);
      final game = Directory.systemTemp.createTempSync('studio_game_');
      addTearDown(() => game.deleteSync(recursive: true));
      w('lane-a/steps.md', '');
      w('prompts/lane-a.md', 'list: `production/autopilot/lane-a-steps.md`');
      (File(p.join(game.path, 'production/autopilot/lane-a-steps.md'))..createSync(recursive: true)).writeAsStringSync('- [x] X1: one\n- [ ] X2: two\n');
      final s = await StudioSource(autopilotDir: dir.path, gameDir: game.path).read();
      expect(s.tracks['a']!.source, p.join(game.path, 'production/autopilot/lane-a-steps.md'));
      expect(s.tracks['a']!.total, 2);
    });

    test('a missing folder is an error, not a crash', () async {
      final src = StudioSource(autopilotDir: p.join(dir.path, 'nope'));
      await src.refresh();
      expect(src.error, contains('No folder'));
    });
  });
}
