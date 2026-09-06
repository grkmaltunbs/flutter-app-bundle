// The run bay: flutter run over the daemon protocol against a scripted
// process, the log in the relay, the card, the log sheet, and the same
// over the phone.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter/services.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/run_bay.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/relay.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/screens/log_sheet.dart';
import 'package:kit_app/src/theme.dart';
import 'package:kit_app/src/widgets/run_card.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_claude.dart';

const _appId = '4809184c-5a1b-474d-86ee-9ba2f810e53d';

/// What `flutter devices --machine` and `flutter emulators` print on
/// this Mac, as the runner answers them.
Future<ProcessResult> _tools(String bin, List<String> args, {String? workingDirectory, Map<String, String>? environment}) async {
  if (args.first == 'devices') {
    return ProcessResult(1, 0, jsonEncode([
      {'id': '46ee1854', 'name': '2512BPNDAG', 'targetPlatform': 'android-arm64', 'emulator': false},
      {'id': '022B', 'name': 'iPhone 17 Pro', 'targetPlatform': 'ios', 'emulator': true},
      {'id': 'macos', 'name': 'macOS', 'targetPlatform': 'darwin', 'emulator': false},
    ]), '');
  }
  if (args.first == 'emulators' && args.length == 1) {
    return ProcessResult(1, 0, '2 available emulators:\n\nId                  • Name          • Manufacturer • Platform\n\napple_ios_simulator • iOS Simulator • Apple        • ios\nokey_test           • okey_test     • Google       • android\n', '');
  }
  return ProcessResult(1, 0, '', '');
}

void _boot(FakeClaude fake, {bool dtd = true}) {
  fake.emit('[{"event":"daemon.connected","params":{"version":"0.6.1","pid":21446}}]');
  fake.emit('[{"event":"app.start","params":{"appId":"$_appId","deviceId":"macos","directory":"/x","supportsRestart":true,"launchMode":"run","mode":"debug"}}]');
  fake.emit('Launching lib/main.dart on macOS in debug mode...');
  fake.emit('[{"event":"app.progress","params":{"appId":"$_appId","id":"0","progressId":null,"message":"Building macOS application...","finished":false}}]');
  fake.emit('[{"event":"app.progress","params":{"appId":"$_appId","id":"0","progressId":null,"finished":true}}]');
  fake.emit('✓ Built build/macos/Build/Products/Debug/kit_scratch.app');
  fake.emit('[{"event":"app.debugPort","params":{"appId":"$_appId","port":63082,"wsUri":"ws://127.0.0.1:63082/dS5=/ws","baseUri":"file:///tmp/x"}}]');
  if (dtd) fake.emit('[{"event":"app.dtd","params":{"appId":"$_appId","uri":"ws://127.0.0.1:63081/bRW="}}]');
  fake.emit('[{"event":"app.started","params":{"appId":"$_appId"}}]');
}

RunBay _bay(FakeClaude fake, String dir, {String? runtime, Duration editDebounce = const Duration(milliseconds: 60)}) => RunBay(
      dir: dir,
      runtime: () => runtime,
      starter: fake.starter,
      runner: _tools,
      shellPath: () async => '/fake/bin',
      findBinary: (_) => '/fake/flutter',
      editDebounce: editDebounce,
      pollEvery: const Duration(milliseconds: 10),
      bootWait: const Duration(milliseconds: 200),
    );

Widget _app(Widget child, {required double scale}) => MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: SingleChildScrollView(child: child))),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

void main() {
  late Directory project;
  setUp(() {
    project = Directory.systemTemp.createTempSync('kit_run_');
    Directory(p.join(project.path, 'lib')).createSync();
  });
  tearDown(() => project.deleteSync(recursive: true));

  group('the bay', () {
    test('devices: the booted ones from flutter devices, the off emulators from flutter emulators — one per kind', () async {
      final bay = _bay(FakeClaude(), project.path);
      final list = await bay.devices();
      expect(list.map((d) => d.id), ['46ee1854', '022B', 'macos', 'okey_test'], reason: 'the iOS emulator is booted already; the Android one is off');
      expect(list.last.off, isTrue);
      expect(bay.state.devices.length, 4);
      expect(bay.state.devicesAt, isNotNull);
      bay.dispose();
    });

    test('start on the default device: the daemon lines become the state, the URIs and the log; reload, restart, stop', () async {
      final fake = FakeClaude();
      final bay = _bay(fake, project.path, runtime: 'macos');
      final phases = <RunPhase>[];
      bay.addListener(() {
        if (phases.isEmpty || phases.last != bay.state.phase) phases.add(bay.state.phase);
      });
      expect(await bay.start(), 'starting on macOS');
      expect(fake.startedWith, ['run', '-d', 'macos', '--machine', '--print-dtd']);
      expect(fake.startedIn, project.path);
      expect(bay.state.phase, RunPhase.starting);
      expect(bay.state.runId, startsWith('r'));
      expect(bay.log.lines.single, 'flutter run -d macos --machine --print-dtd');
      _boot(fake);
      await pumpEventQueue();
      expect(bay.state.running, isTrue);
      expect(bay.state.appId, _appId);
      expect(bay.state.vmUri, 'ws://127.0.0.1:63082/dS5=/ws');
      expect(bay.state.dtdUri, 'ws://127.0.0.1:63081/bRW=');
      expect(bay.state.since, isNotNull);
      expect(bay.log.lines, containsAllInOrder(['Launching lib/main.dart on macOS in debug mode...', 'Building macOS application...', '✓ Built build/macos/Build/Products/Debug/kit_scratch.app', 'Running on macOS.']));
      expect(bay.log.lines.any((l) => l.startsWith('[{')), isFalse, reason: 'protocol lines are not log lines');
      expect(bay.state.lines, bay.log.seq);
      expect(phases.where((x) => x != RunPhase.idle), [RunPhase.starting, RunPhase.running]);
      expect(await bay.start(), 'already running on macOS');

      // Reload: the command on stdin, the daemon's word back.
      final reload = bay.reload();
      await fake.writtenLines(1);
      expect(jsonDecode(fake.written[0]), [
        {'id': 1, 'method': 'app.restart', 'params': {'appId': _appId, 'fullRestart': false, 'reason': 'manual'}}
      ]);
      fake.emit('Reloaded 0 libraries in 106ms.');
      fake.emit('[{"id":1,"result":{"code":0,"message":"Reloaded 0 libraries"}}]');
      expect(await reload, 'reloaded 0 libraries');
      final restart = bay.reload(full: true);
      await fake.writtenLines(2);
      expect((jsonDecode(fake.written[1]) as List).first['params']['fullRestart'], isTrue);
      fake.emit('[{"id":2,"result":{"code":0,"message":""}}]');
      expect(await restart, 'restarted');
      final failed = bay.reload();
      await fake.writtenLines(3);
      fake.emit('[{"id":3,"result":{"code":1,"message":"Reload rejected: a syntax error"}}]');
      expect(await failed, 'failed: Reload rejected: a syntax error');

      // An exception in the app: the count, the last line, the pill.
      fake.emit('══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══');
      fake.emit('The following assertion was thrown building Home:');
      fake.emitErr('[ERROR:flutter/runtime/dart_vm_initializer.cc(41)] Unhandled Exception: Bad state');
      await pumpEventQueue();
      expect(bay.state.exceptions, 2);
      expect(bay.state.lastError, contains('Unhandled Exception: Bad state'));
      expect(runLine(bay.state), contains('· 2 exceptions'));

      // Stop: app.stop, then the process ends.
      final stop = bay.stop();
      await fake.writtenLines(4);
      expect((jsonDecode(fake.written[3]) as List).first['method'], 'app.stop');
      fake.emit('Application finished.');
      fake.emit('[{"id":4,"result":true}]');
      fake.exit(0);
      expect(await stop, 'stopped');
      await pumpEventQueue();
      expect(bay.state.phase, RunPhase.stopped);
      expect(bay.state.error, isNull);
      expect(bay.log.lines.last, 'Process exited (0).');
      expect(bay.state.devices.length, 4, reason: 'the list outlives the run');
      bay.dispose();
    });

    test('a process that dies while starting fails with the last line; a pick that is off boots first', () async {
      final spawned = <FakeClaude>[];
      final bay = RunBay(
        dir: project.path,
        runtime: () => 'android-emulator',
        starter: (bin, args, {workingDirectory, environment}) async {
          final f = FakeClaude()..startedWith = args;
          spawned.add(f);
          return f;
        },
        runner: (bin, args, {workingDirectory, environment}) async {
          if (args.length == 3 && args[1] == '--launch') return ProcessResult(1, 0, '', '');
          if (args.first == 'devices' && spawned.isEmpty && _launched) {
            return ProcessResult(1, 0, jsonEncode([
              {'id': 'emulator-5554', 'name': 'okey_test', 'targetPlatform': 'android-x64', 'emulator': true},
              {'id': 'macos', 'name': 'macOS', 'targetPlatform': 'darwin', 'emulator': false},
            ]), '');
          }
          return _tools(bin, args, workingDirectory: workingDirectory, environment: environment);
        },
        shellPath: () async => '/fake/bin',
        findBinary: (_) => '/fake/flutter',
        pollEvery: const Duration(milliseconds: 10),
        bootWait: const Duration(seconds: 2),
      );
      _launched = false;
      final started = bay.start(device: 'okey_test');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bay.state.phase, RunPhase.starting);
      expect(bay.log.lines.last, 'Booting okey_test…');
      _launched = true;
      expect(await started, 'starting on okey_test');
      expect(spawned.single.startedWith, contains('emulator-5554'), reason: 'the booted emulator, by its device id');
      expect(bay.state.device, 'emulator-5554');
      spawned.single.emit('Error: No pubspec.yaml file found.');
      spawned.single.exit(1);
      await pumpEventQueue();
      expect(bay.state.phase, RunPhase.failed);
      expect(bay.state.error, 'flutter run exited with code 1 — Error: No pubspec.yaml file found.');
      expect(runLine(bay.state), startsWith('Failed · flutter run exited'));
      bay.dispose();
    });

    test('no device at all: the start fails and says so', () async {
      final bay = RunBay(dir: project.path, runtime: () => 'macos', starter: FakeClaude().starter, runner: (b, a, {workingDirectory, environment}) async => ProcessResult(1, 0, '[]', ''), shellPath: () async => '/fake/bin', findBinary: (_) => '/fake/flutter');
      expect(await bay.start(), startsWith('no device to run on'));
      expect(bay.state.phase, RunPhase.failed);
      bay.dispose();
    });

    test('reload on edit: a save under lib/ reloads once the burst settles, only while running', () async {
      final fake = FakeClaude();
      final bay = _bay(fake, project.path, runtime: 'macos');
      bay.setReloadOnEdit(true);
      expect(bay.state.reloadOnEdit, isTrue);
      final f = File(p.join(project.path, 'lib', 'main.dart'))..writeAsStringSync('void main() {}');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(fake.written, isEmpty, reason: 'not running: nothing to reload');
      await bay.start();
      _boot(fake);
      await pumpEventQueue();
      f.writeAsStringSync('void main() { print(1); }');
      f.writeAsStringSync('void main() { print(2); }');
      await fake.writtenLines(1);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(fake.written.length, 1, reason: 'one reload for the burst');
      expect((jsonDecode(fake.written[0]) as List).first['params']['fullRestart'], isFalse);
      expect(bay.log.lines.last, 'Reload on edit…');
      fake.emit('[{"id":1,"result":{"code":0,"message":"Reloaded 1 library"}}]');
      await pumpEventQueue();
      expect(bay.log.lines.last, 'Reload on edit: reloaded 1 library');
      bay.setReloadOnEdit(false);
      f.writeAsStringSync('void main() { print(3); }');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(fake.written.length, 1, reason: 'off: no reload');
      await bay.stop();
      bay.dispose();
    });

    test('the log stream follows the ring', () async {
      final fake = FakeClaude();
      final bay = _bay(fake, project.path, runtime: 'macos');
      final seen = <int>[];
      final sub = bay.logStream.listen((l) => seen.add(l.length));
      await bay.start();
      fake.emit('one');
      fake.emit('two');
      await pumpEventQueue();
      expect(seen.last, 3);
      await sub.cancel();
      bay.dispose();
    });
  });

  group('the relay', () {
    test('the log goes up in documents of 200 lines, only what grew, the last ten kept', () async {
      final db = FakeFirebaseFirestore();
      final pub = RelayPublisher(db, 'demo', dir: '/x', machine: 'm');
      final log = RunLog(keep: 2000);
      for (var i = 0; i < 250; i++) {
        log.add('line $i');
      }
      pub.publishRunLog('r1', log);
      await pumpEventQueue(times: 50);
      final coll = db.collection('projects').doc('demo').collection('runs').doc('r1').collection('log');
      var docs = (await coll.orderBy(FieldPath.documentId).get()).docs;
      expect(docs.map((d) => d.id), ['c000000', 'c000001']);
      expect((docs[0].data()['lines'] as List).length, 200);
      expect(docs[0].data()['from'], 0);
      expect((docs[1].data()['lines'] as List).length, 50);
      expect(docs[1].data()['from'], 200);
      // More lines: coalesced behind the one-second window, then written.
      for (var i = 250; i < 420; i++) {
        log.add('line $i');
      }
      pub.publishRunLog('r1', log);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await pumpEventQueue(times: 50);
      docs = (await coll.orderBy(FieldPath.documentId).get()).docs;
      expect(docs.map((d) => d.id), ['c000000', 'c000001', 'c000002']);
      expect((docs[1].data()['lines'] as List).length, 200);
      expect((docs[2].data()['lines'] as List).last, 'line 419');
      // Far past the keep: old documents go.
      for (var i = 420; i < 2600; i++) {
        log.add('line $i');
      }
      pub.publishRunLog('r1', log);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await pumpEventQueue(times: 50);
      docs = (await coll.orderBy(FieldPath.documentId).get()).docs;
      expect(docs.first.id, isNot('c000000'));
      expect(docs.length, lessThanOrEqualTo(RelayPublisher.logChunks + 1));
      expect((docs.last.data()['lines'] as List).last, 'line 2599');
      // A new run starts its own documents from the first line.
      final log2 = RunLog()..add('fresh');
      pub.publishRunLog('r2', log2);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await pumpEventQueue(times: 50);
      final d2 = (await db.collection('projects').doc('demo').collection('runs').doc('r2').collection('log').get()).docs;
      expect(d2.single.id, 'c000000');
      expect(d2.single.data()['lines'], ['fresh']);
      pub.dispose();
    });

    test('the phone reads the run off the session, joins the log, and sends the commands', () async {
      final db = FakeFirebaseFirestore();
      final run = const RunState(phase: RunPhase.running, runId: 'r1', device: 'macos', deviceName: 'macOS', exceptions: 1, lastError: 'boom', lines: 3);
      await db.collection('projects').doc('demo').set({'session': {'mode': 'bridge', 'state': 'ready', 'run': run.toMap()}});
      final log = db.collection('projects').doc('demo').collection('runs').doc('r1').collection('log');
      await log.doc('c000000').set({'from': 0, 'lines': ['a', 'b']});
      await log.doc('c000001').set({'from': 200, 'lines': ['c']});
      final d = RemoteDeck(db, 'demo')..start();
      await pumpEventQueue();
      expect(d.run.running, isTrue);
      expect(d.run.deviceName, 'macOS');
      expect(d.run.exceptions, 1);
      expect(await d.runLog('r1').first, ['a', 'b', 'c']);
      // The command, stamped by a host.
      final sent = d.runCommand('start', device: 'macos');
      await pumpEventQueue();
      final cmds = await db.collection('projects').doc('demo').collection('commands').get();
      expect(cmds.docs.single.data()['type'], 'run');
      expect(cmds.docs.single.data()['action'], 'start');
      expect(cmds.docs.single.data()['device'], 'macos');
      await cmds.docs.single.reference.set({'doneAt': Timestamp.now(), 'result': 'starting on macOS'}, SetOptions(merge: true));
      expect(await sent, 'starting on macOS');
      d.dispose();
    });
  });

  group('the screens', () {
    for (final scale in [1.0, 2.0, 3.12]) {
      testWidgets('at ${scale}x: the card idle, running with an exception, failed — no overflow; the buttons send their actions', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final calls = <String>[];
        Future<String> onAction(String action, {String? device, bool? on}) async {
          calls.add('$action/$device/$on');
          return 'ok $action';
        }

        const devices = [RunDevice(id: '022B', name: 'iPhone 17 Pro', platform: 'ios', emulator: true), RunDevice(id: 'okey_test', name: 'okey_test', platform: 'android', emulator: true, off: true)];
        await tester.pumpWidget(_app(RunCard(run: const RunState(devices: devices), onAction: onAction), scale: scale));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('RUN · IDLE'), findsOneWidget);
        expect(find.text('RUN'), findsOneWidget);
        expect(find.text('Default device'), findsOneWidget);
        await tester.tap(find.text('RUN'));
        await _settle(tester);
        expect(calls, ['start/null/null']);
        expect(find.text('ok start'), findsOneWidget, reason: 'the line toasted');
        await tester.tap(find.byType(Switch));
        await _settle(tester);
        expect(calls.last, 'reload_on_edit/null/true');

        final since = DateTime(2026, 9, 6, 0, 0);
        var logs = 0;
        final running = RunState(phase: RunPhase.running, runId: 'r1', device: '022B', deviceName: 'iPhone 17 Pro', since: since, exceptions: 1, lastError: '══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══', lines: 12, reloadOnEdit: true, devices: devices);
        await tester.pumpWidget(_app(RunCard(run: running, onAction: onAction, onLog: () => logs++, now: () => since.add(const Duration(minutes: 4))), scale: scale));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('RUN · RUNNING · IPHONE 17 PRO · 4 MIN · 1 EXCEPTION'), findsOneWidget);
        expect(find.textContaining('EXCEPTION CAUGHT'), findsOneWidget);
        expect(find.text('RUN'), findsNothing);
        expect(find.byType(DropdownButton<String?>), findsNothing, reason: 'no picker while it runs');
        await tester.tap(find.text('RELOAD'));
        await _settle(tester);
        await tester.tap(find.text('RESTART'));
        await _settle(tester);
        await tester.tap(find.text('LOG · 12'));
        await _settle(tester);
        await tester.tap(find.text('STOP'));
        await _settle(tester);
        expect(calls.sublist(2), ['reload/null/null', 'restart/null/null', 'stop/null/null']);
        expect(logs, 1);

        await tester.pumpWidget(_app(RunCard(run: const RunState(phase: RunPhase.failed, error: 'no device to run on', devices: devices), onAction: onAction), scale: scale));
        await _settle(tester);
        expect(find.text('RUN · FAILED · NO DEVICE TO RUN ON'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    for (final scale in [1.0, 2.0, 3.12]) {
      testWidgets('at ${scale}x: the Deck shows the run on a line under the facts, amber once it threw; a tap opens the log', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final since = DateTime.now().subtract(const Duration(minutes: 4));
        DeckView deck(RunState run) => DeckView(
              state: BridgeState.ready,
              title: 'Scratch',
              facts: const ['session abcd1234', 'claude-fable-5-1'],
              messages: const [],
              running: true,
              canResume: false,
              onStart: () {},
              onResume: () {},
              onStop: () {},
              onSend: (_, _) async {},
              onOptions: ({mode, chrome, model, effort}) {},
              foldOnScroll: false,
              run: run,
              onRun: (action, {device, on}) async => 'ok',
              runLog: (id) => Stream.value(['Launching lib/main.dart', 'Running on iPhone 17 Pro.']),
            );
        await tester.pumpWidget(MaterialApp(theme: kitTheme(KitTokens.light), home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: deck(RunState(phase: RunPhase.running, runId: 'r1', device: '022B', deviceName: 'iPhone 17 Pro', since: since, exceptions: 2, lines: 2))))));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('RUNNING · IPHONE 17 PRO · 4 MIN · 2 EXCEPTIONS'), findsOneWidget);
        await tester.tap(find.text('RUNNING · IPHONE 17 PRO · 4 MIN · 2 EXCEPTIONS'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('LOG · IPHONE 17 PRO'), findsOneWidget);
        expect(find.text('Running on iPhone 17 Pro.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        // Idle: no line; the card in the fold offers RUN.
        await tester.pumpWidget(MaterialApp(theme: kitTheme(KitTokens.light), home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: deck(const RunState())))));
        await _settle(tester);
        expect(find.textContaining('RUNNING ·'), findsNothing);
        await tester.tap(find.byTooltip('Show session controls'));
        await _settle(tester);
        await tester.ensureVisible(find.text('RUN · IDLE'));
        expect(find.text('RUN'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('the log sheet follows, pauses, finds and copies', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ctrl = StreamController<List<String>>.broadcast();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      await tester.pumpWidget(MaterialApp(theme: kitTheme(KitTokens.light), home: Scaffold(body: LogView(lines: ctrl.stream, title: 'Log · macOS', initial: const ['Launching lib/main.dart', 'Running on macOS.']))));
      await _settle(tester);
      expect(find.text('LOG · MACOS'), findsOneWidget);
      expect(find.text('Running on macOS.'), findsOneWidget);
      ctrl.add([for (var i = 0; i < 60; i++) 'line $i', '══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══']);
      await _settle(tester);
      expect(find.textContaining('EXCEPTION CAUGHT'), findsOneWidget, reason: 'followed to the end');
      expect(find.text('line 0'), findsNothing, reason: 'scrolled past');
      await tester.tap(find.text('PAUSE'));
      await _settle(tester);
      expect(find.text('FOLLOW'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'line 5');
      await _settle(tester);
      expect(find.text('line 5'), findsNWidgets(2), reason: 'the line, and the field');
      expect(find.text('line 55'), findsOneWidget);
      expect(find.text('line 4'), findsNothing);
      expect(find.text('11 / 61'), findsOneWidget);
      await tester.tap(find.text('COPY'));
      await _settle(tester);
      expect(copied, isNotNull);
      expect(copied!.split('\n').length, 11);
      expect(tester.takeException(), isNull);
      await ctrl.close();
      await tester.pumpWidget(const SizedBox());
    });
  });
}

bool _launched = false;
