// The mirror: frames from a scripted device, the stream while a sheet
// watches, input played back, the record over the relay, and the sheet.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/attachments.dart';
import 'package:kit_app/src/blobs.dart';
import 'package:kit_app/src/host/mirror.dart';
import 'package:kit_app/src/host/run_bay.dart';
import 'package:kit_app/src/relay.dart';
import 'package:kit_app/src/screens/mirror_sheet.dart';
import 'package:kit_app/src/theme.dart';

import 'helpers/fake_claude.dart';

final _png = base64Decode(onePixelPng);

class _Rig {
  _Rig({String kind = 'ios'}) {
    tmp = Directory.systemTemp.createTempSync('kit_mirror_');
    bay = RunBay(dir: tmp.path, starter: FakeClaude().starter, runner: (b, a, {workingDirectory, environment}) async => ProcessResult(1, 0, '[]', ''), shellPath: () async => '/fake/bin', findBinary: (_) => '/fake/flutter');
    final dev = switch (kind) {
      'ios' => const RunDevice(id: '022B', name: 'iPhone 17 Pro', platform: 'ios', emulator: true),
      'android' => const RunDevice(id: 'emulator-5554', name: 'okey_test', platform: 'android-x64', emulator: true),
      _ => const RunDevice(id: 'macos', name: 'macOS', platform: 'darwin'),
    };
    bay.state = RunState(phase: RunPhase.running, runId: 'r1', device: dev.id, deviceName: dev.name, devices: [dev]);
    mirror = Mirror(
      run: bay,
      blobs: blobs,
      slug: () => 'demo',
      publish: (m) async => published.add(m),
      dir: tmp.path,
      runner: _runner,
      shellPath: () async => '/fake/bin',
      findBinary: (name) => name == 'idb' && !idb ? null : '/fake/$name',
      shrink: (png) async => Uint8List.fromList([...png, 0]),
      now: () => clock,
      period: const Duration(milliseconds: 30),
      stale: const Duration(seconds: 15),
      tmp: tmp,
    );
  }

  late final Directory tmp;
  late final RunBay bay;
  late final Mirror mirror;
  /// idb installed on this Mac — off by default, as it is.
  bool idb = false;
  final blobs = MemoryBlobStore();
  final published = <Map<String, Object?>>[];
  final commands = <List<String>>[];
  bool failCapture = false;
  DateTime clock = DateTime.utc(2026, 9, 6, 0, 30);

  Future<ProcessResult> _runner(String bin, List<String> args, {String? workingDirectory, Map<String, String>? environment}) async {
    commands.add([bin, ...args]);
    if (failCapture && (bin == 'xcrun' && args.contains('screenshot') || bin == '/bin/sh')) return ProcessResult(1, 1, '', 'no such device');
    if (bin == 'xcrun' && args.contains('screenshot')) {
      File(args.last).writeAsBytesSync(_png);
      return ProcessResult(1, 0, '', '');
    }
    if (bin == 'xcrun' && args.contains('getenv')) return ProcessResult(1, 0, '3.000000\n', '');
    if (bin == '/bin/sh') {
      final path = RegExp(r'> "([^"]+)"').firstMatch(args.last)!.group(1)!;
      File(path).writeAsBytesSync(_png);
      return ProcessResult(1, 0, '', '');
    }
    if (bin == 'osascript') return ProcessResult(1, 0, '364, 49, 324, 731\n', '');
    if (bin == 'screencapture') {
      File(args.last).writeAsBytesSync(_png);
      return ProcessResult(1, 0, '', '');
    }
    return ProcessResult(1, 0, '', '');
  }

  void close() {
    mirror.dispose();
    bay.dispose();
    tmp.deleteSync(recursive: true);
  }
}

Widget _app(Widget child, {double scale = 1.0}) => MaterialApp(
      theme: kitTheme(KitTokens.light),
      home: MediaQuery(data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)), child: Scaffold(body: child)),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

void main() {
  group('the host', () {
    test('one frame: captured, shrunk, put up, the record ticked', () async {
      final r = _Rig();
      expect(await r.mirror.frame(), 'frame 1 · 720×720');
      expect(r.commands.single.take(5), ['xcrun', 'simctl', 'io', '022B', 'screenshot']);
      expect(r.mirror.state.seq, 1);
      expect(r.mirror.state.dw, 1);
      expect(r.mirror.state.dh, 1);
      expect(r.mirror.state.at, r.clock);
      expect(r.mirror.state.streaming, isFalse);
      expect(r.mirror.lastFrame!.length, _png.length + 1, reason: 'the shrunk bytes');
      expect((await r.blobs.get('projects/demo/frames/live.jpg')).length, _png.length + 1);
      expect(r.published.last['seq'], 1);
      expect(r.published.last.containsKey('watching'), isFalse);
      expect(File(r.tmp.path).parent.listSync().where((f) => f.path.contains('kit-mirror-')), isEmpty, reason: 'temp files cleaned');
      // A capture that fails says so, and the record carries the error.
      r.failCapture = true;
      expect(await r.mirror.frame(), startsWith('capture failed: '));
      expect(r.mirror.state.error, contains('no such device'));
      r.failCapture = false;
      await r.mirror.frame();
      expect(r.mirror.state.error, isNull, reason: 'cleared by the next frame');
      // Nothing running: no frame.
      r.bay.state = const RunState();
      expect(await r.mirror.frame(), 'nothing is running');
      r.close();
    });

    test('a watching sheet streams a frame a period; a stale heartbeat stops it', () async {
      final r = _Rig();
      r.mirror.watching(r.clock, 'phone');
      expect(r.mirror.state.streaming, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 130));
      expect(r.mirror.state.seq, greaterThanOrEqualTo(3));
      expect(r.published.first['streaming'], isTrue);
      final seq = r.mirror.state.seq;
      // The phone went quiet.
      r.clock = r.clock.add(const Duration(seconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(r.mirror.state.streaming, isFalse);
      expect(r.mirror.state.seq, lessThanOrEqualTo(seq + 1));
      expect(r.published.last['streaming'], isFalse);
      // Heard again: on again. The run ending: off.
      r.mirror.watching(r.clock, 'phone');
      expect(r.mirror.state.streaming, isTrue);
      r.mirror.stop();
      expect(r.mirror.state.streaming, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      r.close();
    });

    test('input on the simulator needs idb; with it, points from pixels by the scale; then a frame', () async {
      final r = _Rig();
      expect(await r.mirror.input(inputCommand('tap', x: 600, y: 900)), idbMissing);
      expect(r.mirror.state.error, idbMissing);
      r.idb = true;
      expect(await r.mirror.input(inputCommand('tap', x: 600, y: 900)), 'tap 600, 900');
      final tap = r.commands.firstWhere((c) => c[0] == '/fake/idb');
      expect(tap.sublist(1), ['ui', 'tap', '--udid', '022B', '200.0', '300.0']);
      expect(r.mirror.state.lastInput, 'TAP 600, 900');
      expect(r.mirror.state.error, isNull);
      expect(r.mirror.state.seq, 1, reason: 'the next frame follows the input');
      await r.mirror.input(inputCommand('swipe', x: 300, y: 2400, x2: 300, y2: 600));
      expect(r.commands.where((c) => c[0] == '/fake/idb').last.sublist(1), ['ui', 'swipe', '--udid', '022B', '100.0', '800.0', '100.0', '200.0']);
      await r.mirror.input(inputCommand('text', text: 'hello'));
      expect(r.commands.where((c) => c[0] == '/fake/idb').last.sublist(1), ['ui', 'text', '--udid', '022B', 'hello']);
      r.close();
    });

    test('input on an android device goes through adb; a macOS run refuses', () async {
      final r = _Rig(kind: 'android');
      expect(await r.mirror.input(inputCommand('tap', x: 600, y: 900)), 'tap 600, 900');
      expect(r.commands.first, ['/fake/adb', '-s', 'emulator-5554', 'shell', 'input', 'tap', '600', '900']);
      expect(r.commands.last[0], '/bin/sh', reason: 'then screencap');
      await r.mirror.input(inputCommand('text', text: 'hi there'));
      expect(r.commands.where((c) => c[0] == '/fake/adb').last.sublist(4), ['input', 'text', 'hi%sthere']);
      await r.mirror.input(inputCommand('key', text: 'KEYCODE_BACK'));
      expect(r.commands.where((c) => c[0] == '/fake/adb').last.sublist(4), ['input', 'keyevent', 'KEYCODE_BACK']);
      r.close();
      final m = _Rig(kind: 'macos');
      File('${m.tmp.path}/pubspec.yaml').writeAsStringSync('name: kit_scratch\n');
      expect(await m.mirror.frame(), startsWith('frame 1'));
      expect(m.commands.map((c) => c[0]), containsAllInOrder(['osascript', 'screencapture']));
      expect(m.commands.last.sublist(1, 3), ['-x', '-R']);
      expect(m.commands.last[3], '364,49,324,731');
      expect(await m.mirror.input(inputCommand('tap', x: 1, y: 1)), 'input on a macos run is not supported yet');
      m.close();
    });
  });

  group('the relay', () {
    test('the host merges its half, the phone its heartbeat; each reads the other', () async {
      final db = FakeFirebaseFirestore();
      final pub = RelayPublisher(db, 'demo', dir: '/x', machine: 'm');
      final heard = <String>[];
      final sub = pub.watchMirror((at, by) => heard.add('${at != null}/$by'));
      final d = RemoteDeck(db, 'demo', blobs: MemoryBlobStore())..start();
      await pumpEventQueue();
      await d.mirrorPing();
      await pumpEventQueue();
      expect(heard.last, 'true/phone');
      await pub.publishMirror(const MirrorState(seq: 2, w: 331, h: 720, dw: 1206, dh: 2622, streaming: true).toMap());
      await pumpEventQueue();
      expect(d.mirror.seq, 2);
      expect(d.mirror.dw, 1206);
      expect(d.mirror.streaming, isTrue);
      expect(d.mirror.watchingBy, 'phone', reason: 'the host\'s write kept the phone\'s field');
      final doc = (await db.collection('projects').doc('demo').get()).data()!['mirror'] as Map;
      expect((doc['watching'] as Map)['by'], 'phone');
      expect(doc['seq'], 2);
      expect(await d.mirrorStream.first, isA<MirrorState>().having((m) => m.seq, 'seq', 2), reason: 'the current value first');
      // The commands, stamped by a host.
      final frame = d.requestFrame();
      final tap = d.input(inputCommand('tap', x: 1, y: 2));
      await pumpEventQueue();
      final cmds = (await db.collection('projects').doc('demo').collection('commands').orderBy('sentAt').get()).docs;
      expect(cmds.map((c) => c.data()['type']), ['mirror', 'input']);
      expect(cmds[1].data()['x'], 1);
      for (final c in cmds) {
        await c.reference.set({'doneAt': Timestamp.now(), 'result': 'ok ${c.data()['type']}'}, SetOptions(merge: true));
      }
      expect(await frame, 'ok mirror');
      expect(await tap, 'ok input');
      await d.blobs!.put('projects/demo/frames/live.jpg', _png);
      expect((await d.mirrorFrame()).length, _png.length);
      await sub.cancel();
      d.dispose();
      pub.dispose();
    });
  });

  group('the sheet', () {
    for (final scale in [1.0, 2.0, 3.12]) {
      testWidgets('at ${scale}x: opens with a ping and a frame, draws it, a tap lands in device pixels, the camera attaches it', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final states = StreamController<MirrorState>();
        var pings = 0;
        var frames = 0;
        final inputs = <Map<String, Object?>>[];
        PendingAttachment? attached;
        final hooks = MirrorHooks(
          state: states.stream,
          frame: () async => _png,
          ping: () async => pings++,
          requestFrame: () async {
            frames++;
            return 'frame 1 · 331×720';
          },
          input: (c) async {
            inputs.add(c);
            return inputLabel(c).toLowerCase();
          },
        );
        await tester.pumpWidget(_app(MirrorView(hooks: hooks, title: 'Mirror · iPhone 17 Pro', onAttach: (f) => attached = f), scale: scale));
        await _settle(tester);
        expect(pings, 1);
        expect(frames, 1);
        expect(find.text('Waiting for the first frame…'), findsOneWidget);
        states.add(MirrorState(seq: 1, at: DateTime.now(), w: 331, h: 720, dw: 1206, dh: 2622, streaming: true));
        await _settle(tester);
        expect(find.byType(Image), findsOneWidget);
        expect(find.textContaining(' s ago'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // A tap in the middle of the drawn frame is the middle of the device.
        final box = tester.getRect(find.descendant(of: find.byType(AspectRatio), matching: find.byType(GestureDetector)));
        await tester.tapAt(box.center);
        await _settle(tester);
        expect(inputs.single['action'], 'tap');
        expect((inputs.single['x'] as int) - 603, lessThan(3));
        expect((inputs.single['y'] as int) - 1311, lessThan(3));
        expect(find.text('TAP ${inputs.single['x']}, ${inputs.single['y']}'), findsOneWidget);
        // A drag is a swipe.
        await tester.dragFrom(box.center, const Offset(0, -80));
        await _settle(tester);
        expect(inputs.last['action'], 'swipe');
        expect((inputs.last['y2'] as int) < (inputs.last['y'] as int), isTrue);
        // The camera hands the frame to the composer.
        await tester.tap(find.byIcon(Icons.photo_camera_outlined));
        await _settle(tester);
        expect(attached, isNotNull);
        expect(attached!.name, 'frame-1.jpg');
        expect(attached!.mime, 'image/jpeg');
        expect(tester.takeException(), isNull);
        await states.close();
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
