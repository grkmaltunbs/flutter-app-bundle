// The relay round-trip with no backend: host publishes plan/ → the remote
// rebuilds the same plan → the phone sends a batch → the host applies it to
// disk and stamps the batch → the mirror reflects the change.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/bridge_session.dart' show BridgeState;
import 'package:kit_app/src/plan_source.dart';
import 'package:kit_app/src/relay.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late PlanStore store;
  late FakeFirebaseFirestore db;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kit_relay_');
    store = PlanStore(p.join(tmp.path, 'plan'));
    store.writeManifest(Manifest(projectName: 'Demo', releaseStep: 'b'));
    store.writeStep(Step(id: 'a', title: 'A', rank: 1, status: StepStatus.active, gates: {'tests': Gate('tests', status: GateStatus.passed)}));
    store.writeStep(Step(id: 'b', title: 'B', rank: 2, dependsOn: ['a']));
    store.writeItem(Item(id: 'i1', title: 'Tick me', needs: ['device'], blocks: ['a'], runbook: const [RunbookLine(doText: 'Tap it', expect: 'It ticks')]));
    db = FakeFirebaseFirestore();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('publish writes every document once, then only what changed', () async {
    final pub = RelayPublisher(db, 'demo', dir: tmp.path, machine: 'test');
    expect(await pub.publish(store.load()), 3);
    expect(await pub.publish(store.load()), 0);
    store.patch(store.itemPath('i1'), ['title'], 'Tick me now');
    expect(await pub.publish(store.load()), 1);
    File(store.stepPath('b')).deleteSync();
    expect(await pub.publish(store.load()), 1, reason: 'a removed file is a deleted document');
    final steps = await db.collection('projects').doc('demo').collection('steps').get();
    expect(steps.docs.map((d) => d.id), ['a']);
    final proj = await db.collection('projects').doc('demo').get();
    expect(proj.data()!['name'], 'Demo');
    expect((proj.data()!['counts'] as Map)['open'], 1);

    // A second host process seeds from what is there and writes nothing.
    final pub2 = RelayPublisher(db, 'demo', dir: tmp.path, machine: 'test');
    expect(await pub2.publish(store.load()), 0);
  });

  test('the remote rebuilds the plan and derives the same states', () async {
    await RelayPublisher(db, 'demo', dir: tmp.path, machine: 'test').publish(store.load());
    final remote = RemotePlanSource(db, 'demo')..start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final plan = remote.plan!;
    expect(plan.steps.map((s) => s.id), ['a', 'b']);
    expect(plan.manifest.releaseStep, 'b');
    expect(plan.item('i1')!.runbook.single.expect, 'It ticks');
    final g = Graph(plan);
    expect(g.view(plan.step('a')!).state, StepState.codeComplete);
    expect(g.view(plan.step('b')!).state, StepState.blocked);
    expect(g.decisiveItemIds(), {'i1'});
    remote.dispose();
  });

  test('a batch from the phone lands on disk once and is stamped', () async {
    final pub = RelayPublisher(db, 'demo', dir: tmp.path, machine: 'test');
    await pub.publish(store.load());
    var applications = 0;
    final listener = InboxListener(db, 'demo', apply: (batch) async {
      applications++;
      final r = applyInbox(store, batch, today: '2026-08-28');
      await pub.publish(store.load());
      return r;
    })..start();
    await InboxSender(db, 'demo').send({
      'sentAt': '2026-08-28T09:00:00Z',
      'entries': [
        {'kind': 'item', 'id': 'i1', 'action': 'done', 'note': 'from the phone'},
        {'kind': 'step', 'id': 'b', 'note': 'go faster'},
      ],
    }, from: 'phone');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(applications, 1);
    final i1 = store.load().item('i1')!;
    expect(i1.status, ItemStatus.done);
    expect(i1.note, contains('from the phone'));
    expect(store.load().step('b')!.history.single.note, 'go faster');
    final inbox = await db.collection('projects').doc('demo').collection('inbox').get();
    expect(inbox.docs.single.data()['appliedAt'], isNotNull);
    expect(inbox.docs.single.data()['applied'], '2 applied, 0 skipped.');
    expect(inbox.docs.single.data()['lines'], contains('a has nothing left in the way'));
    final mirrored = await db.collection('projects').doc('demo').collection('items').doc('i1').get();
    expect(mirrored.data()!['status'], 'done');
    listener.dispose();
  });

  test('the transcript is mirrored row by row, coalesced, and the phone rebuilds it with its own echo', () async {
    final pub = RelayPublisher(db, 'demo', dir: tmp.path, machine: 'test');
    await pub.publish(store.load());
    final t = Transcript()..sessionId = 'sess-1';
    t.addUser('/plan-status');
    t.apply(const TextDeltaEvent('Step 31 '));
    pub.publishTranscript(t);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final chat = db.collection('projects').doc('demo').collection('chat');
    var docs = await chat.get();
    expect(docs.docs.length, 2, reason: 'the first change of a window flushes at once');
    expect(docs.docs.map((d) => d.data()['sessionId']).toSet(), {'sess-1'});

    // Inside the window: words stream in, nothing is written yet.
    t.apply(const TextDeltaEvent('is ready.'));
    pub.publishTranscript(t);
    t.apply(const AssistantEvent([ContentBlock.text('Step 31 is ready.')]));
    pub.publishTranscript(t);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    docs = await chat.get();
    expect(docs.docs.firstWhere((d) => d.id == 'm00001').data()['text'], 'Step 31 ', reason: 'still the draft');

    // The window ends: the final text lands, once.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    docs = await chat.get();
    expect(docs.docs.firstWhere((d) => d.id == 'm00001').data()['text'], 'Step 31 is ready.');
    expect(docs.docs.firstWhere((d) => d.id == 'm00001').data()['streaming'], isFalse);

    // The phone rebuilds the same rows and shows its own send until the host echoes it.
    final deck = RemoteDeck(db, 'demo')..start();
    await pub.publishSession({'mode': 'bridge', 'state': 'ready', 'sessionId': 'sess-1', 'model': 'claude-fable-5', 'canResume': false, 'pendingAsks': 0});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(deck.messages.map((m) => m.role), [DeckRole.user, DeckRole.assistant]);
    expect(deck.messages.last.text, 'Step 31 is ready.');
    expect(deck.running, isTrue);
    expect(deck.state, BridgeState.ready);
    expect(deck.model, 'claude-fable-5');
    await deck.send('/next');
    expect(deck.view.last.text, '/next');
    expect(deck.view.last.streaming, isTrue, reason: 'an echo, not yet the host\'s copy');
    final cmds = await db.collection('projects').doc('demo').collection('commands').get();
    expect(cmds.docs.single.data()['type'], 'send');
    expect(cmds.docs.single.data()['text'], '/next');
    // The host receives it and mirrors the real row: the echo goes.
    t.addUser('/next');
    pub.publishTranscript(t);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(deck.view.where((m) => m.text == '/next').length, 1);
    expect(deck.view.last.streaming, isFalse);

    // A fresh session on the host: rows the transcript no longer has are deleted.
    t.messages.clear();
    t.addUser('hello again');
    pub.publishTranscript(t);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    docs = await chat.get();
    expect(docs.docs.map((d) => d.data()['text']), ['hello again']);
    deck.dispose();
    pub.dispose();
  });

  test('start, send and stop from the phone are commands the host runs in order', () async {
    final ran = <String>[];
    final listener = CommandListener(db, 'demo', apply: (cmd) async {
      ran.add('${cmd['type']}${cmd['text'] != null ? ':${cmd['text']}' : ''}${cmd['resume'] == true ? ':resume' : ''}');
      return 'ok';
    })..start();
    final deck = RemoteDeck(db, 'demo');
    await deck.startSession();
    await deck.send('/step');
    await deck.startSession(resume: true);
    await deck.stopSession();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(ran, ['start', 'send:/step', 'start:resume', 'stop']);
    listener.dispose();
  });

  test('an ask reaches the phone; its answer comes back as a command; the host stamps both', () async {
    final pub = RelayPublisher(db, 'demo', dir: tmp.path, machine: 'test');
    await pub.publish(store.load());
    final ask = Ask(
      requestId: 'req_1',
      toolName: 'Bash',
      toolUseId: 'toolu_1',
      input: {'command': 'touch /tmp/kit-ask', 'description': 'A marker'},
      at: DateTime.utc(2026, 8, 30, 12),
      description: 'Create a marker file',
      suggestions: [
        {'type': 'addRules', 'rules': [{'toolName': 'Bash', 'ruleContent': 'touch:*'}], 'behavior': 'allow', 'destination': 'localSettings'}
      ],
    );
    await pub.publishAsk(ask);
    final doc = await db.collection('projects').doc('demo').collection('asks').doc('req_1').get();
    expect(doc.data()!['answeredAt'], isNull);
    final back = Ask.fromMap(doc.data()!);
    expect(back.summary, 'touch /tmp/kit-ask');
    expect(back.suggestions.single['behavior'], 'allow');

    final applied = <Map<String, Object?>>[];
    final listener = CommandListener(db, 'demo', apply: (cmd) async {
      applied.add(cmd);
      return 'answered';
    })..start();
    await CommandSender(db, 'demo').answer(ask, AskAnswer.deny('The user declined from the phone.'), from: 'phone');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(applied.single['type'], 'answer');
    expect(applied.single['requestId'], 'req_1');
    expect(applied.single['from'], 'phone');
    expect(applied.single['remember'], isFalse);
    final a = AskAnswer.fromMap(applied.single);
    expect(a.response['behavior'], 'deny');
    expect(a.allowed, isFalse);
    final cmds = await db.collection('projects').doc('demo').collection('commands').get();
    expect(cmds.docs.single.data()['doneAt'], isNotNull);
    expect(cmds.docs.single.data()['result'], 'answered');

    await pub.resolveAsk('req_1', summary: a.summary, by: 'phone');
    final after = await db.collection('projects').doc('demo').collection('asks').doc('req_1').get();
    expect(after.data()!['answeredAt'], isNotNull);
    expect(after.data()!['by'], 'phone');
    expect(after.data()!['answer'], 'Denied');

    // A host that starts later never re-runs a stamped command.
    var again = 0;
    final l2 = CommandListener(db, 'demo', apply: (_) async {
      again++;
      return '';
    })..start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(again, 0);
    listener.dispose();
    l2.dispose();
  });
}
