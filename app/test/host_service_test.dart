// The host as a service: the heartbeat the phone reads, what the phone
// says about it, the power hold on a running process, the login item, and
// a send that waits on a Mac that is gone.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/host_presence.dart';
import 'package:kit_app/src/host/login_item.dart';
import 'package:kit_app/src/host/power.dart';
import 'package:kit_app/src/presence.dart';
import 'package:kit_app/src/relay.dart';

Future<void> _settle([int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeProcess implements Process {
  _FakeProcess(this.pid);
  @override
  final int pid;
  final _exit = Completer<int>();
  bool killed = false;
  @override
  Future<int> get exitCode => _exit.future;
  void exit(int code) => _exit.complete(code);
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exit.isCompleted) _exit.complete(-15);
    return true;
  }

  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  IOSink get stdin => throw UnimplementedError();
}

void main() {
  final now = DateTime.utc(2026, 9, 4, 10, 0, 0);

  test('a Mac is its hostname made safe; the phone reads online, unreachable, stopped or unknown from the row and the clock', () {
    expect(hostIdFor('MacBook-Pro.local'), 'macbook-pro-local');
    expect(hostIdFor('  '), 'mac');
    expect(HostPresenceView.from(null, now: now).state, HostState.unknown);
    expect(HostPresenceView.from({'name': 'x'}, now: now).line, 'Mac · no heartbeat yet');
    final fresh = HostPresenceView.from({'seenAt': Timestamp.fromDate(now.subtract(const Duration(seconds: 12))), 'stopping': false}, now: now);
    expect(fresh.state, HostState.online);
    expect(fresh.line, 'Mac · 12 s ago');
    expect(fresh.warn, isFalse);
    expect(HostPresenceView.from({'seenAt': Timestamp.fromDate(now.subtract(const Duration(seconds: 90)))}, now: now).state, HostState.online, reason: 'three missed beats, not one slow write');
    final gone = HostPresenceView.from({'seenAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 4, seconds: 10)))}, now: now);
    expect(gone.state, HostState.unreachable);
    expect(gone.line, 'Mac unreachable since 4 min');
    expect(gone.warn, isTrue);
    expect(gone.gone, isTrue);
    final stopped = HostPresenceView.from({'seenAt': Timestamp.fromDate(now), 'stopping': true}, now: now);
    expect(stopped.state, HostState.stopped);
    expect(stopped.line, 'Mac stopped');
    expect(HostPresenceView.from({'seenAt': Timestamp.fromDate(now.add(const Duration(seconds: 30)))}, now: now).line, 'Mac · 0 s ago', reason: 'a server clock ahead of the phone reads as now');
    expect(agoShort(const Duration(hours: 3)), '3 h');
    expect(agoShort(const Duration(days: 3)), '3 d');
  });

  test('the host beats its row every period with the projects and their sessions; a clean quit says stopping', () async {
    final db = FakeFirebaseFirestore();
    var running = false;
    final p = HostPresence(db: db, machine: 'MacBook-Pro.local', period: const Duration(milliseconds: 30), now: () => now, sessions: () => {'nahmatik': running, 'kit': false})
      ..appVersion = '1.0.0+1'
      ..cli = '2.1.259';
    addTearDown(p.dispose);
    expect(p.status, contains('not yet'));
    p.start();
    expect(p.running, isTrue);
    await _settle();
    var d = (await db.collection('hosts').doc('macbook-pro-local').get()).data()!;
    expect(d['name'], 'MacBook-Pro.local');
    expect(d['appVersion'], '1.0.0+1');
    expect(d['cli'], '2.1.259');
    expect(d['projects'], ['nahmatik', 'kit']);
    expect(d['sessions'], {'nahmatik': false, 'kit': false});
    expect(d['stopping'], isFalse);
    expect(d['seenAt'], isNotNull);
    expect(p.lastBeat, now);
    expect(p.status, contains('hosts/macbook-pro-local'));
    running = true;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(p.beats, greaterThanOrEqualTo(2));
    d = (await db.collection('hosts').doc('macbook-pro-local').get()).data()!;
    expect((d['sessions'] as Map)['nahmatik'], isTrue, reason: 'each beat reads the sessions afresh');
    p.start();
    await p.stop();
    expect(p.running, isFalse);
    d = (await db.collection('hosts').doc('macbook-pro-local').get()).data()!;
    expect(d['stopping'], isTrue);
    expect(d['name'], 'MacBook-Pro.local', reason: 'the goodbye merges, the row stays whole');
    final beats = p.beats;
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(p.beats, beats, reason: 'no beat after stop');
  });

  test('a power hold is one caffeinate per pid, released by hand or when the process ends', () async {
    final started = <List<String>>[];
    final procs = <_FakeProcess>[];
    var nextPid = 900;
    final hold = PowerHold(starter: (exe, args) async {
      started.add([exe, ...args]);
      final p = _FakeProcess(nextPid++);
      procs.add(p);
      return p;
    });
    expect(hold.holding, isFalse);
    expect(hold.status, contains('nothing runs'));
    await Future.wait([hold.hold(41), hold.hold(41)]);
    expect(started, [['caffeinate', '-is', '-w', '41']], reason: 'twice at once is one');
    expect(hold.holding, isTrue);
    expect(hold.count, 1);
    expect(hold.status, contains('1 process '));
    await hold.hold(42);
    expect(hold.pids, {41, 42});
    hold.release(41);
    expect(procs[0].killed, isTrue);
    expect(hold.pids, {42});
    hold.release(41);
    // The process ended on its own: caffeinate -w exits and the hold goes.
    procs[1].exit(0);
    await _settle();
    expect(hold.holding, isFalse);
    await hold.hold(43);
    hold.releaseAll();
    expect(procs[2].killed, isTrue);
    expect(hold.holding, isFalse);

    final broken = PowerHold(starter: (_, _) async => throw const ProcessException('caffeinate', [], 'no such file'));
    await broken.hold(1);
    expect(broken.holding, isFalse);
    expect(broken.status, contains('Could not hold'));
  });

  test('the login item is a LaunchAgent that runs the app at login and after a crash; enable writes it, disable unloads and removes it', () async {
    final home = Directory.systemTemp.createTempSync('kit-login-');
    addTearDown(() => home.deleteSync(recursive: true));
    final ran = <List<String>>[];
    final item = LoginItem(
      home: home.path,
      executable: '/Users/ren/Applications/kit_app.app/Contents/MacOS/kit_app',
      run: (exe, args) async {
        ran.add([exe, ...args]);
        return ProcessResult(0, 0, exe == 'id' ? '501\n' : '', '');
      },
    );
    expect(item.enabled, isFalse);
    expect(item.status, contains('Off'));
    expect(await item.enable(), isTrue);
    expect(item.enabled, isTrue);
    final plist = item.plist.readAsStringSync();
    expect(item.plist.path, '${home.path}/Library/LaunchAgents/dev.flutterkit.kitApp.plist');
    expect(plist, contains('<string>dev.flutterkit.kitApp</string>'));
    expect(plist, contains('<string>/Users/ren/Applications/kit_app.app/Contents/MacOS/kit_app</string>'));
    expect(plist, contains('<key>RunAtLoad</key>\n  <true/>'));
    expect(plist, contains('<key>SuccessfulExit</key>\n    <false/>'), reason: 'back after a crash, not after a Quit');
    expect(plist, contains('${home.path}/.flutter_kit/host.log'));
    expect(ran.map((r) => r.join(' ')), contains('launchctl enable gui/501/dev.flutterkit.kitApp'));
    expect(ran.any((r) => r.contains('bootstrap')), isFalse, reason: 'bootstrapping now would start a second copy');
    expect(item.status, contains('On'));
    expect(await item.disable(), isTrue);
    expect(item.enabled, isFalse);
    expect(ran.last, ['launchctl', 'bootout', 'gui/501/dev.flutterkit.kitApp']);
    expect(LoginItem.plistFor(executable: '/a/b & c', logPath: '/l'), contains('/a/b &amp; c'));
  });

  test('a send while the Mac is gone is queued and can be withdrawn; Start on a stopped Mac is refused; a Mac that is back clears it', () async {
    final db = FakeFirebaseFirestore();
    final project = db.collection('projects').doc('demo');
    await project.set({'name': 'Demo', 'machine': 'MacBook-Pro.local', 'session': {'mode': 'bridge', 'state': 'ready', 'sessionId': 's1', 'canResume': false, 'pendingAsks': 0}});
    final hosts = db.collection('hosts').doc('macbook-pro-local');
    await hosts.set({'seenAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))), 'stopping': false});
    var clock = now;
    final deck = RemoteDeck(db, 'demo', now: () => clock, tick: const Duration(hours: 1))..start();
    addTearDown(deck.dispose);
    await _settle();
    expect(deck.presence.state, HostState.unreachable);
    expect(deck.presence.line, 'Mac unreachable since 5 min');
    expect(deck.running, isTrue, reason: 'the relay still says live — the deck shows LOST from presence.gone');
    expect(deck.presence.gone, isTrue);

    await deck.send('hello?');
    await _settle();
    expect(deck.echoes, hasLength(1));
    final echoId = deck.echoes.single.id;
    expect(deck.queued, {echoId});
    var cmds = await project.collection('commands').get();
    expect(cmds.docs, hasLength(1));
    expect(cmds.docs.single.data()['doneAt'], isNull);

    await deck.withdraw(echoId);
    expect(deck.echoes, isEmpty);
    expect(deck.queued, isEmpty);
    cmds = await project.collection('commands').get();
    expect(cmds.docs, isEmpty, reason: 'the Mac never sees it');

    await deck.send('again');
    await _settle();
    final second = deck.echoes.single.id;
    expect(deck.queued, {second});
    // The Mac comes back: the row is fresh, nothing is queued any more.
    await hosts.set({'seenAt': Timestamp.fromDate(now), 'stopping': false});
    await _settle();
    expect(deck.presence.state, HostState.online);
    expect(deck.queued, isEmpty);
    // The host stamps it: withdraw is a no-op afterwards.
    final ref = (await project.collection('commands').get()).docs.single.reference;
    await ref.set({'doneAt': '2026-09-04T10:00:05Z', 'result': 'sent'}, SetOptions(merge: true));
    await _settle();
    await deck.withdraw(second);
    expect((await project.collection('commands').get()).docs, hasLength(1));

    // Time passes with no beat: the line ages, then the Mac is gone again.
    clock = now.add(const Duration(minutes: 3));
    expect(deck.presence.line, 'Mac unreachable since 3 min');

    await hosts.set({'seenAt': Timestamp.fromDate(clock), 'stopping': true});
    await _settle();
    expect(deck.presence.state, HostState.stopped);
    final before = (await project.collection('commands').get()).docs.length;
    await deck.startSession();
    expect(deck.error, contains('stopped'));
    expect((await project.collection('commands').get()).docs.length, before, reason: 'no start command for a Mac that quit');

    await hosts.set({'seenAt': Timestamp.fromDate(now), 'stopping': false});
    await _settle();
    clock = now.add(const Duration(minutes: 10));
    await deck.startSession();
    expect(deck.error, contains('queued'));
    expect((await project.collection('commands').get()).docs.length, before + 1, reason: 'unreachable is not stopped: the start waits for the Mac');
    expect(jsonEncode(deck.hostDoc!['stopping']), 'false');

    // Stop follows the same rule: refused on a stopped Mac, queued on an unreachable one.
    await hosts.set({'seenAt': Timestamp.fromDate(clock), 'stopping': true});
    await _settle();
    final count = (await project.collection('commands').get()).docs.length;
    await deck.stopSession();
    expect(deck.error, contains('nothing is running'));
    expect((await project.collection('commands').get()).docs.length, count);
    await hosts.set({'seenAt': Timestamp.fromDate(now), 'stopping': false});
    await _settle();
    await deck.stopSession();
    expect(deck.error, contains('Stop is queued'));
    expect((await project.collection('commands').get()).docs.length, count + 1);
  });
}
