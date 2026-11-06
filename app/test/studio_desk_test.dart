// The step desk: questions about one step go to a second session with the
// step's text, its scoped rows are kept per step on disk, and a change it
// proposes comes back as a card that drops into the draft — on a fake claude.
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/studio/studio_desk.dart';
import 'package:kit_app/src/studio/studio_draft.dart';
import 'package:kit_app/src/studio/studio_thread.dart';
import 'package:kit_app/src/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_claude.dart';

void main() {
  late Directory home, proj, store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    home = Directory.systemTemp.createTempSync('desk_home_');
    proj = Directory.systemTemp.createTempSync('desk_proj_');
    store = Directory.systemTemp.createTempSync('desk_threads_');
  });
  tearDown(() {
    for (final d in [home, proj, store]) {
      d.deleteSync(recursive: true);
    }
  });

  test('a proposal block becomes a draft order; the prose keeps the rest', () {
    final parts = splitAnswer('''
It waits on the pit liner, which lane B has not handed over.

```studio-proposal
kind: link
lane: a
target: ROOMLAB-1D
other: lane-b/COLLAPSE-PIT-LINER
```

```studio-proposal
kind: edit
lane: a
target: ROOMLAB-1D
text: |
  feature tests onto the Lab (after: lane-b/COLLAPSE-PIT-LINER)
    - move the 11 Look tour first
```
''');
    expect(parts.prose, 'It waits on the pit liner, which lane B has not handed over.');
    expect(parts.proposals.map((o) => o.summary), ['Lane A · ROOMLAB-1D waits on lane-b/COLLAPSE-PIT-LINER', 'Lane A · ROOMLAB-1D — new text']);
    expect(parts.proposals[1].text, '- [ ] ROOMLAB-1D: feature tests onto the Lab (after: lane-b/COLLAPSE-PIT-LINER)\n  - move the 11 Look tour first');
    expect(parseProposal('kind: remove\ntarget: M3.2\n')!.onRoadmap, isTrue);
    expect(parseProposal('kind: nonsense\ntarget: X'), isNull);
  });

  test('the desk is told it never edits, and how to propose', () {
    final b = deskBrief(autopilotDir: '/x/auto');
    expect(b, contains('Never edit, create or delete a file'));
    expect(b, contains('```studio-proposal'));
    expect(deskPrompt('why next?', stepAbout('a', 'R1'), '[ ] R1: one'), '[Studio desk · lane step a/R1] why next?\n\n--- as its file holds it ---\n[ ] R1: one\n--- end ---');
  });

  test('a scoped turn is saved to its step\'s thread, and read back after a relaunch', () async {
    final fake = FakeClaude();
    final b = fakeSession(fake, dir: proj.path, home: home.path)
      ..promptForAbout = deskPrompt;
    final threads = StudioThreads(dir: store.path)..watch(b);
    await b.start();
    await pumpEventQueue();
    b.send('why is this next?', about: stepAbout('a', 'R1'));
    await fake.writtenLines(1);
    expect(fake.written.single, contains('[Studio desk · lane step a/R1] why is this next?'));
    fake.emitJson({'type': 'assistant', 'message': {'id': 'm1', 'role': 'assistant', 'content': [{'type': 'text', 'text': 'Because R0 is done.'}]}, 'session_id': b.sessionId});
    fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 5, 'num_turns': 1, 'result': 'Because R0 is done.', 'session_id': b.sessionId});
    await pumpEventQueue();
    expect(threads.questions('step:a/R1'), 1);
    expect(threads.lastAnswer('step:a/R1'), 'Because R0 is done.');
    final again = StudioThreads(dir: store.path)..load();
    expect(again.rows('step:a/R1').map((m) => m.role.name), ['user', 'assistant']);
    await b.stop();
  });

  testWidgets('the thread screen: ask, the answer streams in, a proposal goes into the draft', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeClaude();
    final b = fakeSession(fake, dir: proj.path, home: home.path)..promptForAbout = deskPrompt;
    final threads = StudioThreads(dir: store.path)..watch(b);
    b.describeAbout = (about) => threads.context[threadKeyOf(about)];
    final draft = StudioDraft(persist: false);
    await tester.runAsync(() async {
      await b.start();
      await pumpEventQueue();
    });
    await tester.pumpWidget(MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: StepThreadScreen(title: 'LANE A · R1', subtitle: 'one', about: stepAbout('a', 'R1'), stepText: '[ ] R1: one', desk: b, threads: threads, draft: draft),
    ));
    await tester.pump();
    expect(find.textContaining('No questions yet'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'should this wait on B2?');
    await tester.tap(find.byTooltip('Ask'));
    await tester.pump();
    await tester.runAsync(() => fake.writtenLines(1).timeout(const Duration(seconds: 5)));
    expect(fake.written.single, contains('--- as its file holds it ---\\n[ ] R1: one'), reason: 'the step\'s text rides with the question');
    await tester.runAsync(() async {
      fake.emitJson({'type': 'assistant', 'message': {'id': 'm1', 'role': 'assistant', 'content': [{'type': 'text', 'text': 'Yes.\n\n```studio-proposal\nkind: link\nlane: a\ntarget: R1\nother: lane-b/B2\n```'}]}, 'session_id': b.sessionId});
      fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 5, 'num_turns': 1, 'result': 'Yes.', 'session_id': b.sessionId});
      await pumpEventQueue();
    });
    await tester.pump();
    expect(find.text('should this wait on B2?'), findsOneWidget);
    expect(find.text('PROPOSED CHANGE'), findsOneWidget);
    expect(find.text('Lane A · R1 waits on lane-b/B2'), findsOneWidget);
    await tester.tap(find.text('ADD TO DRAFT'));
    await tester.pump();
    expect(draft.orders.single.summary, 'Lane A · R1 waits on lane-b/B2');
    expect(find.text('IN THE DRAFT'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(b.stop);
  });
}
