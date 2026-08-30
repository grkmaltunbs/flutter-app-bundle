import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;

import '../plan_source.dart';
import '../relay.dart';
import 'bridge_session.dart';
import 'claude_cli.dart';
import 'hook_watcher.dart';
import 'remote_control.dart';

/// Everything the host runs for one open project: the plan on disk, its
/// mirror, the inbox, the hook spool, and the two ways the folder gets a
/// Claude session — the bridge (this app talks to it) and Remote Control
/// (the Claude app does).
class HostProject extends ChangeNotifier {
  HostProject({required this.dir, required this.db});

  final String dir;
  final FirebaseFirestore db;
  late final LocalPlanSource source = LocalPlanSource(dir);
  late final HookWatcher hooks = HookWatcher(dir);
  late final RemoteControlSession session = RemoteControlSession(dir: dir, name: p.basename(dir));
  late final BridgeSession bridge = BridgeSession(dir: dir);
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
    hooks.onEvent = _onHook;
    source.start();
    hooks.start();
  }

  /// What the phone sees as the session: the bridge while it runs, else
  /// Remote Control, else idle.
  Map<String, Object?> sessionRelay() {
    if (bridge.running) return bridge.toRelay();
    if (session.running) return {...session.toRelay(), 'mode': 'remote', 'pendingAsks': 0};
    // Idle carries the bridge's record too, so the phone still offers
    // Resume after the host restarted.
    return {...session.toRelay(), ...bridge.toRelay(), 'mode': 'idle', 'pendingAsks': 0};
  }

  void _onBridge() {
    _publisher?.publishSession(sessionRelay());
    _publisher?.publishTranscript(bridge.transcript);
    final pub = _publisher;
    if (pub != null) unawaited(pub.publishThreads(bridge.transcript));
    notifyListeners();
  }

  void _onAsk(Ask ask) => _publisher?.publishAsk(ask);

  void _onAnswered(Ask ask, AskAnswer a, String by) => _publisher?.resolveAsk(ask.requestId, summary: a.summary, by: by);

  /// A command from the phone. `answer` lands on the pending ask only if it
  /// is still the one the phone saw; `send`, `start` and `stop` are what
  /// the Deck's buttons do here.
  Future<String> applyCommand(Map<String, Object?> cmd) async {
    switch (cmd['type']) {
      case 'answer':
        final requestId = (cmd['requestId'] ?? '').toString();
        if (bridge.transcript.pending?.requestId != requestId) return 'stale: that ask was already answered';
        bridge.answer(AskAnswer.fromMap(cmd), requestId: requestId, by: (cmd['from'] ?? 'phone').toString(), remember: cmd['remember'] == true);
        return 'answered';
      case 'send':
        if (!bridge.running) return 'not running';
        final about = cmd['about'];
        bridge.send((cmd['text'] ?? '').toString(), about: about is Map ? {for (final e in about.entries) e.key.toString(): e.value} : null);
        return 'sent';
      case 'start':
        await bridge.start(resume: cmd['resume'] == true);
        return bridge.error ?? (bridge.running ? 'started' : 'did not start');
      case 'stop':
        await bridge.stop();
        return 'stopped';
      default:
        return 'unknown command ${cmd['type']}';
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
    }
    _inbox ??= InboxListener(db, slug!, apply: applyBatch)..start();
    _commands ??= CommandListener(db, slug!, apply: applyCommand)..start();
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
    _publisher?.publishSession(sessionRelay());
    notifyListeners();
  }

  void _onHook(HookEvent e) {
    final pub = _publisher;
    if (pub == null) return;
    pub.publishNow(e);
    if (e.name != 'PreToolUse' && e.name != 'PostToolUse') pub.publishMilestone(e);
  }

  @override
  void dispose() {
    source.removeListener(_onPlan);
    session.removeListener(_onSession);
    bridge.removeListener(_onBridge);
    _inbox?.dispose();
    _commands?.dispose();
    _publisher?.dispose();
    hooks.dispose();
    session.dispose();
    bridge.dispose();
    source.dispose();
    super.dispose();
  }
}
