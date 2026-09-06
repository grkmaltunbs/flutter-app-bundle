import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;

import '../blobs.dart';
import 'claude_cli.dart';
import 'run_bay.dart';

/// The mirror: the run bay's device on the phone. A frame is `xcrun`
/// `simctl io` `screenshot` of a simulator, `adb exec-out screencap`
/// for an Android device or emulator, `screencapture` of the app's
/// window for a macOS run — shrunk with `sips` to a 720 px long edge as
/// JPEG and put at `projects/{slug}/frames/live.jpg`; the project
/// document's `mirror` ticks. One frame on demand; one a second while a
/// phone's sheet says it is watching (its heartbeat on the document —
/// a sheet left open on a locked phone goes quiet and the stream stops).
/// Input — tap, swipe, text, key in device pixels — plays through `adb
/// shell input` or `idb ui`, and the next frame follows at once.
class Mirror extends ChangeNotifier {
  Mirror({
    required this.run,
    required this.blobs,
    required this.slug,
    this.publish,
    this.dir,
    CommandRunner? runner,
    Future<String> Function()? shellPath,
    this.findBinary,
    this.shrink,
    DateTime Function()? now,
    this.period = const Duration(seconds: 1),
    this.stale = watchStale,
    Directory? tmp,
  })  : _runner = runner ?? _runCommand,
        _shellPath = shellPath ?? ClaudeCli.shellPath,
        _now = now ?? DateTime.now,
        _tmp = tmp ?? Directory.systemTemp;

  final RunBay run;

  /// The bucket the frames go to; null in a test without one — frames
  /// then stay in [lastFrame] only.
  final BlobStore? blobs;
  final String? Function() slug;

  /// Writes the host's half of `mirror` on the project document.
  final Future<void> Function(Map<String, Object?> mirror)? publish;

  /// The project folder — its pubspec names the macOS app's process.
  final String? dir;
  final CommandRunner _runner;
  final Future<String> Function() _shellPath;
  final String? Function(String name)? findBinary;

  /// PNG bytes → JPEG bytes with the long edge at [frameLongEdge];
  /// `sips` on the Mac, or a test's stand-in.
  final Future<Uint8List> Function(Uint8List png)? shrink;
  final DateTime Function() _now;
  final Duration period;
  final Duration stale;
  final Directory _tmp;

  MirrorState state = const MirrorState();

  /// The newest frame's bytes — the Mac's own sheet reads these.
  Uint8List? lastFrame;
  DateTime? _watchingAt;
  Timer? _ticker;
  bool _busy = false;
  double? _scale;
  String? _scaleFor;

  bool get streaming => state.streaming;

  Future<Map<String, String>> _env() async => {...Platform.environment, 'PATH': await _shellPath()};

  Future<String> _bin(String name) async {
    final found = findBinary?.call(name);
    if (found != null) return found;
    for (final d in (await _shellPath()).split(':')) {
      final f = File(p.join(d, name));
      if (f.existsSync()) return f.path;
    }
    return name;
  }

  Future<bool> _has(String name) async {
    if (findBinary != null) return findBinary!(name) != null;
    for (final d in (await _shellPath()).split(':')) {
      if (File(p.join(d, name)).existsSync()) return true;
    }
    return false;
  }

  /// The phone's heartbeat, as the host reads it off the document.
  void watching(DateTime? at, String? by) {
    _watchingAt = at;
    _arm();
  }

  bool get _watched => _watchingAt != null && _now().difference(_watchingAt!) < stale;

  /// One frame a second while a sheet is open and the app runs.
  void _arm() {
    if (_watched && run.state.up) {
      _ticker ??= Timer.periodic(period, (_) => _tick());
      if (!state.streaming) {
        state = state.copyWith(streaming: true);
        _publishState();
      }
      unawaited(_tick());
    } else {
      _disarm();
    }
  }

  void _disarm() {
    _ticker?.cancel();
    _ticker = null;
    if (state.streaming) {
      state = state.copyWith(streaming: false);
      _publishState();
    }
  }

  Future<void> _tick() async {
    if (!_watched || !run.state.up) {
      _disarm();
      return;
    }
    await frame();
  }

  /// Stops the stream — the run ended, the host quits.
  void stop() => _disarm();

  bool _disposed = false;

  void _publishState() {
    if (_disposed) return; // a frame still in flight when the host let go
    notifyListeners();
    final pub = publish;
    if (pub != null) unawaited(pub(state.toMap()).catchError((Object _) {}));
  }

  /// One frame now: captured, shrunk, put up, the document ticked.
  /// Returns the one line to toast.
  Future<String> frame() async {
    if (_busy) return 'a frame is on its way';
    final r = run.state;
    if (!r.up || r.device == null) return _fail('nothing is running');
    _busy = true;
    try {
      final png = await _capture(r);
      final size = pngSize(png);
      if (size == null) return _fail('the capture was not a PNG');
      final (dw, dh) = size;
      final jpg = await (shrink ?? _sips)(png);
      final (w, h) = fitLongEdge(dw, dh);
      lastFrame = jpg;
      final s = slug();
      final store = blobs;
      if (store != null && s != null) await store.put(framePath(s), jpg, contentType: 'image/jpeg');
      state = state.copyWith(seq: state.seq + 1, at: _now(), w: w, h: h, dw: dw, dh: dh, clearError: true);
      _publishState();
      return 'frame ${state.seq} · $w×$h';
    } on Object catch (e) {
      return _fail('capture failed: $e');
    } finally {
      _busy = false;
    }
  }

  String _fail(String why) {
    state = state.copyWith(error: why);
    _publishState();
    return why;
  }

  Future<Uint8List> _capture(RunState r) async {
    final env = await _env();
    final file = File(p.join(_tmp.path, 'kit-mirror-${DateTime.now().microsecondsSinceEpoch}.png'));
    try {
      final device = RunDevice(id: r.device!, name: r.deviceName ?? '', platform: r.devices.where((d) => d.id == r.device).firstOrNull?.platform ?? '');
      final kind = device.platform.isEmpty ? _guessKind(r) : device.kind;
      final ProcessResult res;
      switch (kind) {
        case 'ios':
          res = await _runner('xcrun', ['simctl', 'io', r.device!, 'screenshot', '--type=png', file.path], environment: env).timeout(const Duration(seconds: 15));
        case 'android':
          res = await _runner('/bin/sh', ['-c', '"${await _bin('adb')}" -s "${r.device}" exec-out screencap -p > "${file.path}"'], environment: env).timeout(const Duration(seconds: 15));
        case 'macos':
          final bounds = await _macWindow(env);
          if (bounds == null) throw StateError('the app window was not found');
          res = await _runner('screencapture', ['-x', '-R', bounds, file.path], environment: env).timeout(const Duration(seconds: 15));
        default:
          throw StateError('no capture for a $kind run');
      }
      final err = res.stderr.toString().trim();
      if (res.exitCode != 0 || !file.existsSync()) throw StateError(err.isEmpty ? 'exit ${res.exitCode}' : err);
      return file.readAsBytesSync();
    } finally {
      if (file.existsSync()) file.deleteSync();
    }
  }

  String _guessKind(RunState r) {
    final id = r.device ?? '';
    if (id == 'macos') return 'macos';
    if (RegExp(r'^[0-9A-F-]{36}$').hasMatch(id)) return 'ios';
    return 'android';
  }

  /// The macOS app's window, by the pubspec's name: `x,y,w,h`.
  Future<String?> _macWindow(Map<String, String> env) async {
    final d = dir;
    if (d == null) return null;
    String? name;
    try {
      name = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(File(p.join(d, 'pubspec.yaml')).readAsStringSync())?.group(1);
    } on Object {
      return null;
    }
    if (name == null) return null;
    final r = await _runner('osascript', ['-e', 'tell application "System Events" to get {position, size} of window 1 of (first process whose name is "$name")'], environment: env).timeout(const Duration(seconds: 10));
    final nums = RegExp(r'-?\d+').allMatches(r.stdout.toString()).map((m) => m.group(0)).toList();
    if (nums.length < 4) return null;
    return nums.take(4).join(',');
  }

  Future<Uint8List> _sips(Uint8List png) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final inFile = File(p.join(_tmp.path, 'kit-mirror-$stamp-in.png'))..writeAsBytesSync(png);
    final outFile = File(p.join(_tmp.path, 'kit-mirror-$stamp-out.jpg'));
    try {
      final r = await _runner('sips', ['-Z', '$frameLongEdge', '-s', 'format', 'jpeg', '-s', 'formatOptions', '70', inFile.path, '--out', outFile.path]).timeout(const Duration(seconds: 15));
      if (r.exitCode != 0 || !outFile.existsSync()) throw StateError('sips: ${r.stderr}'.trim());
      return outFile.readAsBytesSync();
    } finally {
      if (inFile.existsSync()) inFile.deleteSync();
      if (outFile.existsSync()) outFile.deleteSync();
    }
  }

  /// The simulator's points per pixel, asked once per device.
  Future<double> _simScale(String udid, Map<String, String> env) async {
    if (_scaleFor == udid && _scale != null) return _scale!;
    try {
      final r = await _runner('xcrun', ['simctl', 'getenv', udid, 'SIMULATOR_MAINSCREEN_SCALE'], environment: env).timeout(const Duration(seconds: 10));
      final v = double.tryParse(r.stdout.toString().trim());
      _scale = v == null || v <= 0 ? 3.0 : v;
    } on Object {
      _scale = 3.0;
    }
    _scaleFor = udid;
    return _scale!;
  }

  /// Plays `{type: input, action, x, y, x2, y2, text}` on the device and
  /// takes the next frame. Returns the one line to toast.
  Future<String> input(Map<String, Object?> cmd) async {
    final r = run.state;
    if (!r.up || r.device == null) return 'nothing is running';
    final action = (cmd['action'] ?? '').toString();
    int n(String k) => (cmd[k] as num?)?.toInt() ?? 0;
    final text = (cmd['text'] ?? '').toString();
    final env = await _env();
    final kind = r.devices.where((d) => d.id == r.device).firstOrNull?.kind ?? _guessKind(r);
    List<String> args;
    String bin;
    switch (kind) {
      case 'android':
        bin = await _bin('adb');
        final base = ['-s', r.device!, 'shell', 'input'];
        args = switch (action) {
          'tap' => [...base, 'tap', '${n('x')}', '${n('y')}'],
          'swipe' => [...base, 'swipe', '${n('x')}', '${n('y')}', '${n('x2')}', '${n('y2')}', '300'],
          'text' => [...base, 'text', text.replaceAll(' ', '%s')],
          'key' => [...base, 'keyevent', text],
          _ => const [],
        };
      case 'ios':
        if (!await _has('idb')) return _fail(idbMissing);
        bin = await _bin('idb');
        final s = await _simScale(r.device!, env);
        String pt(int v) => (v / s).toStringAsFixed(1);
        final base = ['ui'];
        args = switch (action) {
          'tap' => [...base, 'tap', '--udid', r.device!, pt(n('x')), pt(n('y'))],
          'swipe' => [...base, 'swipe', '--udid', r.device!, pt(n('x')), pt(n('y')), pt(n('x2')), pt(n('y2'))],
          'text' => [...base, 'text', '--udid', r.device!, text],
          'key' => [...base, 'key', '--udid', r.device!, text],
          _ => const [],
        };
      default:
        return _fail('input on a $kind run is not supported yet');
    }
    if (args.isEmpty) return 'unknown input $action';
    try {
      final res = await _runner(bin, args, environment: env).timeout(const Duration(seconds: 20));
      if (res.exitCode != 0) return _fail('input failed: ${'${res.stderr}${res.stdout}'.trim()}');
    } on Object catch (e) {
      return _fail('input failed: $e');
    }
    state = state.copyWith(lastInput: inputLabel(cmd), clearError: true);
    _publishState();
    await frame();
    return inputLabel(cmd).toLowerCase();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}

Future<ProcessResult> _runCommand(String executable, List<String> args, {String? workingDirectory, Map<String, String>? environment}) =>
    Process.run(executable, args, workingDirectory: workingDirectory, environment: environment);
