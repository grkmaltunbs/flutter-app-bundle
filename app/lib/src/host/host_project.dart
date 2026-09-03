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
import 'bridge_session.dart';
import 'claude_cli.dart';
import 'hook_watcher.dart';
import 'push_sender.dart';
import 'remote_control.dart';

/// Everything the host runs for one open project: the plan on disk, its
/// mirror, the inbox, the hook spool, and the two ways the folder gets a
/// Claude session — the bridge (this app talks to it) and Remote Control
/// (the Claude app does).
class HostProject extends ChangeNotifier {
  HostProject({required this.dir, required this.db, this.push, this.blobs});

  final String dir;
  final FirebaseFirestore db;

  /// The bucket the phone's files come from; null in a test without one.
  final BlobStore? blobs;

  /// The Mac's one push sender, shared by every open project; null in a
  /// test that has no phone to reach.
  final PushSender? push;
  final TurnWatch _turns = TurnWatch();
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
    bridge.onWithdrawn = (ask) => _publisher?.resolveAsk(ask.requestId, summary: 'Withdrawn — the session stopped', by: 'host');
    hooks.onEvent = _onHook;
    source.start();
    hooks.start();
    push?.start();
  }

  /// The project as a notification names it.
  String get projectName => source.plan?.manifest.projectName ?? p.basename(dir);

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
    final turn = _turns.check(state: bridge.state, error: bridge.error, lastResult: bridge.transcript.lastResult, project: projectName);
    if (turn != null) _notify(turn);
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
        bridge.send((cmd['text'] ?? '').toString(), about: about is Map ? {for (final e in about.entries) e.key.toString(): e.value} : null, files: files);
        for (final u in ups) {
          unawaited(reader!.delete(u).catchError((Object _) {}));
        }
        return ups.isEmpty ? 'sent' : 'sent with ${ups.length} file${ups.length == 1 ? '' : 's'}';
      case 'start':
        // A fresh conversation has nothing pending; a resumed one neither.
        final sweep = _publisher;
        if (sweep != null) unawaited(_sweepAsks(sweep));
        await bridge.start(resume: cmd['resume'] == true);
        return bridge.error ?? (bridge.running ? 'started' : 'did not start');
      case 'stop':
        await bridge.stop();
        return 'stopped';
      case 'options':
        final ok = bridge.setOptions(skipPermissions: cmd['skipPermissions'] as bool?, chrome: cmd['chrome'] as bool?, model: cmd['model'] as String?, effort: cmd['effort'] as String?);
        if (!ok) return 'nothing to change';
        if (bridge.restartPending) return 'applies when this turn ends';
        return bridge.running ? 'restarting on the same conversation' : 'options saved';
      case 'push-test':
        return testPush();
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
      // Files a phone put up and nobody collected.
      final store = blobs;
      if (store != null) unawaited(UploadReader(store, slug!).prune().catchError((Object _) => 0));
      // Asks a dead process left open: nothing can answer them now.
      unawaited(_sweepAsks(_publisher!));
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
    _publisher?.publishSession(sessionRelay());
    notifyListeners();
  }

  void _onHook(HookEvent e) {
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
