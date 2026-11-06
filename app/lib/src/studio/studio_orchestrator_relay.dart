import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart' show Ask, AskAnswer, Notice, NoticeKind, noticeForAsk;

import '../attachments.dart';
import '../blobs.dart';
import '../host/bridge_session.dart';
import '../host/push_sender.dart';
import '../relay.dart';
import 'studio_orchestrator.dart';
import 'studio_schedule.dart';

// The orchestrator on the phone, part 2. The Mac publishes the orchestrator's
// session the way a project's is published — `projects/studio-orchestrator`:
// the session, the conversation, the asks, the sessions list — so the phone's
// own Deck (RemoteDeckTab) drives it unchanged; and it carries out what the
// phone sends to `…/commands`: send, answer, start, stop, interrupt, options.
// The review loop and the timed orders ride on the same document, and the
// phone sets them with `{type: studio, action: …}` commands. An ask is a push
// too, as for a project. The document is marked `studio: true`, so the
// phone's project list leaves it out.

const kOrchestratorSlug = 'studio-orchestrator';

class OrchestratorRelay {
  OrchestratorRelay({required this.db, required this.bridge, required this.machine, required this.dir, this.push, this.blobs, this.loop, required this.schedule});

  final FirebaseFirestore db;
  final BridgeSession bridge;
  final String machine;
  final String dir;
  final PushSender? push;
  final BlobStore? blobs;
  final ReviewLoop? loop;
  final StudioSchedule schedule;

  late final RelayPublisher publisher = RelayPublisher(db, kOrchestratorSlug, dir: dir, machine: machine, name: 'Orchestrator');
  CommandListener? _commands;
  Timer? _extrasTimer;

  DocumentReference<Map<String, dynamic>> get ref => db.collection('projects').doc(kOrchestratorSlug);

  void start() {
    unawaited(ref.set({'studio': true, 'name': 'Orchestrator', 'machine': machine}, SetOptions(merge: true)).catchError((Object _) {}));
    bridge
      ..onAsk = _onAsk
      ..onAnswered = _onAnswered
      ..onWithdrawn = (ask) {
        unawaited(publisher.resolveAsk(ask.requestId, summary: 'Withdrawn', by: 'host').catchError((Object _) {}));
        _withdraw(ask.requestId);
      };
    bridge.addListener(_onBridge);
    loop?.addListener(_extrasSoon);
    schedule.addListener(_extrasSoon);
    // The truth first: a relaunched Mac overwrites a LIVE a dead process left.
    _onBridge();
    _publishExtras();
    unawaited(_sweep());
    _commands = CommandListener(db, kOrchestratorSlug, apply: apply)..start();
  }

  void stop() {
    bridge.removeListener(_onBridge);
    loop?.removeListener(_extrasSoon);
    schedule.removeListener(_extrasSoon);
    _commands?.dispose();
    _extrasTimer?.cancel();
  }

  Map<String, Object?> _session() => bridge.running ? bridge.toRelay() : {...bridge.toRelay(), 'mode': 'idle', 'pendingAsks': 0};

  void _onBridge() {
    unawaited(publisher.publishSession(_session()).catchError((Object _) {}));
    publisher.publishTranscript(bridge.transcript);
    unawaited(publisher.publishSessions(bridge.sessionsRelay).catchError((Object _) {}));
  }

  void _extrasSoon() {
    _extrasTimer?.cancel();
    _extrasTimer = Timer(const Duration(milliseconds: 300), _publishExtras);
  }

  /// The review loop's switch and the schedule, for the phone's bar.
  void _publishExtras() {
    final l = loop;
    unawaited(ref.set({
      'studioLoop': l == null ? null : {'on': l.on, 'why': l.why},
      'schedule': [for (final o in schedule.sorted.take(60)) o.toJson()],
    }, SetOptions(merge: true)).catchError((Object _) {}));
  }

  void _onAsk(Ask ask) {
    unawaited(publisher.publishAsk(ask).catchError((Object _) {}));
    final ps = push;
    if (ps != null) unawaited(ps.send(noticeForAsk(ask, project: 'Orchestrator'), slug: kOrchestratorSlug, project: 'Orchestrator').catchError((Object _) => 0));
  }

  void _onAnswered(Ask ask, AskAnswer a, String by) {
    unawaited(publisher.resolveAsk(ask.requestId, summary: a.summary, by: by).catchError((Object _) {}));
    _withdraw(ask.requestId);
  }

  void _withdraw(String requestId) {
    final ps = push;
    if (ps == null || requestId.isEmpty) return;
    unawaited(ps.withdraw(requestId, slug: kOrchestratorSlug).catchError((Object _) => 0));
  }

  Future<void> _sweep() async {
    try {
      for (final id in await publisher.withdrawOpenAsks()) {
        _withdraw(id);
      }
    } catch (_) {}
  }

  /// What the phone sends. The Deck's own commands, as a project's host
  /// carries them out, and `{type: studio, action: loop|schedule-add|
  /// schedule-cancel|schedule-delete}` for the bar.
  Future<String> apply(Map<String, Object?> cmd) async {
    switch (cmd['type']) {
      case 'answer':
        final requestId = (cmd['requestId'] ?? '').toString();
        if (bridge.transcript.pending?.requestId != requestId) {
          if (requestId.isNotEmpty) unawaited(publisher.resolveAsk(requestId, summary: 'Stale — no longer pending', by: 'host').catchError((Object _) {}));
          _withdraw(requestId);
          return 'stale: that ask was already answered';
        }
        bridge.answer(AskAnswer.fromMap(cmd), requestId: requestId, by: (cmd['from'] ?? 'phone').toString(), remember: cmd['remember'] == true);
        return 'answered';
      case 'send':
        if (!bridge.running) {
          await bridge.start(resume: bridge.sessionId != null);
          if (!await bridge.awaitReady(timeout: const Duration(seconds: 30))) return 'not running: ${bridge.error ?? 'the orchestrator did not start'}';
        }
        final ups = [
          for (final u in (cmd['uploads'] as List? ?? const []))
            if (u is Map) {for (final e in u.entries) e.key.toString(): e.value as Object?},
        ];
        final store = blobs;
        if (ups.isNotEmpty && store == null) return 'failed: this host has no bucket';
        final reader = store == null ? null : UploadReader(store, kOrchestratorSlug);
        final files = <PendingAttachment>[for (final u in ups) await reader!.fetch(u)];
        final queued = bridge.send((cmd['text'] ?? '').toString(), files: files, by: (cmd['from'] ?? 'phone').toString());
        for (final u in ups) {
          unawaited(reader!.delete(u).catchError((Object _) {}));
        }
        return queued ? 'queued' : 'sent';
      case 'interrupt':
        return bridge.interrupt(by: 'phone') ? 'interrupted' : 'nothing to interrupt';
      case 'withdraw':
        return bridge.withdrawQueued((cmd['messageId'] ?? '').toString()) ? 'withdrawn' : 'already sent';
      case 'start':
        unawaited(_sweep());
        final id = cmd['sessionId']?.toString();
        if (id != null || cmd['new'] == true) return bridge.switchTo(id: id);
        await bridge.start(resume: cmd['resume'] == true);
        return bridge.error ?? (bridge.running ? 'started' : 'did not start');
      case 'session':
        if (cmd['action'] != 'delete') return 'unknown session action ${cmd['action']}';
        return bridge.deleteSession((cmd['sessionId'] ?? '').toString()) ? 'removed from the list' : 'not removed — it is running, or not in the list';
      case 'stop':
        await bridge.stop();
        return 'stopped';
      case 'options':
        final ok = bridge.setOptions(mode: cmd['mode'] as String?, chrome: cmd['chrome'] as bool?, model: cmd['model'] as String?, effort: cmd['effort'] as String?, engine: cmd['engine'] as String?);
        if (!ok) return 'nothing to change';
        if (bridge.restartPending || bridge.modePending || bridge.modelPending) return 'applies when this turn ends';
        return bridge.running ? 'switched' : 'options saved';
      case 'brief':
        return bridge.setBrief(cmd['text']?.toString());
      case 'compact':
        return bridge.compact();
      case 'push-test':
        final ps = push;
        if (ps == null) return 'no push on this Mac';
        final n = await ps.send(const Notice(kind: NoticeKind.done, title: 'Test push · Orchestrator', body: 'The Mac reaches this phone.'), slug: kOrchestratorSlug);
        return n > 0 ? 'sent to $n phone${n == 1 ? '' : 's'}' : (ps.lastError ?? 'nothing sent');
      case 'studio':
        return _studio(cmd);
      default:
        return 'not on the orchestrator: ${cmd['type']}';
    }
  }

  String _studio(Map<String, Object?> cmd) {
    switch (cmd['action']) {
      case 'loop':
        final l = loop;
        if (l == null) return 'no review loop here';
        l.set(cmd['on'] == true);
        return l.on ? 'review loop on' : 'review loop off';
      case 'schedule-add':
        final o = cmd['order'];
        if (o is! Map) return 'no order';
        final order = TimedOrder.fromJson({for (final e in o.entries) e.key.toString(): e.value as Object?});
        schedule.add(order);
        return 'scheduled';
      case 'schedule-cancel':
        schedule.cancel((cmd['orderId'] ?? '').toString());
        return 'cancelled';
      case 'schedule-delete':
        schedule.delete((cmd['orderId'] ?? '').toString());
        return 'removed';
      default:
        return 'unknown studio action ${cmd['action']}';
    }
  }
}

/// The phone's side of the bar: the loop's switch and the schedule as the
/// Mac publishes them, changed by commands the Mac carries out.
class RemoteOrchestrator extends ChangeNotifier implements LoopApi, ScheduleApi {
  RemoteOrchestrator(this.db) : _sender = CommandSender(db, kOrchestratorSlug);
  final FirebaseFirestore db;
  final CommandSender _sender;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  Map<String, dynamic> _doc = const {};

  void start() {
    _sub = db.collection('projects').doc(kOrchestratorSlug).snapshots().listen((d) {
      _doc = d.data() ?? const {};
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Whether the Mac publishes the orchestrator at all.
  bool get published => _doc.isNotEmpty;

  /// Sends a command and waits (up to [wait]) for the Mac's one-line result.
  Future<String> command(Map<String, Object?> cmd, {Duration wait = const Duration(seconds: 40)}) async {
    final ref = await _sender.send(cmd, from: 'phone');
    try {
      final done = await ref.snapshots().firstWhere((d) => d.data()?['doneAt'] != null).timeout(wait);
      return (done.data()?['result'] ?? 'done').toString();
    } on TimeoutException {
      return 'sent — the Mac has not answered yet';
    }
  }

  /// A message (or an autopilot command line) to the orchestrator.
  Future<String> send(String text) => command({'type': 'send', 'text': text});

  // LoopApi
  Map<String, dynamic> get _loop => (_doc['studioLoop'] as Map?)?.cast<String, dynamic>() ?? const {};
  @override
  bool get on => _loop['on'] == true;
  @override
  String get why => (_loop['why'] ?? (published ? 'off' : 'the Mac has not published the orchestrator')).toString();
  @override
  void set(bool value) => unawaited(command({'type': 'studio', 'action': 'loop', 'on': value}));

  // ScheduleApi
  @override
  List<TimedOrder> get orders => [
        for (final o in (_doc['schedule'] as List? ?? const []))
          if (o is Map) TimedOrder.fromJson(o.cast<String, Object?>()),
      ];
  @override
  List<TimedOrder> get sorted => orders;
  @override
  int get upcoming => orders.where((o) => o.active).length;
  @override
  Duration get grace => const Duration(minutes: 30);
  @override
  void add(TimedOrder o) => unawaited(command({'type': 'studio', 'action': 'schedule-add', 'order': o.toJson()}));
  @override
  void cancel(String id) => unawaited(command({'type': 'studio', 'action': 'schedule-cancel', 'orderId': id}));
  @override
  void delete(String id) => unawaited(command({'type': 'studio', 'action': 'schedule-delete', 'orderId': id}));
}
