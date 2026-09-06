// Try it: the host's build against a scripted flutter, the bucket kept
// to three, the pushes, the switch; the relay; the phone's install; the
// share intake; the card.
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/blobs.dart';
import 'package:kit_app/src/host/builds.dart';
import 'package:kit_app/src/relay.dart';
import 'package:kit_app/src/share_intake.dart';
import 'package:kit_app/src/theme.dart';
import 'package:kit_app/src/widgets/builds_card.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'helpers/fake_claude.dart';

class _Rig {
  _Rig() {
    project = Directory.systemTemp.createTempSync('kit_builds_');
    home = Directory.systemTemp.createTempSync('kit_builds_home_');
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('name: kit_scratch\nversion: 1.0.0+1\n');
    builds = Builds(
      dir: project.path,
      blobs: store,
      slug: () => 'demo',
      publish: (id, doc) async => published[id] = doc,
      prune: (keep) async => pruned.add(keep),
      remove: (id) async => removed.add(id),
      push: pushes.add,
      starter: (bin, args, {workingDirectory, environment}) async {
        final f = FakeClaude()..startedWith = args;
        spawned.add(f);
        return f;
      },
      runner: (bin, args, {workingDirectory, environment}) async {
        if (args.contains('--short')) return ProcessResult(1, 0, 'abc1234\n', '');
        if (args.contains('--abbrev-ref')) return ProcessResult(1, 0, 'main\n', '');
        return ProcessResult(1, 0, '', '');
      },
      shellPath: () async => '/fake/bin',
      findBinary: (n) => '/fake/$n',
      home: home.path,
      now: () => clock,
    );
  }

  late final Directory project;
  late final Directory home;
  late final Builds builds;
  final store = MemoryBlobStore();
  final published = <String, Map<String, Object?>>{};
  final pruned = <List<String>>[];
  final removed = <String>[];
  final pushes = <Notice>[];
  final spawned = <FakeClaude>[];
  DateTime clock = DateTime.utc(2026, 9, 6, 7);

  /// The process is spawned a tick after start() returns.
  Future<void> spawnedOne() async {
    final n = spawned.length;
    for (var i = 0; i < 50 && spawned.length == n; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// The scripted flutter build: Gradle, the APK on disk, the exit.
  Future<void> succeed({int size = 1000}) async {
    final f = spawned.last;
    f.emit("Running Gradle task 'assembleDebug'...");
    await pumpEventQueue();
    File(p.join(project.path, debugApkPath))
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(size, 7));
    f.emit('✓ Built build/app/outputs/flutter-apk/app-debug.apk (1.0MB)');
    await pumpEventQueue();
    f.exit(0);
    for (var i = 0; i < 200; i++) {
      await pumpEventQueue();
      if (!builds.building) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  void close() {
    builds.dispose();
    project.deleteSync(recursive: true);
    home.deleteSync(recursive: true);
  }
}

Widget _app(Widget child, {double scale = 1.0}) => MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: SingleChildScrollView(child: child))),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

void main() {
  group('the host', () {
    test('TRY IT: flutter build apk --debug, the APK in the bucket, the record ready, the push', () async {
      final r = _Rig();
      expect(await r.builds.start(), 'building 1.0.0+1 on the Mac');
      await r.spawnedOne();
      expect(r.spawned.single.startedWith, ['build', 'apk', '--debug', '--target-platform', 'android-arm64']);
      expect(r.builds.building, isTrue);
      final b0 = r.builds.latest!;
      expect(b0.building, isTrue);
      expect(b0.sha, 'abc1234');
      expect(b0.branch, 'main');
      expect(b0.version, '1.0.0+1');
      expect(b0.name, 'kit_scratch');
      expect(b0.by, 'phone');
      expect(r.published[b0.id]!['state'], 'building');
      expect(await r.builds.start(), 'a build is running');
      await r.succeed(size: 1234);
      final b = r.builds.latest!;
      expect(b.ready, isTrue);
      expect(b.size, 1234);
      expect(b.progress, 1);
      expect(b.path, 'projects/demo/builds/${b.id}.apk');
      expect((await r.store.get(b.path!)).length, 1234);
      expect(b.log, contains('✓ Built build/app/outputs/flutter-apk/app-debug.apk (1.0MB)'));
      expect(r.published[b.id]!['state'], 'ready');
      expect(r.pushes.single.title, 'Build ready · kit_scratch · 1.0.0+1');
      expect(r.pushes.single.data('demo')['buildId'], b.id);
      expect(r.builds.relay['state'], 'ready');
      expect(r.builds.relay['version'], '1.0.0+1');
      r.close();
    });

    test('four builds: the bucket and the list hold three, the oldest object and document go', () async {
      final r = _Rig();
      final ids = <String>[];
      for (var i = 0; i < 4; i++) {
        r.clock = r.clock.add(const Duration(minutes: 1));
        await r.builds.start();
        ids.add(r.builds.latest!.id);
        await r.spawnedOne();
        await r.succeed();
      }
      expect(r.builds.builds.length, 3);
      expect(r.builds.builds.map((b) => b.id), ids.reversed.take(3));
      expect((await r.store.list('projects/demo/builds')).length, 3);
      expect(r.pruned.last, ids.reversed.take(3).toList());
      expect(await r.builds.delete(ids.last), 'removed 1.0.0+1');
      expect(r.builds.builds.length, 2);
      expect((await r.store.list('projects/demo/builds')).length, 2);
      expect(r.removed, [ids.last]);
      // One the host never held, by id alone: the object goes too.
      await r.store.put('projects/demo/builds/old.apk', Uint8List.fromList([1]));
      expect(await r.builds.delete('old'), 'removed old');
      expect(r.removed.last, 'old');
      expect((await r.store.list('projects/demo/builds')).length, 2);
      r.close();
    });

    test('a build that fails: the first error line, the push, the log on the record', () async {
      final r = _Rig();
      await r.builds.start();
      await r.spawnedOne();
      final f = r.spawned.single;
      f.emit("Running Gradle task 'assembleDebug'...");
      f.emitErr('FAILURE: Build failed with an exception.');
      f.emitErr('* What went wrong:');
      f.emitErr("Execution failed for task ':app:compileDebugKotlin'.");
      await pumpEventQueue();
      f.exit(1);
      for (var i = 0; i < 200 && r.builds.building; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final b = r.builds.latest!;
      expect(b.failed, isTrue);
      expect(b.error, 'FAILURE: Build failed with an exception.');
      expect(b.log.length, 4);
      expect(r.pushes.single.title, 'Build failed · kit_scratch');
      expect(r.pushes.single.body, 'FAILURE: Build failed with an exception.');
      expect(r.published[b.id]!['state'], 'failed');
      expect(await r.store.list('projects/demo/builds'), isEmpty);
      r.close();
    });

    test('build on flip: off does nothing, on builds once, and the switch is kept on disk', () async {
      final r = _Rig();
      await r.builds.onFlip();
      expect(r.spawned, isEmpty);
      r.builds.setBuildOnFlip(true);
      await r.builds.onFlip();
      await r.spawnedOne();
      expect(r.spawned.length, 1);
      expect(r.builds.latest!.by, 'flip');
      await r.builds.onFlip();
      expect(r.spawned.length, 1, reason: 'one at a time');
      await r.succeed();
      final again = Builds(dir: r.project.path, blobs: r.store, slug: () => 'demo', home: r.home.path, starter: FakeClaude().starter, runner: (b, a, {workingDirectory, environment}) async => ProcessResult(1, 0, '', ''), shellPath: () async => '/fake/bin', findBinary: (n) => '/fake/$n');
      expect(again.buildOnFlip, isTrue, reason: 'read back');
      again.dispose();
      r.close();
    });
  });

  group('the relay', () {
    test('the host writes and prunes; the phone lists three newest first, reads the switch, sends the command, and installs', () async {
      final db = FakeFirebaseFirestore();
      final pub = RelayPublisher(db, 'demo', dir: '/x', machine: 'm');
      final at = DateTime.utc(2026, 9, 6, 7);
      for (var i = 0; i < 4; i++) {
        await pub.publishBuild('b$i', BuildRecord(id: 'b$i', state: BuildState.ready, version: '1.0.$i', at: at.add(Duration(minutes: i)), path: 'projects/demo/builds/b$i.apk', size: 10).toMap());
      }
      await pub.pruneBuilds(['b3', 'b2', 'b1']);
      expect((await pub.readBuilds()).map((b) => b.id), ['b3', 'b2', 'b1']);
      await db.collection('projects').doc('demo').set({'session': {'mode': 'idle', 'build': {'state': 'ready', 'buildOnFlip': true}}});
      final store = MemoryBlobStore();
      await store.put('projects/demo/builds/b3.apk', Uint8List.fromList(List.filled(50, 1)));
      final d = RemoteDeck(db, 'demo', blobs: store)..start();
      await pumpEventQueue();
      expect(d.buildList.map((b) => b.id), ['b3', 'b2', 'b1']);
      expect(d.buildOnFlip, isTrue);
      final sent = d.buildCommand('start');
      final del = d.buildCommand('delete', id: 'b1');
      await pumpEventQueue();
      final cmds = (await db.collection('projects').doc('demo').collection('commands').get()).docs;
      final start = cmds.firstWhere((c) => c.data()['action'] == 'start').data();
      final delDoc = cmds.firstWhere((c) => c.data()['action'] == 'delete').data();
      expect(start['type'], 'build');
      expect(start.containsKey('id'), isFalse, reason: 'no id to clash with the command doc id');
      expect(delDoc['buildId'], 'b1', reason: 'the build rides as buildId');
      for (final c in cmds) {
        await c.reference.set({'doneAt': Timestamp.now(), 'result': 'ok'}, SetOptions(merge: true));
      }
      expect(await sent, 'ok');
      expect(await del, 'ok');
      // The install: the object to the cache, the installer on it.
      final cache = Directory.systemTemp.createTempSync('kit_cache_');
      RemoteDeck.cacheDir = () async => cache;
      String? opened;
      RemoteDeck.opener = (path) async {
        opened = path;
        return 'the installer opened';
      };
      final progress = <double>[];
      expect(await d.installBuild(d.buildList.first, progress.add), 'the installer opened');
      expect(opened, p.join(cache.path, 'builds', 'b3.apk'));
      expect(File(opened!).lengthSync(), 50);
      expect(progress.last, 1);
      expect(await d.installBuild(const BuildRecord(id: 'x'), (_) {}), 'that build is not ready');
      RemoteDeck.cacheDir = null;
      RemoteDeck.opener = null;
      cache.deleteSync(recursive: true);
      d.dispose();
      pub.dispose();
    });
  });

  group('the share', () {
    test('pictures become attachments, text becomes text, a missing file is skipped', () {
      final dir = Directory.systemTemp.createTempSync('kit_share_');
      final png = File(p.join(dir.path, 'Screenshot_1.png'))..writeAsBytesSync(List.filled(10, 1));
      final s = sharedFrom([
        SharedMediaFile(path: png.path, type: SharedMediaType.image),
        SharedMediaFile(path: 'what is wrong here?', type: SharedMediaType.text),
        SharedMediaFile(path: p.join(dir.path, 'gone.png'), type: SharedMediaType.image),
      ]);
      expect(s.files.single.name, 'Screenshot_1.png');
      expect(s.files.single.mime, 'image/png');
      expect(s.files.single.size, 10);
      expect(s.text, 'what is wrong here?');
      expect(s.isEmpty, isFalse);
      expect(sharedFrom(const []).isEmpty, isTrue);
      expect(mimeFor('a.jpg'), 'image/jpeg');
      expect(mimeFor('a.bin'), 'application/octet-stream');
      dir.deleteSync(recursive: true);
    });
  });

  group('the card', () {
    for (final scale in [1.0, 2.0, 3.12]) {
      testWidgets('at ${scale}x: none yet, building, a ready row that installs, a failed row with its log — no overflow', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final calls = <String>[];
        Future<String> onAction(String action, {String? id, bool? on}) async {
          calls.add('$action/$id/$on');
          return 'ok $action';
        }

        await tester.pumpWidget(_app(BuildsCard(builds: const [], buildOnFlip: false, onAction: onAction), scale: scale));
        await _settle(tester);
        expect(find.text('BUILDS · NONE YET'), findsOneWidget);
        await tester.tap(find.text('TRY IT'));
        await _settle(tester);
        expect(calls, ['start/null/null']);
        await tester.tap(find.byType(Switch));
        await _settle(tester);
        expect(calls.last, 'switch/null/true');
        expect(tester.takeException(), isNull);

        final at = DateTime(2026, 9, 6, 7);
        final building = BuildRecord(id: 'b2', progress: 0.42, version: '1.0.0+2', sha: 'def5678', at: at);
        final ready = BuildRecord(id: 'b1', state: BuildState.ready, version: '1.0.0+1', sha: 'abc1234', branch: 'main', size: 24 * 1024 * 1024, at: at, path: 'p', log: const ['✓ Built'], by: 'phone');
        final failed = BuildRecord(id: 'b0', state: BuildState.failed, version: '1.0.0+0', error: 'FAILURE: Build failed with an exception.', at: at, log: const ['FAILURE: Build failed with an exception.']);
        BuildRecord? installed;
        BuildRecord? logged;
        await tester.pumpWidget(_app(
          BuildsCard(
            builds: [building, ready, failed],
            buildOnFlip: true,
            onAction: onAction,
            now: () => at.add(const Duration(minutes: 5)),
            onInstall: (b, progress) async {
              installed = b;
              progress(0.5);
              return 'the installer opened';
            },
            onLog: (b) => logged = b,
          ),
          scale: scale,
        ));
        await _settle(tester);
        expect(find.text('BUILDS · BUILDING · 42 %'), findsOneWidget);
        expect(find.text('BUILDING…'), findsOneWidget);
        expect(find.text('READY · 1.0.0+1 · 24.0 MB · 5 MIN AGO'), findsOneWidget);
        expect(find.textContaining('FAILED · FAILURE: BUILD FAILED'), findsOneWidget, reason: 'the row\'s line');
        expect(find.text('FAILURE: Build failed with an exception.'), findsOneWidget, reason: 'the error under it');
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('INSTALL'));
        await tester.tap(find.text('INSTALL'));
        await _settle(tester);
        expect(installed?.id, 'b1');
        await tester.ensureVisible(find.text('LOG').last);
        await tester.tap(find.text('LOG').last);
        await _settle(tester);
        expect(logged?.id, 'b0');
        await tester.ensureVisible(find.text('REMOVE').last);
        await tester.tap(find.text('REMOVE').last);
        await _settle(tester);
        expect(calls.last, 'delete/b0/null');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
