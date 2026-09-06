import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;

import '../attachments.dart';
import '../blobs.dart';
import '../plan_source.dart';
import '../relay.dart';
import '../screens/mirror_sheet.dart';
import 'autopilot.dart';
import 'bridge_session.dart';
import 'claude_cli.dart';
import 'hook_watcher.dart';
import 'host_actions.dart';
import 'mirror.dart';
import 'power.dart';
import 'push_sender.dart';
import 'remote_control.dart';
import 'run_bay.dart';

/// Everything the host runs for one open project: the plan on disk, its
/// mirror, the inbox, the hook spool, and the two ways the folder gets a
/// Claude session — the bridge (this app talks to it) and Remote Control
/// (the Claude app does).
class HostProject extends ChangeNotifier {
  HostProject({required this.dir, required this.db, this.push, this.blobs, this.power});

  final String dir;
  final FirebaseFirestore db;

  /// The bucket the phone's files come from; null in a test without one.
  final BlobStore? blobs;

  /// Holds the Mac awake while a session runs; null in a test.
  final PowerHold? power;

  /// The Mac's one push sender, shared by every open project; null in a
  /// test that has no phone to reach.
  final PushSender? push;
  final TurnWatch _turns = TurnWatch();

  /// The host's own hands: files inside the project for the phone, and git.
  late final HostFiles files = HostFiles(dir: dir, attachmentsDir: bridge.attachments.folder.path);
  late final GitOps git = GitOps(dir);

  /// The Git card's numbers — read after every turn and every hook event.
  GitStatus? gitStatus;
  Timer? _gitTimer;
  BridgeState _lastState = BridgeState.idle;
  late final LocalPlanSource source = LocalPlanSource(dir);
  late final HookWatcher hooks = HookWatcher(dir);
  late final RemoteControlSession session = RemoteControlSession(dir: dir, name: p.basename(dir));
  late final BridgeSession bridge = BridgeSession(dir: dir);

  /// The loop that keeps the session stepping — see [Autopilot].
  late final Autopilot autopilot = Autopilot(bridge: bridge, loadPlan: _freshPlan, push: (line) => _notify(Notice(kind: NoticeKind.done, title: 'Autopilot · $projectName', body: line)));

  /// The app under test, run by the host — see [RunBay].
  late final RunBay run = RunBay(dir: dir, runtime: () => source.plan?.manifest.qa['runtime']?.toString());
  RunPhase _lastRunPhase = RunPhase.idle;

  /// The run's device on the phone — see [Mirror].
  late final Mirror mirror = Mirror(run: run, blobs: blobs, slug: () => slug, dir: dir, publish: (m) async => _publisher?.publishMirror(m));
  StreamSubscription<Object?>? _mirrorWatch;
  RelayPublisher? _publisher;
  InboxListener? _inbox;
  CommandListener? _commands;
  String? slug;
  String relayStatus = 'not published yet';
  String? relayError;
  bool get hooksInstalled => ClaudeCli.hooksInstalled(dir);
  bool _publishing = false;
  bool _dirty = false;
  final List<String> applied = [];

  String get machine => Platform.localHostname;

  void start() {
    source.addListener(_onPlan);
    session.addListener(_onSession);
    bridge.addListener(_onBridge);
    autopilot.addListener(_onAutopilot);
    run.addListener(_onRun);
    mirror.addListener(notifyListeners);
    bridge.briefExtra = () => runBrief(run.state);
    bridge.diffFor = (tool, input) => diffForAsk(toolName: tool, input: input, read: _readForDiff);
    _refreshGit(soon: true);
    // A scoped message carries what the plan holds on its item or step —
    // the same text `kit show` prints.
    bridge.describeAbout = (about) {
      final plan = source.plan;
      if (plan == null) return null;
      final id = (about['item'] ?? about['step'])?.toString();
      if (id == null || id.isEmpty) return null;
      final item = plan.item(id);
      if (item != null) return renderItem(plan, item);
      final step = plan.step(id);
      if (step != null) return renderStep(plan, step);
      return null;
    };
    bridge.onAsk = _onAsk;
    bridge.onAnswered = _onAnswered;
    bridge.onWithdrawn = (ask) {
      _publisher?.resolveAsk(ask.requestId, summary: 'Withdrawn', by: 'host');
      _withdraw(ask.requestId);
    };
    hooks.onEvent = _onHook;
    source.start();
    hooks.start();
    push?.start();
  }

  /// The project as a notification names it.
  String get projectName => source.plan?.manifest.projectName ?? p.basename(dir);

  /// The plan as the files hold it this instant — the autopilot reads it
  /// the moment a turn ends, before the watcher's debounce. The last
  /// good plan when a file is half-written.
  Plan? _freshPlan() {
    try {
      return source.store.load();
    } on Object {
      return source.plan;
    }
  }

  void _onAutopilot() {
    _publisher?.publishSession(sessionRelay());
    notifyListeners();
  }

  /// The run moved: the session document, the log, and — when the app
  /// came up or went down — a note for the session's next prompt, so it
  /// reaches the running app through the Dart MCP server instead of
  /// starting its own.
  void _onRun() {
    final r = run.state;
    if (r.phase != _lastRunPhase) {
      if (r.phase == RunPhase.running) {
        bridge.noteHostAction('The run bay started the app on ${r.deviceName ?? r.device}${r.vmUri != null ? ' — VM service ${r.vmUri}' : ''}${r.dtdUri != null ? ', Dart Tooling Daemon ${r.dtdUri}' : ''}. The host owns that process: do not start a second flutter run; reach the app through the Dart MCP server.');
      } else if (_lastRunPhase == RunPhase.running && (r.phase == RunPhase.stopped || r.phase == RunPhase.failed)) {
        bridge.noteHostAction('The run bay stopped the app${r.error != null ? ' (${r.error})' : ''}.');
      }
      if (!r.up) mirror.stop();
      _lastRunPhase = r.phase;
    }
    _publisher?.publishSession(sessionRelay());
    final id = r.runId;
    if (id != null) _publisher?.publishRunLog(id, run.log);
    notifyListeners();
  }

  /// The run bay from the Mac's own screens: the same command the phone
  /// sends. Returns the one line to toast.
  Future<String> runAction(String action, {String? device, bool? on}) => applyCommand({'type': 'run', 'action': action, 'device': ?device, 'on': ?on, 'from': 'Mac'});

  /// The mirror sheet on the Mac: the host's own frames, no relay.
  MirrorHooks get mirrorHooks => MirrorHooks(
        state: () async* {
          yield mirror.state;
          await for (final _ in _changes(mirror)) {
            yield mirror.state;
          }
        }(),
        frame: () async => mirror.lastFrame ?? (throw StateError('no frame yet')),
        ping: () async => mirror.watching(DateTime.now(), 'Mac'),
        requestFrame: mirror.frame,
        input: mirror.input,
      );

  static Stream<void> _changes(Listenable l) {
    late StreamController<void> c;
    void tick() => c.add(null);
    c = StreamController<void>(onListen: () => l.addListener(tick), onCancel: () => l.removeListener(tick));
    return c.stream;
  }

  /// The autopilot from the Mac's own Deck: the same command the phone
  /// sends. Returns the one line to toast.
  Future<String> setAutopilot({required bool on, int? budget, bool? nightShift}) =>
      applyCommand({'type': 'autopilot', 'on': on, 'budget': ?budget, 'nightShift': ?nightShift, 'from': 'Mac'});

  /// What the phone sees as the session: the bridge while it runs, else
  /// Remote Control, else idle.
  Map<String, Object?> sessionRelay() => {..._sessionCore(), if (gitStatus != null) 'git': gitStatus!.toMap(), 'autopilot': autopilot.state.toMap(), 'run': run.state.toMap()};

  Map<String, Object?> _sessionCore() {
    if (bridge.running) return bridge.toRelay();
    if (session.running) return {...session.toRelay(), 'mode': 'remote', 'pendingAsks': 0};
    // Idle carries the bridge's record too, so the phone still offers
    // Resume after the host restarted.
    return {...session.toRelay(), ...bridge.toRelay(), 'mode': 'idle', 'pendingAsks': 0};
  }

  /// The file as it is on disk, for a diff — null when there is none.
  /// Any path: the session edits what it edits, and the diff only shows
  /// what that is.
  String? _readForDiff(String path) {
    try {
      final f = File(p.isAbsolute(path) ? path : p.join(dir, path));
      return f.existsSync() ? f.readAsStringSync() : null;
    } on Object {
      return null;
    }
  }

  /// Reads git after a short quiet — a turn's end, a hook event and a
  /// git command all ask; the last one wins.
  void _refreshGit({bool soon = false}) {
    _gitTimer?.cancel();
    _gitTimer = Timer(Duration(milliseconds: soon ? 50 : 1500), () async {
      final s = await git.status();
      gitStatus = s;
      _publisher?.publishSession(sessionRelay());
      notifyListeners();
    });
  }

  /// A git command from either surface: run, shown as a row, told to the
  /// session with the next message. Returns the one line to toast.
  Future<String> gitOp(String op, {String? message, String? path}) => applyCommand({'type': 'host', 'action': 'git', 'op': op, 'message': ?message, 'path': ?path});

  void _onBridge() {
    // Whose turn just ended — read before the loop moves on to its next.
    final loopTurn = autopilot.on && autopilot.ownsLastTurn;
    autopilot.check();
    _holdWhile(running: bridge.running, pid: bridge.pid);
    if (bridge.state != _lastState) {
      // A turn ended, a session started or stopped: the tree may have moved.
      if (bridge.state == BridgeState.ready || bridge.state == BridgeState.idle || bridge.state == BridgeState.stopped) _refreshGit();
      _lastState = bridge.state;
    }
    _publisher?.publishSession(sessionRelay());
    _publisher?.publishTranscript(bridge.transcript);
    final pub = _publisher;
    if (pub != null) unawaited(pub.publishThreads(bridge.transcript));
    final turn = _turns.check(state: bridge.state, error: bridge.error, lastResult: bridge.transcript.lastResult, interrupted: bridge.lastTurnInterrupted, project: projectName);
    // The loop's own line replaces the plain Done for a turn it drove.
    if (turn != null && !(loopTurn && turn.kind == NoticeKind.done)) _notify(turn);
    notifyListeners();
  }

  void _onAsk(Ask ask) {
    _publisher?.publishAsk(ask);
    _notify(noticeForAsk(ask, project: projectName));
  }

  /// A push to every registered phone, on request — the PUSH · TEST pill
  /// on either device. Returns the one line the pill toasts.
  Future<String> testPush() async {
    final ps = push;
    final s = slug;
    if (ps == null || s == null) return 'no relay for this project yet';
    if (!ps.ready) return ps.status;
    if (ps.devices.isEmpty) return 'no phone registered — open the app on the phone and allow notifications';
    final now = DateTime.now();
    final hm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final n = await ps.send(Notice(kind: NoticeKind.done, title: 'Test push · $projectName', body: 'The Mac reaches this phone — $hm.'), slug: s);
    return n > 0 ? 'sent to $n phone${n == 1 ? '' : 's'}' : (ps.lastError ?? 'nothing sent');
  }

  /// To the phone's lock screen — when there is a key on this Mac, a
  /// phone registered, and a slug to open on a tap.
  void _notify(Notice n) {
    final s = slug;
    final ps = push;
    if (s == null || ps == null) return;
    unawaited(ps.send(n, slug: s));
  }

  void _onAnswered(Ask ask, AskAnswer a, String by) {
    _publisher?.resolveAsk(ask.requestId, summary: a.summary, by: by);
    // Whichever surface answered, the notification comes off the others.
    _withdraw(ask.requestId);
  }

  /// The silent push that takes an ask's notification off every phone.
  void _withdraw(String requestId) {
    final s = slug;
    final ps = push;
    if (s == null || ps == null || requestId.isEmpty) return;
    unawaited(ps.withdraw(requestId, slug: s));
  }

  /// Asks a dead process or a fresh conversation left open: closed in the
  /// relay, and taken off every lock screen.
  Future<void> _sweepAsks(RelayPublisher pub) async {
    List<String> ids;
    try {
      ids = await pub.withdrawOpenAsks();
    } on Object {
      return;
    }
    for (final id in ids) {
      _withdraw(id);
    }
  }

  /// A clean quit: the session this folder runs is stopped (its process
  /// would die with the app anyway), the relay reads stopped rather than
  /// a session the Mac can no longer see, and the "now" line says so.
  Future<void> quit() async {
    autopilot.stop(by: 'the Mac quitting');
    mirror.stop();
    if (run.up) await run.stop();
    if (bridge.running) await bridge.stop();
    if (session.running) await session.stop();
    final pub = _publisher;
    final id = bridge.sessionId;
    if (pub != null && id != null) {
      pub.publishNow(HookEvent(at: DateTime.now(), name: 'SessionEnd', cwd: dir, sessionId: id, payload: const {}));
    }
    _publisher?.publishSession(sessionRelay());
  }

  /// A step that flipped to done on disk — `kit step done` from the
  /// session, or the phone — reaches the phone once, on its own channel.
  void _notifyFlips(Plan plan) {
    final pub = _publisher;
    if (pub == null) return;
    for (final s in flippedDone(pub.lastChanges, plan)) {
      _notify(noticeForStep(number: s.number ?? s.id, title: s.title, project: projectName));
    }
  }

  /// A command from the phone. `answer` lands on the pending ask only if it
  /// is still the one the phone saw; `send`, `start` and `stop` are what
  /// the Deck's buttons do here.
  Future<String> applyCommand(Map<String, Object?> cmd) async {
    switch (cmd['type']) {
      case 'answer':
        final requestId = (cmd['requestId'] ?? '').toString();
        if (bridge.transcript.pending?.requestId != requestId) {
          // Close it in the relay too, so no phone keeps offering it.
          final pub = _publisher;
          if (requestId.isNotEmpty && pub != null) unawaited(pub.resolveAsk(requestId, summary: 'Stale — no longer pending', by: 'host'));
          _withdraw(requestId);
          return 'stale: that ask was already answered';
        }
        bridge.answer(AskAnswer.fromMap(cmd), requestId: requestId, by: (cmd['from'] ?? 'phone').toString(), remember: cmd['remember'] == true);
        return 'answered';
      case 'send':
        // A send that waited on a Mac that was gone finds no process when
        // the Mac is back — the session died with it. It was live when the
        // phone sent, so the last conversation is resumed first.
        if (!bridge.running && bridge.previous()?.sessionId != null) {
          await bridge.start(resume: true);
          if (!await bridge.awaitReady()) {
            // Nothing to resume — the session died before it ever spoke,
            // so the CLI never wrote it down. A fresh one loses nothing.
            final reason = bridge.error ?? 'the session did not come up';
            await bridge.start();
            if (!await bridge.awaitReady()) return 'not running: $reason';
          }
        }
        if (!bridge.running) return 'not running';
        final about = cmd['about'];
        // The files the phone put in the bucket first, back whole.
        final ups = [
          for (final u in (cmd['uploads'] as List? ?? const []))
            if (u is Map) {for (final e in u.entries) e.key.toString(): e.value as Object?},
        ];
        final store = blobs;
        if (ups.isNotEmpty && store == null) return 'failed: this host has no bucket';
        final reader = store == null ? null : UploadReader(store, slug!);
        final files = <PendingAttachment>[for (final u in ups) await reader!.fetch(u)];
        final queued = bridge.send((cmd['text'] ?? '').toString(), about: about is Map ? {for (final e in about.entries) e.key.toString(): e.value} : null, files: files);
        for (final u in ups) {
          unawaited(reader!.delete(u).catchError((Object _) {}));
        }
        final verb = queued ? 'queued' : 'sent';
        return ups.isEmpty ? verb : '$verb with ${ups.length} file${ups.length == 1 ? '' : 's'}';
      case 'interrupt':
        autopilot.stop(by: 'INTERRUPT');
        return bridge.interrupt(by: cmd['from'] == 'phone' ? 'phone' : 'Mac') ? 'interrupted' : 'nothing to interrupt';
      case 'withdraw':
        return bridge.withdrawQueued((cmd['messageId'] ?? '').toString()) ? 'withdrawn' : 'already sent';
      case 'start':
        // A fresh conversation has nothing pending; a resumed one neither.
        final sweep = _publisher;
        if (sweep != null) unawaited(_sweepAsks(sweep));
        await bridge.start(resume: cmd['resume'] == true);
        return bridge.error ?? (bridge.running ? 'started' : 'did not start');
      case 'stop':
        autopilot.stop(by: 'Stop');
        await bridge.stop();
        return 'stopped';
      case 'autopilot':
        // `{type: autopilot, on, budget?, nightShift?}` — the toggle on
        // either device; off is immediate, on starts the run.
        if (cmd['on'] != true) return autopilot.stop(by: cmd['from'] == 'phone' ? 'the phone' : 'the Mac');
        return autopilot.start(budget: (cmd['budget'] as num?)?.toInt(), nightShift: cmd['nightShift'] as bool?);
      case 'options':
        final ok = bridge.setOptions(mode: cmd['mode'] as String?, chrome: cmd['chrome'] as bool?, model: cmd['model'] as String?, effort: cmd['effort'] as String?);
        if (!ok) return 'nothing to change';
        if (bridge.restartPending) return 'applies when this turn ends';
        if (bridge.modePending || bridge.modelPending) return 'applies when this turn ends';
        if (!bridge.running) return 'options saved';
        return cmd['chrome'] == null && cmd['effort'] == null ? 'switched in place' : 'restarting on the same conversation';
      case 'push-test':
        return testPush();
      case 'compact':
        return bridge.compact();
      case 'host':
        return _hostAction(cmd);
      case 'mirror':
        // `{type: mirror, action: frame}` — one frame now.
        return cmd['action'] == 'frame' ? mirror.frame() : 'unknown mirror action ${cmd['action']}';
      case 'input':
        // `{type: input, action: tap|swipe|text|key, x, y, x2, y2, text}` in device pixels.
        return mirror.input(cmd);
      case 'run':
        // `{type: run, action: start|reload|restart|stop|devices|reload_on_edit, device?, on?}`.
        switch (cmd['action']) {
          case 'start':
            return run.start(device: cmd['device']?.toString());
          case 'reload':
            return run.reload();
          case 'restart':
            return run.reload(full: true);
          case 'stop':
            return run.stop();
          case 'devices':
            final list = await run.devices();
            return '${list.length} device${list.length == 1 ? '' : 's'}';
          case 'reload_on_edit':
            run.setReloadOnEdit(cmd['on'] == true);
            return 'reload on edit ${cmd['on'] == true ? 'on' : 'off'}';
          default:
            return 'unknown run action ${cmd['action']}';
        }
      default:
        return 'unknown command ${cmd['type']}';
    }
  }

  /// `{type: host, action: read_file|git, …}` — the host's own hands.
  Future<String> _hostAction(Map<String, Object?> cmd) async {
    final id = (cmd['id'] ?? '').toString();
    switch (cmd['action']) {
      case 'read_file':
        final path = (cmd['path'] ?? '').toString();
        final r = files.read(path);
        final doc = r.toMap();
        if (r.ok && r.truncated) {
          // The whole file rides in Storage; the document keeps the start.
          final store = blobs;
          final s = slug;
          final abs = files.resolve(path);
          if (store != null && s != null && abs != null && id.isNotEmpty) {
            final blobPath = 'projects/$s/files/$id';
            try {
              await store.put(blobPath, File(abs).readAsBytesSync(), contentType: 'text/plain');
              doc['blob'] = blobPath;
            } on Object {
              // The first part still shows, and says it is the first part.
            }
          }
        }
        final pub = _publisher;
        if (id.isNotEmpty && pub != null) await pub.publishFile(id, doc);
        if (!r.ok) return 'refused: ${r.refused}';
        return r.truncated ? 'read — the first ${fileInlineBytes ~/ 1024} KB inline' : 'read';
      case 'git':
        final op = (cmd['op'] ?? '').toString();
        final message = cmd['message']?.toString();
        final path = cmd['path']?.toString();
        final GitResult r;
        switch (op) {
          case 'commit':
            r = await git.commit(message ?? '');
          case 'push':
            r = await git.push();
          case 'revert':
            r = await git.revertFile(path ?? '');
          default:
            return 'unknown git op $op';
        }
        final first = r.output.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => r.ok ? 'ok' : 'failed');
        bridge.addHostRow(toolName: 'git', input: {'op': op, 'message': ?message, 'path': ?path}, result: r.output.isEmpty ? (r.ok ? 'ok' : 'failed') : r.output, isError: !r.ok);
        bridge.noteHostAction('git $op${message != null ? ' "$message"' : ''}${path != null ? ' $path' : ''} — ${r.ok ? 'ok' : 'failed'}: $first');
        _refreshGit(soon: true);
        return r.ok ? 'ok: $first' : 'failed: $first';
      default:
        return 'unknown host action ${cmd['action']}';
    }
  }

  Future<void> _onPlan() async {
    final plan = source.plan;
    if (plan == null) return;
    slug ??= slugFor(plan.manifest);
    if (_publisher == null) {
      _publisher = RelayPublisher(db, slug!, dir: dir, machine: machine);
      // The truth about the session, first thing: a relaunched host must
      // overwrite the LIVE a dead process left on the mirror.
      unawaited(_publisher!.publishSession(sessionRelay()));
      // Files a phone put up and nobody collected.
      final store = blobs;
      if (store != null) unawaited(UploadReader(store, slug!).prune().catchError((Object _) => 0));
      // Asks a dead process left open: nothing can answer them now.
      unawaited(_sweepAsks(_publisher!));
    }
    _inbox ??= InboxListener(db, slug!, apply: applyBatch)..start();
    _commands ??= CommandListener(db, slug!, apply: applyCommand)..start();
    _mirrorWatch ??= _publisher!.watchMirror(mirror.watching);
    if (_publishing) {
      _dirty = true;
      return;
    }
    _publishing = true;
    try {
      do {
        _dirty = false;
        relayStatus = 'publishing…';
        notifyListeners();
        final n = await _publisher!.publish(source.plan!);
        relayStatus = n == 0 ? 'mirror up to date' : 'published $n document${n == 1 ? '' : 's'}';
        relayError = null;
        _stampThreadUpdate();
        _notifyFlips(source.plan!);
      } while (_dirty);
    } on Object catch (e) {
      relayError = e.toString();
      relayStatus = 'publish failed';
    } finally {
      _publishing = false;
      notifyListeners();
    }
  }

  /// A mirrored plan change to the thing the last scoped message was about
  /// becomes the thread's UPDATED row — the strip the card shows.
  void _stampThreadUpdate() {
    final about = bridge.transcript.lastAbout;
    final key = threadKey(about);
    final pub = _publisher;
    if (key == null || about == null || pub == null) return;
    final docKey = key.startsWith('item:') ? 'items/${key.substring(5)}' : 'steps/${key.substring(5)}';
    final fields = pub.lastChanges[docKey];
    if (fields == null || fields.isEmpty) return;
    unawaited(pub.publishThreadUpdate(about, fields));
  }

  /// Applies a batch from the phone with the same code as `kit inbox`, then
  /// regenerates the plan markdown and the board HTML so Claude's next
  /// `/board` publishes what the phone did.
  Future<InboxResult> applyBatch(Map<String, Object?> batch) async {
    final r = applyInbox(source.store, batch, today: _today());
    try {
      final plan = source.store.load();
      File(p.join(dir, plan.manifest.planMarkdown)).writeAsStringSync(renderPlanMarkdown(plan));
      File(p.join(dir, plan.manifest.boardOutput))
        ..createSync(recursive: true)
        ..writeAsStringSync(renderBoardHtml(plan, today: _today()));
    } on Object {
      // The batch is applied; the rendered views are a convenience.
    }
    applied.insert(0, '${DateTime.now().toIso8601String().substring(11, 16)} — ${r.summary}');
    if (applied.length > 20) applied.removeLast();
    source.reload();
    notifyListeners();
    return r;
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  void _onSession() {
    _holdWhile(running: session.running, pid: session.pid);
    _publisher?.publishSession(sessionRelay());
    notifyListeners();
  }

  /// The Mac stays awake as long as the process with [pid] runs.
  void _holdWhile({required bool running, required int? pid}) {
    final pw = power;
    if (pw == null || pid == null) return;
    if (running) {
      unawaited(pw.hold(pid));
    } else {
      pw.release(pid);
    }
  }

  void _onHook(HookEvent e) {
    _refreshGit();
    final pub = _publisher;
    if (pub == null) return;
    pub.publishNow(e);
    if (e.name != 'PreToolUse' && e.name != 'PostToolUse') pub.publishMilestone(e);
    // `kit notify` from the session: a line for the phone, on purpose.
    if (e.name == 'Notify' && e.summary.isNotEmpty) _notify(noticeForNote(e.summary, project: projectName));
  }

  @override
  void dispose() {
    source.removeListener(_onPlan);
    session.removeListener(_onSession);
    bridge.removeListener(_onBridge);
    autopilot.removeListener(_onAutopilot);
    autopilot.dispose();
    run.removeListener(_onRun);
    run.dispose();
    mirror.removeListener(notifyListeners);
    _mirrorWatch?.cancel();
    mirror.dispose();
    _inbox?.dispose();
    _commands?.dispose();
    _publisher?.dispose();
    hooks.dispose();
    _gitTimer?.cancel();
    session.dispose();
    bridge.dispose();
    source.dispose();
    super.dispose();
  }
}
