import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;

import 'claude_cli.dart';

/// How a process is started — injected so a test can hand the session a
/// fake `claude` and script its stdout.
typedef ProcessStarter = Future<Process> Function(String executable, List<String> args, {String? workingDirectory, Map<String, String>? environment});

Future<Process> _startProcess(String executable, List<String> args, {String? workingDirectory, Map<String, String>? environment}) =>
    Process.start(executable, args, workingDirectory: workingDirectory, environment: environment);

enum BridgeState {
  idle,

  /// The process is up; no `init` yet.
  starting,

  /// Between turns — send something.
  ready,

  /// A turn is running.
  busy,

  /// A permission or a question is waiting on the user.
  waiting,
  stopped,
  failed,
}

/// The session a previous run left for this folder, so a host restart can
/// offer Resume instead of starting a second conversation.
class BridgeRecord {
  const BridgeRecord({required this.sessionId, required this.startedAt, this.pid});
  final String sessionId;
  final DateTime startedAt;
  final int? pid;
  Map<String, Object?> toJson() => {'sessionId': sessionId, 'startedAt': startedAt.toUtc().toIso8601String(), if (pid != null) 'pid': pid};
  static BridgeRecord? fromJson(Object? v) {
    if (v is! Map) return null;
    final id = v['sessionId']?.toString();
    if (id == null || id.isEmpty) return null;
    return BridgeRecord(sessionId: id, startedAt: DateTime.tryParse(v['startedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0), pid: (v['pid'] as num?)?.toInt());
  }
}

/// One headless `claude -p` for one project, driven over stdio: the host
/// writes user messages and control responses, reads the stream, and keeps
/// the [Transcript] the window shows. Sibling of [RemoteControlSession] —
/// the other way the same folder gets a session — and, like it, never a
/// second one at a time.
///
/// No trust check here: `claude -p` runs in an untrusted folder (proven
/// 2026-08-30); only Remote Control refuses one.
class BridgeSession extends ChangeNotifier {
  BridgeSession({
    required this.dir,
    ProcessStarter? starter,
    Future<String?> Function()? findBinary,
    Future<String?> Function(String bin)? versionOf,
    Future<String> Function()? shellPath,
    this.home,
  })  : _starter = starter ?? _startProcess,
        _findBinary = findBinary ?? ClaudeCli.findBinary,
        _versionOf = versionOf ?? _claudeVersion,
        _shellPath = shellPath ?? ClaudeCli.shellPath;

  final String dir;
  final ProcessStarter _starter;
  final Future<String?> Function() _findBinary;
  final Future<String?> Function(String bin) _versionOf;
  final Future<String> Function() _shellPath;

  /// Overrides `~/.flutter_kit` — tests keep their records in a temp folder.
  final String? home;

  final Transcript transcript = Transcript();
  BridgeState state = BridgeState.idle;
  String? error;
  String? sessionId;
  String? cliVersion;
  int? pid;
  DateTime? startedAt;

  /// stderr and any stdout line that was not protocol — the Session tab's
  /// process output.
  final List<String> log = [];

  Process? _proc;
  StreamSubscription<String>? _out;
  StreamSubscription<String>? _err;

  bool get running => state == BridgeState.starting || state == BridgeState.ready || state == BridgeState.busy || state == BridgeState.waiting;

  /// Where the record for this folder lives: `~/.flutter_kit/bridge/<slug>.json`.
  File get _recordFile => File(p.join(kitHome(home: home), 'bridge', '${claudeProjectSlug(dir)}.json'));

  BridgeRecord? previous() {
    try {
      final f = _recordFile;
      if (!f.existsSync()) return null;
      return BridgeRecord.fromJson(jsonDecode(f.readAsStringSync()));
    } on Object {
      return null;
    }
  }

  Future<void> start({bool resume = false, String? model}) async {
    if (running) return;
    final prev = resume ? previous() : null;
    if (resume && prev == null) return _fail('Nothing to resume for this folder.');
    error = null;
    log.clear();
    state = BridgeState.starting;
    notifyListeners();
    final bin = await _findBinary();
    if (bin == null) return _fail('claude is not installed (looked on your shell PATH, ~/.local/bin, /opt/homebrew/bin).');
    sessionId = resume ? prev!.sessionId : _uuid4();
    final args = bridgeArgs(sessionId: sessionId!, resume: resume, model: model);
    try {
      _proc = await _starter(bin, args, workingDirectory: dir, environment: {...Platform.environment, 'PATH': await _shellPath()});
    } on ProcessException catch (e) {
      return _fail('Could not start claude: ${e.message}');
    }
    pid = _proc!.pid;
    startedAt = DateTime.now();
    _out = _proc!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_line);
    _err = _proc!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(_logLine);
    unawaited(_proc!.exitCode.then(_exited));
    _writeRecord();
    notifyListeners();
    cliVersion = await _versionOf(bin);
    notifyListeners();
  }

  void _line(String raw) {
    final e = parseBridgeLine(raw);
    if (e == null) {
      _logLine(raw);
      return;
    }
    transcript.apply(e);
    switch (e) {
      case InitEvent():
        if (state == BridgeState.starting) state = transcript.turnOpen ? BridgeState.busy : BridgeState.ready;
        if (e.sessionId.isNotEmpty && e.sessionId != sessionId) {
          // A resumed session keeps its id; a fresh one is what we asked for.
          sessionId = e.sessionId;
          _writeRecord();
        }
      case AskEvent():
        state = BridgeState.waiting;
      case ResultEvent():
        state = BridgeState.ready;
      case TextDeltaEvent():
      case AssistantEvent():
      case ToolResultEvent():
        if (state != BridgeState.waiting) state = BridgeState.busy;
      case OtherEvent():
        if (e.type != 'stream_event' && e.type != 'system') _logLine('${e.type}${e.subtype == null ? '' : '/${e.subtype}'}');
      case UserEchoEvent():
      case RateLimitEvent():
        break;
    }
    notifyListeners();
  }

  void _logLine(String line) {
    final l = line.trim();
    if (l.isEmpty) return;
    log.add(l);
    if (log.length > 200) log.removeAt(0);
  }

  /// Sends a message. [about] scopes it to one item or step — the prompt
  /// prefix for that comes in `item-threads`.
  void send(String text, {Map<String, Object?>? about}) {
    final proc = _proc;
    final t = text.trim();
    if (proc == null || !running || t.isEmpty) return;
    transcript.addUser(t, about: about);
    proc.stdin.writeln(encodeUserMessage(t));
    unawaited(proc.stdin.flush());
    state = BridgeState.busy;
    notifyListeners();
  }

  /// Answers the pending ask. No-op when nothing is pending.
  void answer(AskAnswer a) {
    final proc = _proc;
    if (proc == null || transcript.pending == null) return;
    final line = transcript.answer(a);
    proc.stdin.writeln(line);
    unawaited(proc.stdin.flush());
    state = BridgeState.busy;
    notifyListeners();
  }

  Future<void> stop() async {
    final proc = _proc;
    if (proc == null) return;
    try {
      await proc.stdin.close();
    } on Object {
      // Already closed by the other side.
    }
    proc.kill(ProcessSignal.sigterm);
    await proc.exitCode.timeout(const Duration(seconds: 8), onTimeout: () {
      proc.kill(ProcessSignal.sigkill);
      return -9;
    });
  }

  void _exited(int code) {
    final clean = code == 0 || code == 143 || code == -15;
    state = clean ? BridgeState.stopped : BridgeState.failed;
    if (!clean && error == null) error = 'claude exited with code $code${log.isEmpty ? '' : ' — ${log.last}'}';
    _proc = null;
    pid = null;
    transcript.pending = null;
    transcript.turnOpen = false;
    _writeRecord();
    notifyListeners();
  }

  void _fail(String message) {
    error = message;
    state = BridgeState.failed;
    notifyListeners();
  }

  void _writeRecord() {
    final id = sessionId;
    if (id == null) return;
    try {
      _recordFile
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(BridgeRecord(sessionId: id, startedAt: startedAt ?? DateTime.now(), pid: pid).toJson()));
    } on Object {
      // The record is a convenience for Resume; the session runs without it.
    }
  }

  Map<String, Object?> toRelay() => {
        'mode': running ? 'bridge' : 'idle',
        'state': state.name,
        if (sessionId != null) 'sessionId': sessionId,
        if (transcript.model != null) 'model': transcript.model,
        if (cliVersion != null) 'cliVersion': cliVersion,
        if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
        if (transcript.pool?.resetsAt != null) 'poolResetsAt': transcript.pool!.resetsAt!.toIso8601String(),
        if (error != null) 'error': error,
      };

  @override
  void dispose() {
    _out?.cancel();
    _err?.cancel();
    super.dispose();
  }
}

Future<String?> _claudeVersion(String bin) async {
  try {
    final r = await Process.run(bin, ['--version']).timeout(const Duration(seconds: 15));
    final out = (r.stdout as String).trim();
    return out.isEmpty ? null : out.split(' ').first;
  } on Object {
    return null;
  }
}

String _uuid4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
