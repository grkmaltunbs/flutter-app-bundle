import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;

import 'bridge_session.dart' show ProcessStarter;
import 'claude_cli.dart';

typedef CommandRunner = Future<ProcessResult> Function(String executable, List<String> args, {String? workingDirectory, Map<String, String>? environment});

Future<Process> _startProcess(String executable, List<String> args, {String? workingDirectory, Map<String, String>? environment}) =>
    Process.start(executable, args, workingDirectory: workingDirectory, environment: environment);

Future<ProcessResult> _runCommand(String executable, List<String> args, {String? workingDirectory, Map<String, String>? environment}) =>
    Process.run(executable, args, workingDirectory: workingDirectory, environment: environment);

/// The run bay: the host owns the app under test. `flutter run -d`
/// `<device> --machine --print-dtd` in the project folder, spoken to over the
/// daemon protocol IDEs use — `app.start`, `app.debugPort`, `app.dtd`,
/// `app.started` and `app.progress` in (proven 2026-09-06 on Flutter's
/// daemon 0.6.1), `app.restart {appId, fullRestart}` and `app.stop` out.
/// Plain lines on stdout and stderr are the app's own output and go to
/// the [log]; a line that reads like an exception counts one. No model,
/// no quota. Reload on edit watches `lib/` and hot-reloads on a save.
class RunBay extends ChangeNotifier {
  RunBay({
    required this.dir,
    this.runtime,
    ProcessStarter? starter,
    CommandRunner? runner,
    Future<String> Function()? shellPath,
    this.findBinary,
    DateTime Function()? now,
    this.bootWait = const Duration(seconds: 90),
    this.pollEvery = const Duration(seconds: 3),
    this.editDebounce = const Duration(milliseconds: 400),
  })  : _starter = starter ?? _startProcess,
        _runner = runner ?? _runCommand,
        _shellPath = shellPath ?? ClaudeCli.shellPath,
        _now = now ?? DateTime.now;

  final String dir;

  /// What the plan's `qa.runtime` names — the default device's class.
  final String? Function()? runtime;
  final ProcessStarter _starter;
  final CommandRunner _runner;
  final Future<String> Function() _shellPath;
  /// Where a tool is, for a test; the shell PATH otherwise.
  final String? Function(String name)? findBinary;
  final DateTime Function() _now;
  final Duration bootWait;
  final Duration pollEvery;
  final Duration editDebounce;

  RunState state = const RunState();

  /// The last two thousand lines the run wrote.
  final RunLog log = RunLog();

  Process? _proc;
  StreamSubscription<String>? _out;
  StreamSubscription<String>? _err;
  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _editTimer;
  int _seq = 0;
  final Map<int, Completer<DaemonResponse>> _waits = {};

  bool get up => state.up;

  /// The log as it grows — what the Mac's own log sheet follows; the
  /// phone follows the relay's documents instead.
  Stream<List<String>> get logStream => _logCtrl.stream;
  final StreamController<List<String>> _logCtrl = StreamController<List<String>>.broadcast();

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_logCtrl.hasListener) _logCtrl.add(log.lines);
  }

  Future<Map<String, String>> _env() async => {...Platform.environment, 'PATH': await _shellPath()};

  /// A GUI app's PATH has no Flutter SDK; the user's shell PATH does.
  Future<String> _flutter() async {
    final found = findBinary?.call('flutter');
    if (found != null) return found;
    for (final d in (await _shellPath()).split(':')) {
      final f = File(p.join(d, 'flutter'));
      if (f.existsSync()) return f.path;
    }
    return 'flutter';
  }

  /// `flutter devices --machine`, plus the emulators `flutter emulators`
  /// knows that are not booted. The list rides on the state.
  Future<List<RunDevice>> devices() async {
    final env = await _env();
    final bin = await _flutter();
    final out = <RunDevice>[];
    try {
      final r = await _runner(bin, ['devices', '--machine'], workingDirectory: dir, environment: env).timeout(const Duration(seconds: 60));
      final text = r.stdout.toString();
      final start = text.indexOf('[');
      if (start >= 0) {
        final raw = jsonDecode(text.substring(start));
        if (raw is List) {
          for (final d in raw) {
            if (d is Map) out.add(RunDevice.fromFlutter({for (final e in d.entries) e.key.toString(): e.value as Object?}));
          }
        }
      }
    } on Object catch (e) {
      _logLine('flutter devices failed: $e', err: true);
    }
    try {
      final r = await _runner(bin, ['emulators'], workingDirectory: dir, environment: env).timeout(const Duration(seconds: 30));
      for (final line in r.stdout.toString().split('\n')) {
        final parts = line.split('•').map((s) => s.trim()).toList();
        if (parts.length < 4 || parts[0].isEmpty || parts[0] == 'Id') continue;
        final kind = parts[3].toLowerCase();
        // A kind that already has a booted emulator needs no second one.
        if (out.any((d) => d.emulator && !d.off && d.kind == kind)) continue;
        out.add(RunDevice(id: parts[0], name: parts[1], platform: kind, emulator: true, off: true));
      }
    } on Object {
      // No emulators listed — the devices are what there is.
    }
    state = state.copyWith(devices: out, devicesAt: _now());
    notifyListeners();
    return out;
  }

  /// Starts the app on [device] — the plan's default when null — booting
  /// an emulator first when the pick is one that is off. Returns the one
  /// line to toast.
  Future<String> start({String? device}) async {
    if (state.up) return 'already ${state.phase.name} on ${state.deviceName ?? state.device}';
    final list = state.devices.isEmpty || device == null ? await devices() : state.devices;
    RunDevice? d;
    if (device == null) {
      d = defaultDevice(list, runtime?.call());
    } else {
      d = list.where((x) => x.id == device).firstOrNull ?? RunDevice(id: device, name: device);
    }
    if (d == null) return _fail('no device to run on — plug one in, or boot a simulator');
    final runId = 'r${_now().toUtc().millisecondsSinceEpoch ~/ 1000}';
    log.clear();
    state = RunState(phase: RunPhase.starting, runId: runId, device: d.id, deviceName: d.name, reloadOnEdit: state.reloadOnEdit, devices: list, devicesAt: state.devicesAt);
    notifyListeners();
    final env = await _env();
    final bin = await _flutter();
    if (d.off) {
      _logLine('Booting ${d.name}…');
      final booted = await _boot(d, bin, env);
      if (booted == null) return _fail('${d.name} did not come up in ${bootWait.inSeconds} s');
      d = booted;
      state = state.copyWith(device: d.id, deviceName: d.name);
      notifyListeners();
    }
    _logLine('flutter run -d ${d.id} --machine --print-dtd');
    try {
      _proc = await _starter(bin, ['run', '-d', d.id, '--machine', '--print-dtd'], workingDirectory: dir, environment: env);
    } on ProcessException catch (e) {
      return _fail('could not start flutter: ${e.message}');
    }
    _out = _proc!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((l) => _line(l));
    _err = _proc!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((l) => _line(l, err: true));
    final spawned = _proc;
    unawaited(_proc!.exitCode.then((c) {
      if (identical(_proc, spawned)) _exited(c);
    }));
    return 'starting on ${d.name}';
  }

  /// `flutter emulators --launch <id>`, then the device list until one
  /// of that kind is booted.
  Future<RunDevice?> _boot(RunDevice d, String bin, Map<String, String> env) async {
    try {
      await _runner(bin, ['emulators', '--launch', d.id], workingDirectory: dir, environment: env).timeout(const Duration(seconds: 60));
    } on Object catch (e) {
      _logLine('could not launch ${d.id}: $e', err: true);
      return null;
    }
    final end = _now().add(bootWait);
    while (_now().isBefore(end)) {
      await Future<void>.delayed(pollEvery);
      final list = await devices();
      final booted = list.where((x) => !x.off && x.emulator && x.kind == d.kind).firstOrNull;
      if (booted != null) return booted;
    }
    return null;
  }

  String _fail(String why) {
    state = state.copyWith(phase: RunPhase.failed, error: why);
    _logLine(why, err: true);
    notifyListeners();
    return why;
  }

  void _line(String raw, {bool err = false}) {
    final l = parseDaemonLine(raw);
    if (l == null) {
      final dtd = dtdUriIn(raw);
      if (dtd != null) state = state.copyWith(dtdUri: dtd);
      _logLine(raw, err: err);
      notifyListeners();
      return;
    }
    switch (l) {
      case DaemonEvent(:final event, :final params):
        switch (event) {
          case 'app.start':
            state = state.copyWith(appId: params['appId']?.toString());
          case 'app.debugPort':
            state = state.copyWith(vmUri: params['wsUri']?.toString());
          case 'app.dtd':
            state = state.copyWith(dtdUri: params['uri']?.toString());
          case 'app.started':
            state = state.copyWith(phase: RunPhase.running, since: _now());
            _logLine('Running on ${state.deviceName}.');
            _armWatch();
          case 'app.progress':
            final m = params['message']?.toString();
            if (m != null && m.isNotEmpty && params['finished'] != true) _logLine(m);
          case 'app.log':
            _logLine((params['log'] ?? '').toString(), err: params['error'] == true);
          case 'app.stop':
            state = state.copyWith(phase: RunPhase.stopped);
          case 'daemon.logMessage':
            final m = params['message']?.toString() ?? '';
            if (m.isNotEmpty && params['level'] == 'error') _logLine(m, err: true);
        }
      case DaemonResponse(:final id):
        _waits.remove(id)?.complete(l);
    }
    notifyListeners();
  }

  /// A line into the log; one that reads like an exception lights the
  /// pill and is kept as the last error.
  void _logLine(String line, {bool err = false}) {
    final t = line.trimRight();
    if (t.isEmpty) return;
    log.add(t);
    final exception = t.contains('EXCEPTION CAUGHT') || t.contains('Unhandled Exception') || (err && t.contains('Exception'));
    state = state.copyWith(lines: log.seq, exceptions: exception ? state.exceptions + 1 : null, lastError: exception ? t : null);
  }

  Future<DaemonResponse> _send(String method, Map<String, Object?> params) {
    final proc = _proc;
    if (proc == null) return Future.error(StateError('not running'));
    final id = ++_seq;
    final c = Completer<DaemonResponse>();
    _waits[id] = c;
    try {
      proc.stdin.writeln(encodeDaemonCommand(id, method, params));
    } on Object catch (e) {
      _waits.remove(id);
      return Future.error(e);
    }
    return c.future;
  }

  /// Hot reload — or, [full], a hot restart. Returns the daemon's word.
  Future<String> reload({bool full = false}) async {
    final appId = state.appId;
    if (!state.running || appId == null) return 'not running';
    try {
      final r = await _send('app.restart', {'appId': appId, 'fullRestart': full, 'reason': 'manual'}).timeout(const Duration(seconds: 120));
      final res = r.result;
      final m = res is Map ? res : const {};
      final code = (m['code'] as num?)?.toInt() ?? 0;
      final msg = (m['message'] ?? '').toString();
      if (r.error != null) return 'failed: ${r.error}';
      if (code != 0) return 'failed: ${msg.isEmpty ? 'code $code' : msg}';
      return full ? 'restarted' : (msg.isEmpty ? 'reloaded' : msg.toLowerCase());
    } on TimeoutException {
      return 'no answer from flutter in 120 s';
    } on Object catch (e) {
      return 'failed: $e';
    }
  }

  /// `app.stop`, then the process; killed after eight seconds.
  Future<String> stop() async {
    final proc = _proc;
    if (proc == null) return 'not running';
    final appId = state.appId;
    if (appId != null && state.running) {
      try {
        await _send('app.stop', {'appId': appId}).timeout(const Duration(seconds: 10));
      } on Object {
        // The process goes next either way.
      }
    }
    try {
      await proc.exitCode.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      proc.kill(ProcessSignal.sigterm);
      try {
        await proc.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        proc.kill(ProcessSignal.sigkill);
      }
    }
    return 'stopped';
  }

  void _exited(int code) {
    _proc = null;
    _out?.cancel();
    _err?.cancel();
    _disarmWatch();
    for (final w in _waits.values) {
      if (!w.isCompleted) w.completeError(StateError('the process ended'));
    }
    _waits.clear();
    final wasStarting = state.phase == RunPhase.starting;
    final last = log.lines.isEmpty ? '' : log.lines.last;
    state = state.copyWith(
      phase: wasStarting ? RunPhase.failed : RunPhase.stopped,
      error: wasStarting ? 'flutter run exited with code $code${last.isEmpty ? '' : ' — $last'}' : null,
    );
    _logLine('Process exited ($code).');
    notifyListeners();
  }

  // --- reload on edit --------------------------------------------------

  bool get reloadOnEdit => state.reloadOnEdit;

  void setReloadOnEdit(bool on) {
    state = state.copyWith(reloadOnEdit: on);
    if (on) {
      _armWatch();
    } else {
      _disarmWatch();
    }
    notifyListeners();
  }

  /// Watches `lib/` while the app runs and reload-on-edit is on; a burst
  /// of saves becomes one reload.
  void _armWatch() {
    if (!state.reloadOnEdit || !state.running || _watch != null) return;
    final lib = Directory(p.join(dir, 'lib'));
    if (!lib.existsSync()) return;
    _watch = lib.watch(recursive: true).listen((_) {
      _editTimer?.cancel();
      _editTimer = Timer(editDebounce, () async {
        _editTimer = null;
        if (!state.running) return;
        _logLine('Reload on edit…');
        notifyListeners();
        final r = await reload();
        _logLine('Reload on edit: $r');
        notifyListeners();
      });
    });
  }

  void _disarmWatch() {
    _watch?.cancel();
    _watch = null;
    _editTimer?.cancel();
    _editTimer = null;
  }

  @override
  void dispose() {
    _disarmWatch();
    _out?.cancel();
    _err?.cancel();
    // Let go of the process before the kill: its exit must not report
    // to a notifier that is gone.
    final proc = _proc;
    _proc = null;
    proc?.kill(ProcessSignal.sigterm);
    _logCtrl.close();
    super.dispose();
  }
}
