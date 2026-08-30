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
    hooks.onEvent = _onHook;
    source.start();
    hooks.start();
  }

  void _onBridge() => notifyListeners();

  Future<void> _onPlan() async {
    final plan = source.plan;
    if (plan == null) return;
    slug ??= slugFor(plan.manifest);
    _publisher ??= RelayPublisher(db, slug!, dir: dir, machine: machine);
    _inbox ??= InboxListener(db, slug!, apply: applyBatch)..start();
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
      } while (_dirty);
    } on Object catch (e) {
      relayError = e.toString();
      relayStatus = 'publish failed';
    } finally {
      _publishing = false;
      notifyListeners();
    }
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
    _publisher?.publishSession(session.toRelay());
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
    _publisher?.dispose();
    hooks.dispose();
    session.dispose();
    bridge.dispose();
    source.dispose();
    super.dispose();
  }
}
