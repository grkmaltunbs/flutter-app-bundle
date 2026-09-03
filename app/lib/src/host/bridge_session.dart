import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;

import '../attachments.dart';
import 'attachment_store.dart';
import 'claude_cli.dart';
import 'permission_rules.dart';

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

/// What this folder keeps between runs: the session a previous run left,
/// so a host restart can offer Resume instead of starting a second
/// conversation; the rules the user answered Always to, so the Session
/// tab can list them; and the options the next Start runs with.
class BridgeRecord {
  const BridgeRecord({this.sessionId, required this.startedAt, this.pid, this.always = const [], this.skipPermissions = false, this.chrome = false});

  /// Null when no session has run here yet — only options are recorded.
  final String? sessionId;
  final DateTime startedAt;
  final int? pid;
  final List<AppliedRule> always;

  /// `--permission-mode bypassPermissions`: nothing waits on Allow.
  final bool skipPermissions;

  /// `--chrome`: the Claude in Chrome tools, on this Mac's browser.
  final bool chrome;

  Map<String, Object?> toJson() => {
        if (sessionId != null) 'sessionId': sessionId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (pid != null) 'pid': pid,
        'always': [for (final r in always) r.toJson()],
        'skipPermissions': skipPermissions,
        'chrome': chrome,
      };
  static BridgeRecord? fromJson(Object? v) {
    if (v is! Map) return null;
    final id = v['sessionId']?.toString();
    return BridgeRecord(
      sessionId: id == null || id.isEmpty ? null : id,
      startedAt: DateTime.tryParse(v['startedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      pid: (v['pid'] as num?)?.toInt(),
      always: [for (final r in (v['always'] as List? ?? const [])) if (r is Map) AppliedRule.fromJson({for (final e in r.entries) e.key.toString(): e.value})],
      skipPermissions: v['skipPermissions'] == true,
      chrome: v['chrome'] == true,
    );
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
        _shellPath = shellPath ?? ClaudeCli.shellPath {
    final prev = previous();
    alwaysApplied.addAll(prev?.always ?? const []);
    skipPermissions = prev?.skipPermissions ?? false;
    chrome = prev?.chrome ?? false;
  }

  final String dir;
  final ProcessStarter _starter;
  final Future<String?> Function() _findBinary;
  final Future<String?> Function(String bin) _versionOf;
  final Future<String> Function() _shellPath;

  /// Overrides `~/.flutter_kit` — tests keep their records in a temp folder.
  final String? home;

  final Transcript transcript = Transcript();

  /// Where the files that travel with a message land.
  late final AttachmentStore attachments = AttachmentStore(dir: dir, home: home);

  BridgeState state = BridgeState.idle;
  String? error;
  String? sessionId;
  String? cliVersion;
  int? pid;
  DateTime? startedAt;

  /// stderr and any stdout line that was not protocol — the Session tab's
  /// process output.
  final List<String> log = [];

  /// A new ask that needs a person — the host mirrors it to the phone.
  void Function(Ask ask)? onAsk;

  /// An ask was answered, by whichever surface got there first; [by] names
  /// it (`Mac`, `phone`, or `host` for a remembered one).
  void Function(Ask ask, AskAnswer answer, String by)? onAnswered;

  /// Renders what the plan holds on the thing a scoped message is about —
  /// injected by the host, which has the plan (`renderItem`/`renderStep`,
  /// the same text `kit show` prints).
  String? Function(Map<String, Object?> about)? describeAbout;

  /// Rules the CLI wrote because an ask was answered Always. Persisted with
  /// the record; the Session tab lists and removes them.
  final List<AppliedRule> alwaysApplied = [];

  /// The next Start runs `--permission-mode bypassPermissions`: no Allow /
  /// Deny cards, every command runs. Questions still come. Persisted.
  bool skipPermissions = false;

  /// The next Start runs `--chrome`: the session drives this Mac's own
  /// browser through the Claude in Chrome extension. Persisted.
  bool chrome = false;

  /// Options are fixed for a running process; returns false then.
  bool setOptions({bool? skipPermissions, bool? chrome}) {
    if (running) return false;
    if (skipPermissions != null) this.skipPermissions = skipPermissions;
    if (chrome != null) this.chrome = chrome;
    _writeRecord();
    notifyListeners();
    return true;
  }

  /// What `init` said about the browser: `connected`, `failed`, … — null
  /// before init or when [chrome] was off.
  String? get chromeStatus => transcript.mcpServers['claude-in-chrome'];

  /// "This session": the exact requests the user allowed once for the life
  /// of the process. Cleared on stop; never persisted.
  final Set<String> _sessionAllows = {};

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
    if (resume && prev?.sessionId == null) return _fail('Nothing to resume for this folder.');
    error = null;
    log.clear();
    _sessionAllows.clear();
    if (!resume) {
      // A fresh session is a fresh conversation; Resume keeps the old one.
      transcript.messages.clear();
      transcript.pending = null;
      transcript.lastResult = null;
      transcript.turnOpen = false;
    }
    state = BridgeState.starting;
    notifyListeners();
    final bin = await _findBinary();
    if (bin == null) return _fail('claude is not installed (looked on your shell PATH, ~/.local/bin, /opt/homebrew/bin).');
    sessionId = resume ? prev!.sessionId : _uuid4();
    final args = bridgeArgs(sessionId: sessionId!, resume: resume, model: model, permissionMode: skipPermissions ? 'bypassPermissions' : 'default', chrome: chrome);
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
        if (!e.ask.isQuestion && _sessionAllows.contains(e.ask.key)) {
          _answerRemembered(e.ask);
        } else {
          state = BridgeState.waiting;
          onAsk?.call(e.ask);
        }
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

  /// Sends a message. [about] scopes it to one item or step: the deck
  /// shows what was typed, the model reads it wrapped with `kit show` and
  /// the standing instruction — answer for a phone, edit the thing itself
  /// if it should change. [files] travel with it: every one is saved under
  /// the store and named by path in the prompt; an image the API takes
  /// goes inline too, so the model sees it at once — a pasted screenshot,
  /// as in the terminal.
  void send(String text, {Map<String, Object?>? about, List<PendingAttachment> files = const []}) {
    final proc = _proc;
    final t = text.trim();
    if (proc == null || !running || (t.isEmpty && files.isEmpty)) return;
    final saved = [for (final f in files) attachments.save(f)];
    transcript.addUser(t, about: about, attachments: saved);
    var prompt = about == null ? t : scopedPrompt(t, about, describeAbout?.call(about));
    final images = <InlineImage>[];
    final inline = <int>{};
    for (var i = 0; i < files.length; i++) {
      if (!files[i].inlinable) continue;
      images.add(InlineImage(mediaType: files[i].mime, data: base64Encode(files[i].bytes)));
      inline.add(i);
    }
    prompt = attachmentsPrompt(prompt, saved, inline: inline);
    proc.stdin.writeln(encodeUserMessage(prompt, images: images));
    unawaited(proc.stdin.flush());
    state = BridgeState.busy;
    notifyListeners();
  }

  /// Answers the pending ask. A no-op when nothing is pending, or when
  /// [requestId] names a different ask than the pending one — a phone's
  /// answer to a question the Mac already settled must not land on the
  /// next question. [remember] is "this session"; an [AskAnswer.always]
  /// is remembered too, and its rules are recorded.
  void answer(AskAnswer a, {String? requestId, String by = 'Mac', bool remember = false}) {
    final proc = _proc;
    final ask = transcript.pending;
    if (proc == null || ask == null) return;
    if (requestId != null && requestId != ask.requestId) return;
    if (a.allowed && !ask.isQuestion && (remember || a.appliesAlways)) _sessionAllows.add(ask.key);
    if (a.appliesAlways) {
      for (final s in ask.suggestions) {
        for (final r in AppliedRule.fromSuggestion(s)) {
          if (!alwaysApplied.contains(r)) alwaysApplied.add(r);
        }
      }
      _writeRecord();
    }
    final line = transcript.answer(a, note: remember && !a.appliesAlways ? 'Allowed (this session): ${ask.summary}' : null);
    proc.stdin.writeln(line);
    unawaited(proc.stdin.flush());
    state = BridgeState.busy;
    onAnswered?.call(ask, a, by);
    notifyListeners();
  }

  void _answerRemembered(Ask ask) {
    final proc = _proc;
    if (proc == null) return;
    final a = AskAnswer.allow(ask);
    final line = transcript.answer(a, note: 'Allowed (this session): ${ask.summary}');
    proc.stdin.writeln(line);
    unawaited(proc.stdin.flush());
    state = BridgeState.busy;
    onAnswered?.call(ask, a, 'host');
  }

  /// Takes an Always rule back out of its settings file and this record.
  bool forgetAlways(AppliedRule rule) {
    final removed = PermissionRules.remove(dir, rule);
    alwaysApplied.remove(rule);
    _writeRecord();
    notifyListeners();
    return removed;
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
    _sessionAllows.clear();
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
    final prev = previous();
    try {
      _recordFile
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(BridgeRecord(
          sessionId: sessionId ?? prev?.sessionId,
          startedAt: startedAt ?? prev?.startedAt ?? DateTime.now(),
          pid: pid,
          always: alwaysApplied,
          skipPermissions: skipPermissions,
          chrome: chrome,
        ).toJson()));
    } on Object {
      // The record is a convenience for Resume; the session runs without it.
    }
  }

  Map<String, Object?> toRelay() => {
        'mode': running ? 'bridge' : 'idle',
        'state': state.name,
        'pendingAsks': transcript.pending == null ? 0 : 1,
        'canResume': !running && previous()?.sessionId != null,
        'skipPermissions': skipPermissions,
        'chrome': chrome,
        if (chromeStatus != null) 'chromeStatus': chromeStatus,
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

/// The prompt a scoped message becomes: the question, what the plan holds
/// on the thing (when the host could render it), and the standing
/// instruction from the plan's `item-threads` step.
String scopedPrompt(String text, Map<String, Object?> about, String? shown) {
  final kind = about.containsKey('item') ? 'item' : 'step';
  final id = (about[kind] ?? '').toString();
  return [
    'The user asks about one $kind of the plan — `$id`:',
    '',
    text,
    '',
    if (shown != null && shown.trim().isNotEmpty) ...[
      '--- what the plan holds on it (kit show $id) ---',
      shown.trim(),
      '--- end ---',
      '',
    ],
    'Answer for a phone screen: short and concrete, from this $kind\'s own facts.',
    'If the $kind itself should change — needs, blocks, body, runbook, deadline, or the recommended option — make the change with the `kit` CLI or by editing its YAML under plan/, and say in one line what you changed.',
  ].join('\n');
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
