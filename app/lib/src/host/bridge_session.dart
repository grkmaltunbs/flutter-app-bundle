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
import 'codex_cli.dart';
import 'codex_engine.dart';
import 'engine.dart';
import 'permission_rules.dart';

/// How a process is started — injected so a test can hand the session a
/// fake `claude` and script its stdout.
typedef ProcessStarter = Future<Process> Function(String executable, List<String> args, {String? workingDirectory, Map<String, String>? environment});

Future<Process> _startProcess(String executable, List<String> args, {String? workingDirectory, Map<String, String>? environment}) =>
    Process.start(executable, args, workingDirectory: workingDirectory, environment: environment);

/// The engine for an id — injected so a test can hand the session a fake
/// Codex or a fake Claude.
typedef EngineFactory = Engine Function(String id);

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
  const BridgeRecord({this.sessionId, required this.startedAt, this.pid, this.always = const [], this.mode = 'default', this.chrome = false, this.model, this.effort, this.sessions = const [], this.brief, this.engine = 'claude'});

  /// Null when no session has run here yet — only options are recorded.
  /// Otherwise the current one — what Resume resumes — of [sessions].
  final String? sessionId;

  /// Every conversation this folder had, oldest first: the list the
  /// phone shows. A record from before the list reads as one entry.
  final List<SessionEntry> sessions;
  final DateTime startedAt;
  final int? pid;
  final List<AppliedRule> always;

  /// `--permission-mode`: one of [modeChoices]. `bypassPermissions` is
  /// the old Skip permissions switch; a record from before the dial
  /// still reads as it was set.
  final String mode;

  /// `--chrome`: the Claude in Chrome tools, on this Mac's browser.
  final bool chrome;

  /// `--model` / `--effort` — null leaves the CLI to its own choice.
  final String? model;
  final String? effort;

  /// The user's own part of the standing brief for this folder — its own
  /// block under the kit's lines at every Start.
  final String? brief;

  /// The engine the next Start runs on — one of [engineChoices]; a record
  /// from before the notch reads as `claude`.
  final String engine;

  Map<String, Object?> toJson() => {
        if (sessionId != null) 'sessionId': sessionId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (pid != null) 'pid': pid,
        'always': [for (final r in always) r.toJson()],
        'mode': mode,
        'chrome': chrome,
        if (model != null) 'model': model,
        if (effort != null) 'effort': effort,
        if (brief != null && brief!.trim().isNotEmpty) 'brief': brief,
        'engine': engine,
        'sessions': [for (final s in sessions) s.toMap()],
      };
  static BridgeRecord? fromJson(Object? v) {
    if (v is! Map) return null;
    final id = v['sessionId']?.toString();
    final current = id == null || id.isEmpty ? null : id;
    final startedAt = DateTime.tryParse(v['startedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final sessions = [for (final s in (v['sessions'] as List? ?? const [])) if (s is Map) SessionEntry.fromMap({for (final e in s.entries) e.key.toString(): e.value})];
    return BridgeRecord(
      sessionId: current,
      startedAt: startedAt,
      sessions: sessions.isEmpty && current != null ? [SessionEntry(id: current, startedAt: startedAt)] : sessions,
      pid: (v['pid'] as num?)?.toInt(),
      always: [for (final r in (v['always'] as List? ?? const [])) if (r is Map) AppliedRule.fromJson({for (final e in r.entries) e.key.toString(): e.value})],
      mode: v['mode'] != null ? knownMode(v['mode']) : (v['skipPermissions'] == true ? 'bypassPermissions' : 'default'),
      chrome: v['chrome'] == true,
      model: _choice(v['model']),
      effort: _choice(v['effort']),
      brief: v['brief']?.toString(),
      engine: knownEngine(v['engine']),
    );
  }

  static String? _choice(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty || s == 'default' ? null : s;
  }
}

/// One headless session for one project — `claude -p` or `codex
/// app-server`, whichever the ENGINE notch names — driven over stdio: the
/// host writes user messages and answers, reads the stream through the
/// engine's translation, and keeps the [Transcript] the window shows.
/// Sibling of [RemoteControlSession] — the other way the same folder gets
/// a session — and, like it, never a second one at a time.
///
/// Everything here is the same over both engines: the record, the
/// sessions list, the queue, the host notes, the asks, the options, the
/// brief, the Always rules, the relay. Only what goes down the pipe and
/// what comes back differ, and that is the [Engine]'s.
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
    bool Function(String sessionId)? transcriptExists,
    List<String>? Function(String sessionId)? readTranscript,
    this.readyGrace = const Duration(milliseconds: 1500),
    EngineFactory? engines,
    this.codexHome,
  })  : _starter = starter ?? _startProcess,
        _shellPath = shellPath ?? ClaudeCli.shellPath {
    _engines = engines ??
        (id) => id == 'codex'
            ? CodexEngine()
            : ClaudeEngine(
                findBinary: findBinary,
                versionOf: versionOf,
                transcriptExists: transcriptExists ?? ((id) => File(p.join(ClaudeCli.projectStateDir(dir), '$id.jsonl')).existsSync()),
                readTranscript: readTranscript ?? ((id) => _readLines(File(p.join(ClaudeCli.projectStateDir(dir), '$id.jsonl')))),
              );
    final prev = previous();
    alwaysApplied.addAll(prev?.always ?? const []);
    sessions.addAll(prev?.sessions ?? const []);
    sessionId = prev?.sessionId;
    modeChoice = prev?.mode ?? 'default';
    chrome = prev?.chrome ?? false;
    modelChoice = prev?.model;
    effort = prev?.effort;
    customBrief = prev?.brief;
    engineId = prev?.engine ?? 'claude';
    // An entry from before the list knows nothing but its id: the file
    // says what was said, once. Nothing runs at construction, so every
    // entry is over — its end is the file's last line.
    var filled = false;
    for (final s in sessions) {
      if (s.firstMessage != null || s.turns > 0 || s.isCodex) continue;
      final lines = _engines('claude').readTranscript(s.id);
      if (lines == null) continue;
      final sum = summarizeTranscript(lines);
      s.firstMessage = sum.firstMessage;
      s.turns = sum.turns;
      s.model ??= sum.model;
      s.endedAt ??= sum.lastAt;
      filled = true;
    }
    if (filled) _writeRecord();
  }

  final String dir;
  final ProcessStarter _starter;
  final Future<String> Function() _shellPath;
  late final EngineFactory _engines;

  /// Overrides `~/.flutter_kit` — tests keep their records in a temp folder.
  final String? home;

  /// Overrides `~/.codex` — where an Always rule lands on Codex.
  final String? codexHome;

  final Transcript transcript = Transcript();

  /// Where the files that travel with a message land.
  late final AttachmentStore attachments = AttachmentStore(dir: dir, home: home);

  BridgeState state = BridgeState.idle;
  String? error;
  String? sessionId;
  String? cliVersion;

  /// What the engine loaded as the folder's rules ([InitEvent.rules]);
  /// null until an engine says. Cleared with [cliVersion] on a switch.
  List<String>? rules;
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

  /// The process ended with an ask still open — nobody can answer it now,
  /// and the phone must stop showing it.
  void Function(Ask ask)? onWithdrawn;

  /// The diff for an editing tool's input against the file on disk —
  /// injected by the host, which reads files. Computed when the tool call
  /// streams in (before it runs) and again for its ask; null for other
  /// tools.
  String? Function(String toolName, Map<String, Object?> input)? diffFor;

  /// Renders what the plan holds on the thing a scoped message is about —
  /// injected by the host, which has the plan (`renderItem`/`renderStep`,
  /// the same text `kit show` prints).
  String? Function(Map<String, Object?> about)? describeAbout;

  /// Rules the CLI wrote because an ask was answered Always. Persisted with
  /// the record; the Session tab lists and removes them.
  final List<AppliedRule> alwaysApplied = [];

  /// The mode dial — `--permission-mode` for the next Start, and, while a
  /// session runs, what it is switched to in place. One of [modeChoices];
  /// `bypassPermissions` runs every command without an Allow card
  /// (questions still come). Persisted. Distinct from
  /// [Transcript.permissionMode], what the CLI last reported.
  String modeChoice = 'default';

  /// The next Start runs `--chrome`: the session drives this Mac's own
  /// browser through the Claude in Chrome extension. Persisted.
  bool chrome = false;

  /// The next Start's `--model` alias (`opus`, `fable`, …); null is the
  /// CLI's own choice. Distinct from [Transcript.model], what init said.
  String? modelChoice;

  /// The next Start's `--effort` level; null is the CLI's own.
  String? effort;

  /// The ENGINE notch: which engine the next Start runs — `claude` or
  /// `codex`. Persisted. Switched only while no session runs: a session
  /// belongs to the engine that made it.
  String engineId = 'claude';
  Engine? _engine;

  /// The engine the session runs on, or the one the next Start would.
  Engine get engine => _engine ??= _engines(engineId);
  String get engineLabel => engine.label;

  /// Moves the notch. Refused while a session runs; the line to toast.
  String setEngine(String id) {
    final want = knownEngine(id);
    if (running) return want == engineId ? 'already on ${engine.label}' : 'stop the session first — the engine switches between sessions';
    if (want != engineId) {
      engineId = want;
      _engine = null;
      cliVersion = null;
      rules = null;
      _writeRecord();
    }
    notifyListeners();
    return 'engine: ${engine.label}';
  }

  /// Options for the next Start — and, while a session runs, for this
  /// one. On Claude, [chrome] and [effort] are flags of the process, not
  /// the conversation, so the process is stopped and started again on the
  /// same session (`--resume`) with the new flags, and [mode] and [model]
  /// the CLI switches in place (`set_permission_mode`, `set_model`). On
  /// Codex all four ride on the next turn; nothing restarts. Either way:
  /// at once between turns; while a turn runs or an ask is open, when
  /// that turn ends, so nothing in flight is cut. `default` for [model] or
  /// [effort] hands the choice back to the CLI. Returns false only when
  /// nothing was given.
  bool setOptions({String? mode, bool? chrome, String? model, String? effort, String? engine}) {
    if (mode == null && chrome == null && model == null && effort == null && engine == null) return false;
    if (engine != null) setEngine(engine);
    final before = modelChoice;
    if (mode != null) modeChoice = knownMode(mode);
    if (chrome != null) this.chrome = chrome;
    if (model != null) modelChoice = BridgeRecord._choice(model);
    if (effort != null) this.effort = BridgeRecord._choice(effort);
    _writeRecord();
    if (running) {
      final e = this.engine;
      if (e.switchesByRequest) {
        if (mode != null && modeChoice != transcript.permissionMode) {
          _modeWanted = modeChoice;
          _applyPendingMode();
        }
        if (model != null && modelChoice != before) {
          _modelWanted = modelChoice ?? 'default';
          _applyPendingModel();
        }
      } else if (mode != null) {
        // The next turn carries it; the facts line says so now.
        transcript.permissionMode = modeChoice;
      }
      if ((chrome != null && e.hasChrome) || (effort != null && e.restartsOnEffort)) {
        restartPending = true;
        _applyPendingRestart();
      }
    }
    notifyListeners();
    return true;
  }

  /// A mode, a model, the running session is not on yet — sent when the
  /// turn ends (`set_permission_mode`, `set_model`; both proven live on
  /// 2.1.260, 2026-09-04).
  String? _modeWanted;
  String? _modelWanted;
  int _ctlSeq = 0;

  /// A dial moved while a turn ran; the switch waits for the turn's end.
  bool get modePending => _modeWanted != null;
  bool get modelPending => _modelWanted != null;

  void _applyPendingMode() {
    final proc = _proc;
    final want = _modeWanted;
    if (proc == null || want == null || state != BridgeState.ready || restartPending) return;
    _modeWanted = null;
    final line = engine.setMode('mode-${++_ctlSeq}', want);
    if (line != null) _write(proc, line);
  }

  void _applyPendingModel() {
    final proc = _proc;
    final want = _modelWanted;
    if (proc == null || want == null || state != BridgeState.ready || restartPending) return;
    _modelWanted = null;
    final line = engine.setModel('model-${++_ctlSeq}', want);
    if (line != null) _write(proc, line);
  }

  /// A change made while a turn was running — applied when it ends.
  bool restartPending = false;
  bool _restarting = false;

  void _applyPendingRestart() {
    if (!restartPending || _restarting || state != BridgeState.ready) return;
    unawaited(_restartForOptions());
  }

  Future<void> _restartForOptions() async {
    _restarting = true;
    restartPending = false;
    try {
      await stop();
      await start(resume: true);
    } finally {
      _restarting = false;
    }
  }

  /// What `init` said about the browser: `connected`, `failed`, … — null
  /// before init or when [chrome] was off. On Codex the browser is the
  /// ChatGPT app's own plugin and is not available under a host-spawned
  /// app-server (proven 2026-09-10): `unavailable`.
  String? get chromeStatus => engineId == 'codex' ? (running ? 'unavailable' : null) : transcript.mcpServers['claude-in-chrome'];

  /// What the next Start tells the session, on top of its own system
  /// prompt — the phone, the browser, sign-ins as questions, then the
  /// user's own block. Claude reads it as `--append-system-prompt`, Codex
  /// as `developerInstructions`.
  String get brief => deckBrief(chrome: chrome, mode: modeChoice, run: briefExtra?.call(), worktree: worktree, worktreePath: worktreePath, custom: customBrief, engine: engineId);

  /// The kit's part of the brief alone — what the editor shows above the
  /// user's block.
  String get fixedBrief => deckBrief(chrome: chrome, mode: modeChoice, run: briefExtra?.call(), worktree: worktree, worktreePath: worktreePath, engine: engineId);

  /// The user's standing rules for this folder, kept in the record and
  /// read at Start.
  String? customBrief;

  /// Saves the user's part of the brief. The line says when it applies:
  /// the brief rides on the command line, so a running session sees it
  /// only when its process starts again.
  String setBrief(String? text) {
    final t = text?.trim();
    customBrief = t == null || t.isEmpty ? null : t;
    _writeRecord();
    notifyListeners();
    if (!running) return 'Saved. It applies at the next Start.';
    return engine.restartsOnEffort ? 'Saved. It applies when the session starts again — Start, Resume, or a Chrome or effort change.' : 'Saved. It applies when the session starts again — Start or Resume.';
  }

  /// This folder is a git worktree on this branch: the brief says so, and
  /// that the plan belongs to the main tree.
  String? worktree;
  String? worktreePath;

  /// What else the next Start tells the session — the run bay's state,
  /// from the host. Read at Start; a change while a session runs reaches
  /// it as a host note instead.
  String? Function()? briefExtra;

  /// "This session": the exact requests the user allowed once for the life
  /// of the process. Cleared on stop; never persisted.
  final Set<String> _sessionAllows = {};

  Process? _proc;
  StreamSubscription<String>? _out;
  StreamSubscription<String>? _err;
  Timer? _grace;

  bool get running => state == BridgeState.starting || state == BridgeState.ready || state == BridgeState.busy || state == BridgeState.waiting;

  /// Where the record for this folder lives: `~/.flutter_kit/bridge/<slug>.json`.
  File get _recordFile => File(p.join(kitHome(home: home), 'bridge', '${claudeProjectSlug(dir)}.json'));

  /// The record goes with the folder: a removed worktree must not hand
  /// its sessions to the next tree made under the same name.
  void forgetRecord() {
    try {
      final f = _recordFile;
      if (f.existsSync()) f.deleteSync();
    } on Object {
      // Nothing to forget, or nothing we can do about it.
    }
  }

  BridgeRecord? previous() {
    try {
      final f = _recordFile;
      if (!f.existsSync()) return null;
      return BridgeRecord.fromJson(jsonDecode(f.readAsStringSync()));
    } on Object {
      return null;
    }
  }

  /// True once the process reported its init; false when it ended first
  /// or [timeout] passed — a `--resume` of a session the CLI never wrote
  /// down exits with "No conversation found" a second after it starts.
  Future<bool> awaitReady({Duration timeout = const Duration(seconds: 15)}) async {
    final end = DateTime.now().add(timeout);
    while (state == BridgeState.starting && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return running && state != BridgeState.starting;
  }

  /// Every conversation this folder had, oldest first. Persisted with the
  /// record; mirrored to the phone as `sessions/{id}`.
  final List<SessionEntry> sessions = [];

  /// The entry of the session on the Deck — running, or last run.
  SessionEntry? get current => _entry(sessionId);

  SessionEntry? _entry(String? id) {
    if (id == null) return null;
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<Map<String, Object?>> get sessionsRelay => [for (final s in sessions) s.toMap()];

  /// With stream-json input the CLI says nothing until the first message —
  /// its init comes with the first turn. A process still alive this long
  /// after Start is waiting for input: ready, not starting. Codex answers
  /// its handshake, so its init is what makes it ready.
  final Duration readyGrace;

  /// The engine's start: what Start gave it, so `/clear` and a restart
  /// run the same.
  EngineStart? _startArgs;

  /// Starts a session: a fresh conversation, or — [resume] — the one the
  /// record names, or [id] from the list. The rows on the Deck belong to
  /// one conversation: a fresh start, or a resume of a different one than
  /// shown, begins from nothing, and a resume the host has no rows for
  /// brings the tail back from the session's file. A session from the
  /// list runs on the engine that made it — the notch follows.
  Future<void> start({bool resume = false, String? id}) async {
    if (running) return;
    final want = id ?? (resume ? (sessionId ?? previous()?.sessionId) : null);
    if (resume && want == null) return _fail('Nothing to resume for this folder.');
    if (want != null) {
      final made = _entry(want)?.engine ?? 'claude';
      if (made != engineId) {
        engineId = knownEngine(made);
        _engine = null;
        cliVersion = null;
        rules = null;
      }
    }
    _engine = _engines(engineId);
    final e = engine;
    String? fresh;
    if (resume && !e.canResume(want!)) {
      // `--resume` of it would report its init and then fail on the first
      // message with "No conversation found". A fresh one loses nothing —
      // and a session that never spoke is nothing to list.
      fresh = 'Nothing to resume: session $want never spoke — starting fresh.';
      sessions.removeWhere((s) => s.id == want);
      resume = false;
    }
    lastStartNote = fresh;
    error = null;
    log.clear();
    if (fresh != null) _logLine(fresh);
    _sessionAllows.clear();
    _modeWanted = null; // the flags carry the dials
    _modelWanted = null;
    final switching = resume && want != transcript.sessionId;
    if (!resume || switching) {
      // A fresh session is a fresh conversation; Resume keeps the old one
      // when it is the one on the Deck.
      transcript.messages.clear();
      _queue.clear();
      _hostNotes.clear();
      transcript.pending = null;
      transcript.lastResult = null;
      transcript.turnOpen = false;
      // The context arc reads the conversation on the Deck, not the last
      // one: nothing until this session's first call.
      transcript.usage = null;
      transcript.usageAt = null;
    }
    state = BridgeState.starting;
    notifyListeners();
    final bin = await e.findBinary();
    if (bin == null) return _fail('${e.id} is not installed (looked on ${e.whereLooked}).');
    // Claude takes the id the host chooses; Codex names its thread with
    // the init, so a fresh one has no id until then.
    sessionId = resume ? want : (e.namesSession ? null : _uuid4());
    transcript.sessionId = sessionId;
    if (resume) {
      var cur = current;
      if (cur == null) {
        cur = SessionEntry(id: want!, startedAt: DateTime.now(), engine: e.id == 'claude' ? null : e.id);
        sessions.add(cur);
      }
      cur.endedAt = null;
      cur.mode = modeChoice;
      if (switching) _restoreRows(want!, cur);
    } else if (sessionId != null) {
      sessions.add(SessionEntry(id: sessionId!, startedAt: DateTime.now(), mode: modeChoice, model: modelChoice));
    }
    final s = EngineStart(dir: dir, mode: modeChoice, model: modelChoice, effort: effort, chrome: chrome, brief: brief, sessionId: sessionId, resume: resume);
    _startArgs = s;
    final args = e.args(s);
    try {
      _proc = await _starter(bin, args, workingDirectory: dir, environment: {...Platform.environment, 'PATH': await _shellPath()});
    } on ProcessException catch (err) {
      return _fail('Could not start ${e.id}: ${err.message}');
    }
    pid = _proc!.pid;
    startedAt = DateTime.now();
    _out = _proc!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_line);
    _err = _proc!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(_logLine);
    unawaited(_proc!.exitCode.then(_exited));
    final spawnedProc = _proc!;
    for (final l in await e.opening(s)) {
      if (!identical(_proc, spawnedProc)) break; // it died while the engine looked around
      _write(spawnedProc, l);
    }
    final spawned = _proc;
    _grace?.cancel();
    if (e.readyOnInit) {
      // Its init makes it ready; the runner waits.
    } else if (readyGrace == Duration.zero) {
      state = BridgeState.ready;
    } else {
      _grace = Timer(readyGrace, () {
        _grace = null;
        if (identical(_proc, spawned) && state == BridgeState.starting) {
          state = BridgeState.ready;
          notifyListeners();
        }
      });
    }
    _writeRecord();
    notifyListeners();
    cliVersion = await e.versionOf(bin);
    notifyListeners();
  }

  /// The tail of a session's file onto the Deck, and what the file says
  /// about the session into an entry the record had nothing on.
  void _restoreRows(String id, SessionEntry entry) {
    final lines = engine.readTranscript(id);
    if (lines == null) return;
    final rows = restoreRows(lines);
    if (rows.isNotEmpty) {
      transcript.restore(rows);
      transcript.addNote('Resumed — the last ${rows.length} rows, from the session\'s file.');
    }
    final s = summarizeTranscript(lines);
    entry.firstMessage ??= s.firstMessage;
    if (entry.turns == 0) entry.turns = s.turns;
    entry.model ??= s.model;
  }

  void _line(String raw) {
    final e = engine;
    final events = e.feed(raw);
    if (events == null) {
      _logLine(raw);
      return;
    }
    final proc = _proc;
    for (final ev in events) {
      _event(ev);
    }
    if (proc != null) {
      for (final l in e.drain()) {
        _write(proc, l);
      }
    }
    notifyListeners();
  }

  void _event(BridgeEvent e) {
    transcript.apply(e);
    switch (e) {
      case InitEvent():
        if (state == BridgeState.starting) state = transcript.turnOpen ? BridgeState.busy : BridgeState.ready;
        if (e.rules != null) rules = e.rules;
        if (e.sessionId.isNotEmpty && e.sessionId != sessionId) _adoptSessionId(e.sessionId, model: e.model);
        if (e.model != null && current?.model != e.model) {
          current?.model = e.model;
          _writeRecord();
        }
        final restored = engine.takeRestored();
        if (restored.isNotEmpty) {
          transcript.restore(restored);
          transcript.addNote('Resumed — the last ${restored.length} rows, from the thread.');
          final cur = current;
          if (cur != null) {
            cur.firstMessage ??= _firstUserLine(restored);
            if (cur.turns == 0) cur.turns = restored.where((m) => m.role == DeckRole.user).length;
            _writeRecord();
          }
        }
        _applyPendingRestart();
        _applyPendingMode();
        _applyPendingModel();
        _flushQueue();
      case AskEvent():
        e.ask.diff ??= _diffForRow(e.ask.toolUseId) ?? diffFor?.call(e.ask.toolName, e.ask.input);
        if (!e.ask.isQuestion && !e.ask.isPlan && _sessionAllows.contains(e.ask.key)) {
          _answerRemembered(e.ask);
        } else {
          state = BridgeState.waiting;
          onAsk?.call(e.ask);
        }
      case ResultEvent():
        state = BridgeState.ready;
        if (e.numTurns > 0 && current != null) {
          current!.turns++;
          _writeRecord();
        }
        final by = _interruptedBy;
        lastTurnInterrupted = by != null || e.subtype == 'interrupted';
        if (by != null) {
          _interruptedBy = null;
          transcript.addNote('Interrupted from the $by.');
        }
        _applyPendingRestart();
        _applyPendingMode();
        _applyPendingModel();
        _flushQueue();
      case ControlResponseEvent():
        if (!e.ok) {
          _logLine('${e.requestId} refused: ${e.error ?? 'no reason given'}');
          if (state == BridgeState.starting) {
            // The handshake failed — a thread that cannot be resumed, a
            // server that would not start one: the session is not coming.
            error = '${engine.label}: ${e.error ?? 'could not start a thread'}';
            unawaited(stop());
          }
        }
      case StatusEvent():
      case CompactEvent():
      case ResetEvent():
      case TaskEvent():
      case UsageEvent():
        // The transcript took the mode, the compaction, the tokens or the
        // subagent's progress; nothing for the process to do.
        break;
      case AssistantEvent():
        // An edit's row gets its diff now, while the file is still as it
        // was — the ask, if one comes, reuses it.
        for (final b in e.blocks) {
          if (!b.isToolUse || !isEditTool(b.toolName ?? '')) continue;
          for (final m in transcript.messages.reversed) {
            if (m.toolUseId == b.toolUseId) {
              m.diff ??= diffFor?.call(b.toolName!, b.toolInput ?? const {});
              break;
            }
          }
        }
        if (state != BridgeState.waiting) state = BridgeState.busy;
      case TextDeltaEvent():
      case ToolResultEvent():
        if (state != BridgeState.waiting) state = BridgeState.busy;
      case OtherEvent():
        if (e.type == 'error' || e.type == 'warning') {
          _logLine('${e.type}: ${e.subtype ?? ''}');
        } else if (e.type != 'stream_event' && e.type != 'system') {
          _logLine('${e.type}${e.subtype == null ? '' : '/${e.subtype}'}');
        }
      case UserEchoEvent():
      case RateLimitEvent():
        break;
    }
  }

  /// The engine named the session: a fresh thread got its id, a resumed
  /// one kept it — or `/clear` on Codex made a new thread, which is a new
  /// entry in the list.
  void _adoptSessionId(String id, {String? model}) {
    final old = sessionId;
    sessionId = id;
    transcript.sessionId = id;
    final cur = _entry(old);
    final engineTag = engineId == 'claude' ? null : engineId;
    if (cur == null) {
      sessions.add(SessionEntry(id: id, startedAt: DateTime.now(), mode: modeChoice, model: modelChoice ?? model, engine: engineTag));
    } else if (cur.turns == 0 && cur.firstMessage == null) {
      sessions[sessions.indexOf(cur)] = SessionEntry(id: id, startedAt: cur.startedAt, mode: cur.mode, model: cur.model ?? model, engine: engineTag);
    } else {
      cur.endedAt = DateTime.now();
      sessions.add(SessionEntry(id: id, startedAt: DateTime.now(), mode: modeChoice, model: modelChoice ?? model, engine: engineTag));
    }
    _writeRecord();
  }

  static String? _firstUserLine(List<DeckMessage> rows) {
    for (final m in rows) {
      if (m.role == DeckRole.user && m.text.trim().isNotEmpty) return clipLine(m.text, 120);
    }
    return null;
  }

  /// One line to the CLI's stdin. Never flushed: an IOSink is bound
  /// while a flush is pending, and the next write throws "StreamSink is
  /// bound to a stream" — which is what happened when a mode switch and
  /// the autopilot's next /step went out on the same turn's end. The pipe
  /// takes the bytes as they come; nothing waits on them.
  void _write(Process proc, String line) {
    try {
      proc.stdin.writeln(line);
    } on Object catch (e) {
      _logLine('stdin write failed: $e');
    }
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
  ///
  /// While a turn runs, the message is **queued**: the row shows so, the
  /// host holds the stdin line and writes it the moment the `result`
  /// lands — one queue per session, in order — unless [withdrawQueued]
  /// takes it back first. Returns true when it was queued.
  bool send(String text, {Map<String, Object?>? about, List<PendingAttachment> files = const [], String? by}) {
    final proc = _proc;
    final t = text.trim();
    if (proc == null || !running || (t.isEmpty && files.isEmpty)) return false;
    final saved = [for (final f in files) attachments.save(f)];
    final queued = transcript.turnOpen || _queue.isNotEmpty;
    final row = transcript.addUser(t, about: about, attachments: saved, queued: queued, by: by);
    lastSent = row;
    final cur = current;
    if (cur != null && cur.firstMessage == null) {
      cur.firstMessage = clipLine(t.isEmpty ? '(a file)' : t, 120);
      _writeRecord();
    }
    var prompt = about == null ? t : scopedPrompt(t, about, describeAbout?.call(about));
    final images = <InlineImage>[];
    final imagePaths = <String>[];
    final inline = <int>{};
    for (var i = 0; i < files.length; i++) {
      if (!files[i].inlinable) continue;
      images.add(InlineImage(mediaType: files[i].mime, data: base64Encode(files[i].bytes)));
      if (saved[i].path != null) imagePaths.add(saved[i].path!);
      inline.add(i);
    }
    prompt = attachmentsPrompt(prompt, saved, inline: inline);
    if (_hostNotes.isNotEmpty) {
      prompt = 'Since your last turn the user did this from the app, outside this session:\n${_hostNotes.map((l) => '- $l').join('\n')}\n\n$prompt';
      _hostNotes.clear();
    }
    final body = prompt;
    String? build() {
      final e = engine;
      final s = _startArgs;
      // `/clear` and `/compact` are requests on an engine that has them,
      // messages on one that does not.
      if (t == '/clear' && s != null) {
        final l = e.clear(EngineStart(dir: s.dir, mode: modeChoice, model: modelChoice, effort: effort, chrome: chrome, brief: brief, clear: true));
        if (l != null) return l;
      }
      if (t == '/compact') {
        final l = e.compact();
        if (l != null) {
          transcript.compacting = true;
          return l;
        }
      }
      return e.userMessage(body, images: images, imagePaths: imagePaths, turn: EngineTurn(mode: modeChoice, model: modelChoice, effort: effort));
    }

    if (queued) {
      _queue.add((row: row, build: build));
      notifyListeners();
      return true;
    }
    final line = build();
    if (line == null) {
      // The engine cannot take it yet (its thread is still starting): it
      // goes the moment the init lands, and its turn opens then.
      _queue.add((row: row, build: build));
      transcript.hold(row);
      notifyListeners();
      return true;
    }
    _write(proc, line);
    state = BridgeState.busy;
    notifyListeners();
    return false;
  }

  String? _diffForRow(String toolUseId) {
    for (final m in transcript.messages.reversed) {
      if (m.toolUseId == toolUseId) return m.diff;
    }
    return null;
  }

  /// The row the last [send] made — sent or queued — so the sender can
  /// recognise its turn's end ([Transcript.lastTurnRowId]).
  DeckMessage? lastSent;

  /// A line in the transcript from the host itself — the autopilot's
  /// record, mirrored like any row.
  void note(String text) {
    transcript.addNote(text);
    notifyListeners();
  }

  /// Messages sent while a turn ran, each with the way its stdin line is
  /// built — at write time, since on Codex the dials ride on it.
  final List<({DeckMessage row, String? Function() build})> _queue = [];

  /// What the host did on the user's behalf since the last turn — a commit
  /// from the phone, a reverted file — told to the session with the next
  /// message, so it does not work from a picture that is out of date.
  final List<String> _hostNotes = [];
  void noteHostAction(String line) => _hostNotes.add(line);

  /// A row for something the host ran itself, in the transcript where it
  /// happened and mirrored to the phone.
  DeckMessage addHostRow({required String toolName, required Map<String, Object?> input, required String result, bool isError = false}) {
    final m = transcript.addHostRow(toolName: toolName, input: input, result: result, isError: isError);
    notifyListeners();
    return m;
  }

  /// Ids of the rows still waiting, in order.
  List<String> get queuedIds => [for (final q in _queue) q.row.id];

  /// Takes a queued message back: gone from the queue and the transcript.
  /// False when it already ran, or never queued.
  bool withdrawQueued(String id) {
    final i = _queue.indexWhere((q) => q.row.id == id);
    if (i < 0) return false;
    _queue.removeAt(i);
    transcript.dropQueued(id);
    notifyListeners();
    return true;
  }

  /// The turn ended: the first queued message goes now.
  void _flushQueue() {
    final proc = _proc;
    if (proc == null || _queue.isEmpty || state != BridgeState.ready || restartPending) return;
    final line = _queue.first.build();
    if (line == null) return; // the engine is not ready for it yet
    final next = _queue.removeAt(0);
    transcript.release(next.row);
    _write(proc, line);
    state = BridgeState.busy;
  }

  /// Whether `/<name>` runs here — the engine's word, or null when it
  /// cannot tell (Claude answers "Unknown command" as text instead).
  bool? knowsCommand(String name) => engine.knowsCommand(name);

  /// Who interrupted the running turn — the note the `result` gets.
  String? _interruptedBy;

  /// The last turn ended because someone interrupted it — no "Done" push.
  bool lastTurnInterrupted = false;

  /// Ends the running turn and keeps the session: the `interrupt` control
  /// request. An open ask goes with the turn — withdrawn here and on
  /// every surface. False when no turn is running.
  bool interrupt({String by = 'Mac'}) {
    final proc = _proc;
    if (proc == null || !transcript.turnOpen) return false;
    final line = engine.interrupt('int-${++_ctlSeq}');
    if (line == null) return false;
    final open = transcript.pending;
    if (open != null) {
      transcript.pending = null;
      transcript.addNote('Withdrawn — the turn was interrupted: ${open.summary}');
      onWithdrawn?.call(open);
    }
    _interruptedBy = by;
    _write(proc, line);
    state = BridgeState.busy;
    notifyListeners();
    return true;
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
    transcript.answer(a, note: remember && !a.appliesAlways ? 'Allowed (this session): ${ask.summary}' : null);
    final after = a.modeAfter;
    if (after != null) {
      // A plan approved, or every edit allowed: the CLI switches the
      // session's mode and says nothing — the dial follows the answer.
      modeChoice = knownMode(after);
      transcript.permissionMode = after;
      _modeWanted = null;
      _writeRecord();
    }
    final line = engine.answer(ask, a);
    if (line != null) {
      _write(proc, line);
      state = BridgeState.busy;
    } else {
      // A card the host raised itself (a Codex plan): nothing to write —
      // what follows is the next turn.
      state = BridgeState.ready;
      final follow = engine.followUp(ask, a);
      if (follow != null) send(follow);
    }
    onAnswered?.call(ask, a, by);
    notifyListeners();
  }

  void _answerRemembered(Ask ask) {
    final proc = _proc;
    if (proc == null) return;
    final a = AskAnswer.allow(ask);
    transcript.answer(a, note: 'Allowed (this session): ${ask.summary}');
    final line = engine.answer(ask, a);
    if (line != null) _write(proc, line);
    state = BridgeState.busy;
    onAnswered?.call(ask, a, 'host');
  }

  /// Takes an Always rule back out of where it lives — a Claude settings
  /// file, or Codex's execpolicy — and this record.
  bool forgetAlways(AppliedRule rule) {
    final removed = rule.isExecpolicy ? ExecPolicyRules.remove(rule.pattern, home: codexHome) : PermissionRules.remove(dir, rule);
    alwaysApplied.remove(rule);
    _writeRecord();
    notifyListeners();
    return removed;
  }

  /// Takes a session off the list — the CLI's file stays. Refused for the
  /// one running. The current one, stopped, leaves the Deck empty with it.
  bool deleteSession(String id) {
    if (running && id == sessionId) return false;
    final n = sessions.length;
    sessions.removeWhere((s) => s.id == id);
    if (sessions.length == n) return false;
    if (id == sessionId) {
      sessionId = null;
      transcript.sessionId = null;
      transcript.messages.clear();
      transcript.pending = null;
      transcript.lastResult = null;
      transcript.turnOpen = false;
    }
    _writeRecord();
    notifyListeners();
    return true;
  }

  /// A resume the last Start could not honour — the session never spoke,
  /// so it started fresh and says so. Null when it did what was asked.
  String? lastStartNote;

  /// Resumes [id] from the list — or, with none, starts a new conversation
  /// — stopping the running one first, between turns. Returns the one
  /// line to toast.
  Future<String> switchTo({String? id}) async {
    if (running) {
      if (transcript.turnOpen) return 'A turn is running — interrupt it, or wait for it to end.';
      await stop();
    }
    await start(resume: id != null, id: id);
    if (error != null) return error!;
    if (!running) return 'did not start';
    if (lastStartNote != null) return lastStartNote!;
    return id == null ? 'a new session' : 'resumed ${id.length > 8 ? id.substring(0, 8) : id}';
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
    _grace?.cancel();
    _grace = null;
    final clean = code == 0 || code == 143 || code == -15;
    state = clean && error == null ? BridgeState.stopped : BridgeState.failed;
    if (!clean && error == null) error = '${engine.id} exited with code $code${log.isEmpty ? '' : ' — ${log.last}'}';
    _proc = null;
    pid = null;
    _sessionAllows.clear();
    final open = transcript.pending;
    if (open != null) {
      transcript.addNote('Withdrawn — the session stopped: ${open.summary}');
      onWithdrawn?.call(open);
    }
    transcript.pending = null;
    transcript.turnOpen = false;
    // A restart for new options is on its way; anything else that ended
    // takes the record with it on the next Start.
    if (!_restarting) restartPending = false;
    _modeWanted = null;
    _modelWanted = null;
    _interruptedBy = null;
    current?.endedAt = DateTime.now();
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
          sessionId: sessionId,
          startedAt: startedAt ?? prev?.startedAt ?? DateTime.now(),
          pid: pid,
          always: alwaysApplied,
          mode: modeChoice,
          chrome: chrome,
          model: modelChoice,
          effort: effort,
          sessions: sessions,
          brief: customBrief,
          engine: engineId,
        ).toJson()));
    } on Object {
      // The record is a convenience for Resume; the session runs without it.
    }
  }

  Map<String, Object?> toRelay() => {
        'mode': running ? 'bridge' : 'idle',
        'state': state.name,
        'pendingAsks': transcript.pending == null ? 0 : 1,
        'canResume': !running && sessionId != null,
        'engine': engineId,
        'provenOn': engine.provenOn,
        if (engine.models.isNotEmpty) 'models': engine.models,
        'modeChoice': modeChoice,
        'modePending': modePending,
        'modelPending': modelPending,
        if (transcript.permissionMode != null) 'permissionMode': transcript.permissionMode,
        'chrome': chrome,
        'modelChoice': modelChoice ?? 'default',
        'effort': effort ?? 'default',
        'restartPending': restartPending,
        'brief': customBrief ?? '',
        'briefFixed': fixedBrief,
        if (chromeStatus != null) 'chromeStatus': chromeStatus,
        if (sessionId != null) 'sessionId': sessionId,
        if (transcript.model != null) 'model': transcript.model,
        // Always written: an engine switch clears it until the new one says.
        'cliVersion': cliVersion,
        if (rules != null) 'rules': rules,
        if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
        if (transcript.pool?.resetsAt != null) 'poolResetsAt': transcript.pool!.resetsAt!.toIso8601String(),
        if (transcript.pool != null) 'pool': transcript.pool!.toMap(),
        'context': transcript.contextRelay,
        'compacting': transcript.compacting,
        // Always written: the merge would keep a dead session's error under a fresh one.
        'error': error,
      };

  /// `/compact` — a message on Claude (the CLI compacts in `-p`, proven
  /// 2026-09-06, 2.1.261: `status compacting`, a `compact_boundary` with
  /// the tokens before and after, a fresh `init`, a `result` with no
  /// turns), a `thread/compact/start` request on Codex. Queued like any
  /// message while a turn runs. Returns the one-line outcome.
  String compact() {
    if (!running) return 'no session';
    return send('/compact') ? 'queued' : 'compacting';
  }

  @override
  void dispose() {
    _out?.cancel();
    _err?.cancel();
    _grace?.cancel();
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

List<String>? _readLines(File f) {
  try {
    return f.existsSync() ? f.readAsLinesSync() : null;
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
