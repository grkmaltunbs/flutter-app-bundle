// The run bay's pure half: the daemon protocol, the default device, the
// state both devices share, the lines, and the log ring.
import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

void main() {
  test('daemon lines: an event, a response, and the app\'s own output', () {
    final e = parseDaemonLine('[{"event":"app.debugPort","params":{"appId":"a1","port":63082,"wsUri":"ws://127.0.0.1:63082/x=/ws"}}]');
    expect(e, isA<DaemonEvent>());
    expect((e as DaemonEvent).event, 'app.debugPort');
    expect(e.params['wsUri'], 'ws://127.0.0.1:63082/x=/ws');
    final r = parseDaemonLine('[{"id":1,"result":{"code":0,"message":"Reloaded 0 libraries"}}]') as DaemonResponse;
    expect(r.id, 1);
    expect((r.result as Map)['message'], 'Reloaded 0 libraries');
    expect((parseDaemonLine('[{"id":3,"result":true}]') as DaemonResponse).result, isTrue);
    expect(parseDaemonLine('Launching lib/main.dart on macOS in debug mode...'), isNull);
    expect(parseDaemonLine('[not json'), isNull);
    expect(parseDaemonLine('[]'), isNull);
    expect(encodeDaemonCommand(2, 'app.restart', {'appId': 'a1', 'fullRestart': true}), '[{"id":2,"method":"app.restart","params":{"appId":"a1","fullRestart":true}}]');
    expect(dtdUriIn('The Dart Tooling Daemon is available at: ws://127.0.0.1:63081/bRW='), 'ws://127.0.0.1:63081/bRW=');
    expect(dtdUriIn('Reloaded 0 libraries'), isNull);
  });

  test('the device list and the default for a runtime', () {
    final sim = RunDevice.fromFlutter(const {'id': '022B', 'name': 'iPhone 17 Pro', 'targetPlatform': 'ios', 'emulator': true});
    final phone = RunDevice.fromFlutter(const {'id': '46ee', 'name': '2512BPNDAG', 'targetPlatform': 'android-arm64', 'emulator': false});
    final mac = RunDevice.fromFlutter(const {'id': 'macos', 'name': 'macOS', 'targetPlatform': 'darwin', 'emulator': false});
    const off = RunDevice(id: 'okey_test', name: 'okey_test', platform: 'android', emulator: true, off: true);
    expect(sim.kind, 'ios');
    expect(phone.kind, 'android');
    expect(mac.kind, 'macos');
    final all = [phone, sim, mac, off];
    expect(defaultDevice(all, 'ios-simulator')!.id, '022B');
    expect(defaultDevice(all, 'android')!.id, '46ee');
    expect(defaultDevice(all, 'macos')!.id, 'macos');
    expect(defaultDevice(all, null)!.id, '46ee', reason: 'the first booted device');
    expect(defaultDevice([off, mac], 'android-emulator')!.id, 'okey_test', reason: 'an emulator that is off still fits');
    expect(defaultDevice(const [], 'macos'), isNull);
    expect(RunDevice.fromMap(off.toMap()).off, isTrue);
  });

  test('the state round-trips with every key, and the lines read right', () {
    final since = DateTime.utc(2026, 9, 6, 0, 0);
    final r = RunState(phase: RunPhase.running, runId: 'r1', device: '022B', deviceName: 'iPhone 17 Pro', appId: 'a1', since: since, vmUri: 'ws://vm', dtdUri: 'ws://dtd', exceptions: 2, lastError: 'boom', lines: 40, reloadOnEdit: true, devices: const [RunDevice(id: 'macos', name: 'macOS', platform: 'darwin')]);
    final m = r.toMap();
    expect(m.keys, containsAll(['phase', 'runId', 'device', 'deviceName', 'appId', 'since', 'vmUri', 'dtdUri', 'error', 'exceptions', 'lastError', 'lines', 'reloadOnEdit', 'devices', 'devicesAt']));
    expect(m['error'], isNull, reason: 'null, not absent — the session document is merged');
    final back = RunState.fromMap(m);
    expect(back.phase, RunPhase.running);
    expect(back.deviceName, 'iPhone 17 Pro');
    expect(back.dtdUri, 'ws://dtd');
    expect(back.exceptions, 2);
    expect(back.devices.single.id, 'macos');
    expect(back.reloadOnEdit, isTrue);
    expect(runLine(back, now: since.add(const Duration(minutes: 4))), 'Running · iPhone 17 Pro · 4 min · 2 exceptions');
    expect(runLine(back.copyWith(exceptions: 0), now: since.add(const Duration(seconds: 20))), 'Running · iPhone 17 Pro · just now', reason: 'a count given is taken; one left out is kept');
    expect(runLine(RunState.fromMap({...m, 'exceptions': 0}), now: since.add(const Duration(minutes: 75))), 'Running · iPhone 17 Pro · 1 h 15 min');
    expect(runLine(const RunState()), isNull);
    expect(runLine(const RunState(phase: RunPhase.starting, deviceName: 'macOS')), 'Starting · macOS');
    expect(runLine(const RunState(phase: RunPhase.failed, error: 'no device')), 'Failed · no device');
    expect(runLine(const RunState(phase: RunPhase.stopped, deviceName: 'macOS')), 'Stopped · macOS');
    final fresh = r.copyWith(clear: true, phase: RunPhase.idle);
    expect(fresh.appId, isNull);
    expect(fresh.exceptions, 0);
    expect(fresh.devices.length, 1, reason: 'the device list outlives a run');
    expect(fresh.reloadOnEdit, isTrue, reason: 'so does the switch');
  });

  test('the brief names the URIs while a run is up', () {
    expect(runBrief(const RunState()), contains('no app is running'));
    final b = runBrief(const RunState(phase: RunPhase.running, deviceName: 'iPhone 17 Pro', vmUri: 'ws://vm', dtdUri: 'ws://dtd'));
    expect(b, contains('already running from the Mac on iPhone 17 Pro'));
    expect(b, contains('ws://dtd'));
    expect(b, contains('Do not start a second `flutter run`'));
  });

  test('the log keeps the last lines and says what is new', () {
    final log = RunLog(keep: 5);
    for (var i = 0; i < 8; i++) {
      log.add('line $i');
    }
    expect(log.seq, 8);
    expect(log.length, 5);
    expect(log.lines.first, 'line 3');
    final (from, lines) = log.since(6);
    expect(from, 6);
    expect(lines, ['line 6', 'line 7']);
    final (from0, all) = log.since(0);
    expect(from0, 3, reason: 'what was dropped cannot be given');
    expect(all.length, 5);
    log.clear();
    expect(log.seq, 0);
  });
}
