// The relay round-trip with no backend: host publishes plan/ → the remote
// rebuilds the same plan → the phone sends a batch → the host applies it to
// disk and stamps the batch → the mirror reflects the change.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
