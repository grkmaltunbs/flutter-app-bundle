import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'claude_cli.dart';

enum RcState { idle, starting, connected, stopped, failed }

/// One `claude remote-control` process for one project. Spawned with no
/// terminal — proven on 2026-08-28: it registers, connects and polls just
/// the same — and read two ways: its stdout for the human lines, and the
/// `bridge-pointer.json` it writes for the ids.
class RemoteControlSession extends ChangeNotifier {
  RemoteControlSession({required this.dir, required this.name});

  final String dir;
  String name;
  RcState state = RcState.idle;
  String? sessionUrl;
  String? environmentUrl;
  String? error;
  String? statusLine;
  int? pid;
  DateTime? startedAt;
  final List<String> log = [];
  Process? _proc;
  Timer? _pointerPoll;
  StreamSubscription<String>? _out;
  StreamSubscription<String>? _err;

  bool get running => state == RcState.starting || state == RcState.connected;

  /// The pointer a previous (still running) server left, so a host restart
  /// finds the session instead of starting a second one.
  BridgePointer? existing() {
    final ptr = ClaudeCli.readPointer(dir);
    if (ptr == null || !ClaudeCli.processAlive(ptr.pid)) return null;
    return ptr;
  }

  Future<void> start({bool reattach = false}) async {
    if (running) return;
    error = null;
    log.clear();
    state = RcState.starting;
    notifyListeners();
    final bin = await ClaudeCli.findBinary();
    if (bin == null) return _fail('claude is not installed (looked on your shell PATH, ~/.local/bin, /opt/homebrew/bin).');
    if (!ClaudeCli.isTrusted(dir)) return _fail('This folder is not trusted yet. Open a terminal, run `claude` in $dir once and accept the trust dialog.');
    final logDir = Directory(p.join(ClaudeCli.home, '.flutter_kit', 'logs'))..createSync(recursive: true);
    final args = ['remote-control', '--name', name, '--debug-file', p.join(logDir.path, 'remote-control.log'), if (reattach) '--continue'];
    try {
      _proc = await Process.start(bin, args, workingDirectory: dir, environment: {...Platform.environment, 'PATH': await ClaudeCli.shellPath()});
    } on ProcessException catch (e) {
      return _fail('Could not start claude: ${e.message}');
    }
    pid = _proc!.pid;
    startedAt = DateTime.now();
    _out = _proc!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_line);
    _err = _proc!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(_line);
    unawaited(_proc!.exitCode.then(_exited));
    _pointerPoll = Timer.periodic(const Duration(seconds: 2), (_) => _readPointer());
    notifyListeners();
  }

  static final _ansi = RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]');
  static final _osc = RegExp(r'\x1B\][^\x07\x1B]*(\x07|\x1B\\)');
  static final _sessionRe = RegExp(r'https://claude\.ai/code/session_[A-Za-z0-9]+');
  static final _envRe = RegExp(r'https://claude\.ai/code\?environment=env_[A-Za-z0-9]+');

  void _line(String raw) {
    final line = raw.replaceAll(_osc, '').replaceAll(_ansi, '').trim();
    if (line.isEmpty) return;
    if (log.isEmpty || log.last != line) {
      log.add(line);
      if (log.length > 200) log.removeAt(0);
    }
    final s = _sessionRe.firstMatch(line);
    if (s != null) sessionUrl = s.group(0);
    final e = _envRe.firstMatch(line);
    if (e != null) environmentUrl = e.group(0);
    if (line.contains('Connected')) {
      state = RcState.connected;
      statusLine = line;
    } else if (line.startsWith('Error:')) {
      error = line;
    }
    notifyListeners();
  }

  void _readPointer() {
    final ptr = ClaudeCli.readPointer(dir);
    if (ptr == null || ptr.pid != pid) return;
    sessionUrl ??= ptr.sessionUrl;
    environmentUrl ??= ptr.environmentUrl;
    if (state == RcState.starting && sessionUrl != null) state = RcState.connected;
    notifyListeners();
  }

  void _exited(int code) {
    _pointerPoll?.cancel();
    _pointerPoll = null;
    state = code == 0 || code == 143 || code == -15 ? RcState.stopped : RcState.failed;
    if (state == RcState.failed && error == null) error = 'claude exited with code $code';
    _proc = null;
    pid = null;
    notifyListeners();
  }

  void _fail(String message) {
    error = message;
    state = RcState.failed;
    notifyListeners();
  }

  Future<void> stop() async {
    final proc = _proc;
    if (proc == null) return;
    proc.kill(ProcessSignal.sigterm);
    // The bridge answers SIGTERM by stopping its sessions and preserving the
    // environment; give it a moment before the app moves on.
    await proc.exitCode.timeout(const Duration(seconds: 10), onTimeout: () {
      proc.kill(ProcessSignal.sigkill);
      return -9;
    });
  }

  Map<String, Object?> toRelay() => {
        'state': state.name,
        'name': name,
        if (sessionUrl != null) 'sessionUrl': sessionUrl,
        if (environmentUrl != null) 'environmentUrl': environmentUrl,
        if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
        if (error != null) 'error': error,
      };

  @override
  void dispose() {
    _pointerPoll?.cancel();
    _out?.cancel();
    _err?.cancel();
    super.dispose();
  }
}
