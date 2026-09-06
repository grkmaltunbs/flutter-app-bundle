import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';

import 'attachments.dart';
import 'blobs.dart';
import 'host/bridge_session.dart' show BridgeState;
import 'host/host_actions.dart';
import 'presence.dart';

/// The relay: Firestore on `flutterappbundle`, one user, owner-only rules.
///
/// ```
/// projects/{slug}                 manifest, dir, machine, session, now, counts
/// projects/{slug}/steps/{id}      Step.toMap()
/// projects/{slug}/items/{id}      Item.toMap()
/// projects/{slug}/inbox/{auto}    a batch from the phone; the host stamps appliedAt
/// projects/{slug}/events/{auto}   milestones from hooks (prompt, stop, notification)
/// projects/{slug}/asks/{requestId} an Ask the bridge raised; the host stamps answeredAt, answer, by
/// projects/{slug}/commands/{auto} phone → host: {type: answer|send|start|stop|interrupt|withdraw|options|push-test|compact|autopilot|host, …}; withdraw names a queued messageId; options carry mode, chrome, model, effort; autopilot carries on, budget?, nightShift?; host carries action: read_file (path) | git (op: commit|push|revert, message?, path?); the host stamps doneAt, result
/// projects/{slug}/files/{commandId} the host's answer to a read_file: FileRead.toMap() — {path, text, lines, bytes, truncated, blob?, refused?}; the phone deletes it once read
/// projects/{slug}/chat/{messageId} the transcript, one DeckMessage.toMap() per row, the last 300
/// projects/{slug}/runs/{runId}/log/{chunk} the run bay's log: {from, lines} — 200 lines a document, the last 10 documents kept, one write a second at most; the phone joins them in order
/// projects/{slug}/threads/{about}   `item:<id>` or `step:<id>`: {about, count, last, updated}
/// projects/{slug}/threads/{about}/messages/{sessionId-messageId}  the scoped rows, kept forever
/// hosts/{hostId}                   the Mac's heartbeat: {seenAt, name, appVersion, cli, projects, sessions, stopping}; the phone reads "unreachable" from its age
/// devices/{fcmToken}                a phone that takes pushes: {platform, name, uid, registeredAt, seenAt}; the host drops one FCM no longer knows
/// ```
///
/// Bytes are not rows: a file from the phone goes into Firebase Storage
/// under `projects/{slug}/uploads/{id}/{name}` (`blobs.dart`) and the
/// `send` command names it; the host fetches, saves and deletes it.
///
/// The host is the only writer of `asks`, `chat` and `session`; the phone
/// only ever writes `inbox`, `commands` and its own `devices` row, and puts
/// objects in the bucket.
class ProjectSummary {
  ProjectSummary({required this.slug, required this.name, required this.dir, required this.machine, required this.session, required this.now, required this.counts, this.updatedAt});

  factory ProjectSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    Map<String, Object?> map(Object? v) => v is Map ? {for (final e in v.entries) e.key.toString(): e.value} : {};
    return ProjectSummary(
      slug: d.id,
      name: (m['name'] ?? d.id).toString(),
      dir: (m['dir'] ?? '').toString(),
      machine: (m['machine'] ?? '').toString(),
      session: map(m['session']),
      now: map(m['now']),
      counts: map(m['counts']),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String slug;
  final String name;
  final String dir;
  final String machine;
  final Map<String, Object?> session;
  final Map<String, Object?> now;
  final Map<String, Object?> counts;
  final DateTime? updatedAt;

  String? get sessionUrl => session['sessionUrl']?.toString();
  String? get environmentUrl => session['environmentUrl']?.toString();
  String get sessionState => (session['state'] ?? 'idle').toString();

  /// `bridge` when this app drives the session, `remote` for the Claude app.
  String get mode => (session['mode'] ?? (sessionState == 'connected' ? 'remote' : 'idle')).toString();
  bool get live => mode == 'bridge' || sessionState == 'connected';
  int get pendingAsks => (session['pendingAsks'] as num?)?.toInt() ?? 0;
}

/// Writes the plan mirror. Keeps the stable JSON of every document it has
/// published, so a reload that changed two files writes two documents.
class RelayPublisher {
  RelayPublisher(this.db, this.slug, {required this.dir, required this.machine});

  final FirebaseFirestore db;
  final String slug;
  final String dir;
  final String machine;
  final Map<String, String> _published = {};
  bool _seeded = false;
  Timer? _nowTimer;
  Map<String, Object?>? _pendingNow;

  DocumentReference<Map<String, dynamic>> get ref => db.collection('projects').doc(slug);

  /// What the last [publish] changed, per document — `items/presence` →
  /// `[body, needs]`. The host turns a change to the thing a thread is
  /// about into the thread's UPDATED row.
  final Map<String, List<String>> lastChanges = {};

  /// Reads what is already there once, so a host restart does not rewrite
  /// every document it already published.
  Future<void> seed() async {
    if (_seeded) return;
    for (final coll in const ['steps', 'items']) {
      final q = await ref.collection(coll).get();
      for (final d in q.docs) {
        _published['$coll/${d.id}'] = stableJson(d.data());
      }
    }
    _seeded = true;
  }

  /// Returns the number of documents written or deleted.
  Future<int> publish(Plan plan) async {
    await seed();
    lastChanges.clear();
    final wanted = <String, Map<String, Object?>>{
      for (final s in plan.steps) 'steps/${s.id}': stepDoc(s),
      for (final i in plan.items) 'items/${i.id}': itemDoc(i),
    };
    final ops = <void Function(WriteBatch)>[];
    for (final e in wanted.entries) {
      final json = stableJson(e.value);
      if (_published[e.key] == json) continue;
      final before = _published[e.key];
      if (before != null) {
        final old = jsonDecode(before) as Map;
        final fields = <String>[
          for (final k in {...old.keys.map((k) => k.toString()), ...e.value.keys})
            if (stableJson({'v': old[k]}) != stableJson({'v': e.value[k]})) k,
        ];
        if (fields.isNotEmpty) lastChanges[e.key] = fields;
      }
      final parts = e.key.split('/');
      ops.add((b) => b.set(ref.collection(parts[0]).doc(parts[1]), e.value));
      _published[e.key] = json;
    }
    for (final key in _published.keys.toList()) {
      if (wanted.containsKey(key)) continue;
      final parts = key.split('/');
      ops.add((b) => b.delete(ref.collection(parts[0]).doc(parts[1])));
      _published.remove(key);
    }
    final open = plan.items.where((i) => i.isOpen).length;
    final manifest = manifestDoc(plan.manifest);
    ops.add((b) => b.set(ref, {
          'name': plan.manifest.projectName,
          'slug': slug,
          'dir': dir,
          'machine': machine,
          'manifest': manifest,
          'counts': {'steps': plan.steps.length, 'done': plan.steps.where((s) => s.status == StepStatus.done).length, 'items': plan.items.length, 'open': open},
          'revision': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));
    // A batch takes 500 operations; stay well under.
    for (var i = 0; i < ops.length; i += 400) {
      final b = db.batch();
      for (final op in ops.sublist(i, (i + 400).clamp(0, ops.length))) {
        op(b);
      }
      await b.commit();
    }
    return ops.length - 1;
  }

  Future<void> publishSession(Map<String, Object?> session) =>
      ref.set({'session': session, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  /// The run's log, in documents of [logChunk] lines under
  /// `runs/{runId}/log/{chunk}`, the last [logChunks] kept — coalesced
  /// to one write a second, and only the documents that grew.
  static const logChunk = 200;
  static const logChunks = 10;
  String? _logRun;
  int _logSeq = 0;
  RunLog? _logSource;
  Timer? _logTimer;
  bool _logDirty = false;
  bool _logFlushing = false;

  void publishRunLog(String runId, RunLog log) {
    if (_logRun != runId) {
      _logRun = runId;
      _logSeq = 0;
    }
    _logSource = log;
    if (_logTimer != null) {
      _logDirty = true;
      return;
    }
    _logTimer = Timer(const Duration(seconds: 1), () {
      _logTimer = null;
      if (_logDirty) {
        _logDirty = false;
        publishRunLog(_logRun!, _logSource!);
      }
    });
    unawaited(_flushLog());
  }

  Future<void> _flushLog() async {
    final log = _logSource;
    final runId = _logRun;
    if (log == null || runId == null || _logFlushing) {
      _logDirty = _logDirty || _logFlushing;
      return;
    }
    _logFlushing = true;
    try {
      if (log.seq <= _logSeq) return;
      final (from, lines) = log.since(_logSeq);
      final firstChunk = from ~/ logChunk;
      final lastChunk = (log.seq - 1) ~/ logChunk;
      final coll = ref.collection('runs').doc(runId).collection('log');
      final b = db.batch();
      for (var c = firstChunk; c <= lastChunk; c++) {
        final start = c * logChunk;
        final end = (start + logChunk).clamp(0, log.seq);
        // What the ring still holds of this chunk.
        final (cf, cl) = log.since(start);
        final have = cl.take(end - cf).toList();
        if (have.isEmpty) continue;
        b.set(coll.doc('c${c.toString().padLeft(6, '0')}'), {'from': cf, 'lines': have, 'at': FieldValue.serverTimestamp()});
      }
      for (var c = firstChunk - 1; c >= 0 && c >= lastChunk - logChunks - 2; c--) {
        if (c <= lastChunk - logChunks) b.delete(coll.doc('c${c.toString().padLeft(6, '0')}'));
      }
      _logSeq = log.seq;
      await b.commit();
      assert(lines.isNotEmpty || true);
    } on Object {
      // The next flush tries again from the same sequence.
    } finally {
      _logFlushing = false;
      if (_logDirty && _logTimer == null) {
        _logDirty = false;
        publishRunLog(runId, log);
      }
    }
  }

  /// The host's answer to a `read_file`, under the command's id.
  Future<void> publishFile(String commandId, Map<String, Object?> file) =>
      ref.collection('files').doc(commandId).set({...file, 'createdAt': FieldValue.serverTimestamp()});

  /// An ask the bridge raised, for the phone to answer.
  Future<void> publishAsk(Ask ask) async {
    await ref.collection('asks').doc(ask.requestId).set({...ask.toMap(), 'answeredAt': null, 'createdAt': FieldValue.serverTimestamp()});
    _asks++;
    if (_asks % 20 == 0) await _pruneAsks();
  }

  /// Whoever answered, the phone's card drops on this.
  Future<void> resolveAsk(String requestId, {required String summary, required String by}) =>
      ref.collection('asks').doc(requestId).set({'answeredAt': FieldValue.serverTimestamp(), 'answer': summary, 'by': by}, SetOptions(merge: true));

  /// Every ask still open in the relay, closed as withdrawn — a host that
  /// just came up, or a fresh conversation, has nothing pending, so an ask
  /// a dead process left behind must not haunt the phone. Returns their
  /// ids, so the host can take them off the lock screens too.
  Future<List<String>> withdrawOpenAsks({String reason = 'Withdrawn — the session stopped'}) async {
    final q = await ref.collection('asks').where('answeredAt', isNull: true).get();
    if (q.docs.isEmpty) return const [];
    final b = db.batch();
    for (final d in q.docs) {
      b.set(d.reference, {'answeredAt': FieldValue.serverTimestamp(), 'answer': reason, 'by': 'host'}, SetOptions(merge: true));
    }
    await b.commit();
    return [for (final d in q.docs) d.id];
  }

  int _asks = 0;

  /// How many rows of the transcript the mirror keeps.
  static const chatKeep = 300;

  final Map<String, String> _chat = {};
  Transcript? _chatSource;
  Timer? _chatTimer;
  bool _chatDirty = false;
  bool _chatSeeded = false;
  bool _chatFlushing = false;

  /// Mirrors the transcript — coalesced: the first change of a window
  /// flushes at once, the rest of the window's changes go together when it
  /// ends, so a streaming reply costs one write a second, not one a word.
  void publishTranscript(Transcript t) {
    _chatSource = t;
    if (_chatTimer != null) {
      _chatDirty = true;
      return;
    }
    _chatTimer = Timer(const Duration(milliseconds: 700), () {
      _chatTimer = null;
      if (_chatDirty) {
        _chatDirty = false;
        publishTranscript(_chatSource!);
      }
    });
    unawaited(_flushChat());
  }

  Future<void> _flushChat() async {
    final t = _chatSource;
    if (t == null || _chatFlushing) {
      _chatDirty = _chatDirty || _chatFlushing;
      return;
    }
    _chatFlushing = true;
    try {
      if (!_chatSeeded) {
        _chatSeeded = true;
        final q = await ref.collection('chat').get();
        for (final d in q.docs) {
          _chat[d.id] = stableJson(d.data());
        }
      }
      final msgs = t.messages.length > chatKeep ? t.messages.sublist(t.messages.length - chatKeep) : t.messages;
      final wanted = <String, Map<String, Object?>>{for (final m in msgs) m.id: {...m.toMap(), if (t.sessionId != null) 'sessionId': t.sessionId}};
      final ops = <void Function(WriteBatch)>[];
      for (final e in wanted.entries) {
        final json = stableJson(e.value);
        if (_chat[e.key] == json) continue;
        ops.add((b) => b.set(ref.collection('chat').doc(e.key), e.value));
        _chat[e.key] = json;
      }
      for (final id in _chat.keys.toList()) {
        if (wanted.containsKey(id)) continue;
        ops.add((b) => b.delete(ref.collection('chat').doc(id)));
        _chat.remove(id);
      }
      for (var i = 0; i < ops.length; i += 400) {
        final b = db.batch();
        for (final op in ops.sublist(i, (i + 400).clamp(0, ops.length))) {
          op(b);
        }
        await b.commit();
      }
    } finally {
      _chatFlushing = false;
    }
  }

  final Set<String> _threadSeen = {};

  /// Mirrors every finalized scoped row into its thread — append-only, so
  /// a thread survives session restarts and the chat's 300-row window.
  Future<void> publishThreads(Transcript t) async {
    final sid = t.sessionId;
    if (sid == null) return;
    for (final m in t.messages) {
      final key = threadKey(m.about);
      if (key == null || m.streaming) continue;
      // A tool row waits for its result so the thread holds the outcome.
      if (m.role == DeckRole.tool && m.toolResult == null) continue;
      final docId = '$sid-${m.id}';
      if (!_threadSeen.add('$key/$docId')) continue;
      final tref = ref.collection('threads').doc(key);
      final mref = tref.collection('messages').doc(docId);
      final exists = (await mref.get()).exists;
      await mref.set({...m.toMap(), 'sessionId': sid});
      await tref.set({
        'about': m.about,
        if (!exists) 'count': FieldValue.increment(1),
        'last': {'role': m.role.name, 'text': _clipText(m.role == DeckRole.tool ? m.toolSummary : m.text, 240), 'at': m.at.toUtc().toIso8601String()},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// The UPDATED row: Claude changed the thing the thread is about.
  Future<void> publishThreadUpdate(Map<String, Object?> about, List<String> fields) async {
    final key = threadKey(about);
    if (key == null || fields.isEmpty) return;
    final tref = ref.collection('threads').doc(key);
    final at = DateTime.now().toUtc();
    final id = 'upd-${at.microsecondsSinceEpoch}';
    await tref.collection('messages').doc(id).set({'id': id, 'role': 'note', 'text': 'UPDATED · ${fields.join(', ')}', 'at': at.toIso8601String(), 'about': about, 'isError': false, 'streaming': false});
    await tref.set({
      'about': about,
      'count': FieldValue.increment(1),
      'updated': {'fields': fields, 'at': at.toIso8601String()},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _clipText(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1)}…';

  Future<void> _pruneAsks() async {
    final q = await ref.collection('asks').orderBy('at', descending: true).limit(200).get();
    if (q.docs.length < 100) return;
    final b = db.batch();
    for (final d in q.docs.skip(50)) {
      b.delete(d.reference);
    }
    await b.commit();
  }

  /// The "now" line — coalesced, because a `/step` fires PostToolUse
  /// hundreds of times and only the latest matters on a phone.
  void publishNow(HookEvent e) {
    _pendingNow = e.toJson();
    _nowTimer ??= Timer(const Duration(seconds: 1), () {
      _nowTimer = null;
      final now = _pendingNow;
      _pendingNow = null;
      if (now != null) ref.set({'now': now}, SetOptions(merge: true));
    });
  }

  /// Milestones keep a short history: prompts, turn ends, notifications.
  Future<void> publishMilestone(HookEvent e) async {
    await ref.collection('events').add({...e.toJson(), 'createdAt': FieldValue.serverTimestamp()});
    _prunes++;
    if (_prunes % 25 == 0) await _pruneEvents();
  }

  int _prunes = 0;

  Future<void> _pruneEvents() async {
    final q = await ref.collection('events').orderBy('at', descending: true).limit(300).get();
    if (q.docs.length < 150) return;
    final b = db.batch();
    for (final d in q.docs.skip(100)) {
      b.delete(d.reference);
    }
    await b.commit();
  }

  void dispose() {
    _nowTimer?.cancel();
    _chatTimer?.cancel();
  }
}

/// The phone's Deck: the mirrored transcript and the session document in,
/// commands out. A message sent from here shows at once as an echo and is
/// replaced by the host's copy when the mirror catches up.
class RemoteDeck extends ChangeNotifier {
  RemoteDeck(this.db, this.slug, {this.from = 'phone', this.blobs, DateTime Function()? now, this.tick = const Duration(seconds: 10)}) : _now = now ?? DateTime.now;

  final FirebaseFirestore db;
  final String slug;
  final String from;
  final DateTime Function() _now;

  /// How often the "ago" in the Mac's line is redrawn.
  final Duration tick;

  /// The Mac's `hosts/{id}` row, once the project doc named the machine.
  Map<String, Object?>? hostDoc;
  String? _hostId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _hostSub;
  Timer? _ticker;

  /// Commands this device wrote that the host has not stamped yet, by echo id.
  final Map<String, DocumentReference<Map<String, dynamic>>> _pending = {};

  /// What the phone says about the Mac right now.
  HostPresenceView get presence => HostPresenceView.from(hostDoc, now: _now());

  /// The echoes whose command sits unread because the Mac is gone — shown
  /// as queued, with a way to withdraw. Empty while the Mac is up.
  Set<String> get queued => presence.gone ? {for (final e in echoes) if (_pending.containsKey(e.id)) e.id} : const {};

  /// The bucket the files go into — a test hands one in; the phone opens
  /// Firebase Storage on the first file.
  BlobStore? blobs;

  BlobStore get _store => blobs ??= FirebaseBlobStore();

  /// How far each file of an echo has gone up: `'<echo id>/<name>'` → 0…1.
  /// Gone once the command is written.
  final Map<String, double> uploadProgress = {};
  List<DeckMessage> messages = const [];
  Map<String, Object?> session = const {};
  final List<DeckMessage> echoes = [];
  String? error;
  final _subs = <StreamSubscription<Object?>>[];
  int _echoSeq = 0;

  DocumentReference<Map<String, dynamic>> get ref => db.collection('projects').doc(slug);

  /// What the last [publish] changed, per document — `items/presence` →
  /// `[body, needs]`. The host turns a change to the thing a thread is
  /// about into the thread's UPDATED row.
  final Map<String, List<String>> lastChanges = {};

  BridgeState get state {
    final s = (session['state'] ?? 'idle').toString();
    return BridgeState.values.firstWhere((v) => v.name == s, orElse: () => BridgeState.idle);
  }

  bool get running => session['mode'] == 'bridge';
  bool get canResume => session['canResume'] == true;
  bool get turnOpen => state == BridgeState.busy || state == BridgeState.waiting;
  String? get sessionId => session['sessionId']?.toString();
  String? get model => session['model']?.toString();
  String? get cliVersion => session['cliVersion']?.toString();
  String? get machine => session['machine']?.toString();
  /// The mode dial; [permissionMode] is what the CLI last reported, and
  /// [modePending] that the dial moved mid-turn and waits for its end.
  String get modeChoice => knownMode(session['modeChoice']);
  bool get modePending => session['modePending'] == true;
  bool get modelPending => session['modelPending'] == true;

  /// A dial moved mid-turn; the switch waits for the turn to end.
  bool get switchPending => modePending || modelPending;
  String? get permissionMode => session['permissionMode']?.toString();
  bool get chrome => session['chrome'] == true;
  String get modelChoice => (session['modelChoice'] ?? 'default').toString();
  String get effort => (session['effort'] ?? 'default').toString();

  /// An option changed mid-turn; the host restarts when the turn ends.
  bool get restartPending => session['restartPending'] == true;
  String? get chromeStatus => session['chromeStatus']?.toString();

  /// The transcript with this device's unconfirmed sends at the end.
  List<DeckMessage> get view => [...messages, ...echoes];

  void start() {
    _subs.add(ref.snapshots().listen((d) {
      final m = d.data()?['session'];
      session = m is Map ? {for (final e in m.entries) e.key.toString(): e.value, 'machine': d.data()?['machine']} : const {};
      error = session['error']?.toString();
      _watchHost((d.data()?['machine'] ?? '').toString());
      notifyListeners();
    }, onError: _onError));
    _ticker ??= Timer.periodic(tick, (_) => notifyListeners());
    _subs.add(ref.collection('chat').snapshots().listen((q) {
      messages = (q.docs.map((d) => DeckMessage.fromMap({for (final e in d.data().entries) e.key: e.value as Object?})).toList()..sort((a, b) => a.id.compareTo(b.id)));
      // The host's copy of a message we sent replaces the echo.
      final sent = messages.where((m) => m.role == DeckRole.user).map((m) => m.text).toSet();
      echoes.removeWhere((e) => sent.contains(e.text));
      notifyListeners();
    }, onError: _onError));
  }

  void _onError(Object e) {
    error = e.toString();
    notifyListeners();
  }

  /// Follows the Mac's heartbeat row once the project says which Mac.
  void _watchHost(String machine) {
    if (machine.isEmpty) return;
    final id = hostIdFor(machine);
    if (id == _hostId) return;
    _hostId = id;
    _hostSub?.cancel();
    _hostSub = db.collection('hosts').doc(id).snapshots().listen((d) {
      final m = d.data();
      hostDoc = m == null ? null : {for (final e in m.entries) e.key: e.value as Object?};
      notifyListeners();
    }, onError: (Object _) {});
  }

  /// Ends the running turn and keeps the session — a command the host
  /// turns into the `interrupt` control request.
  Future<void> interrupt() => CommandSender(db, slug).send({'type': 'interrupt'}, from: from);

  /// The instruments, as the host publishes them: the context in use
  /// against the model's window, the pool with both windows, and whether
  /// `/compact` is running.
  int get contextUsed => (_context['used'] as num?)?.toInt() ?? 0;
  int get contextWindow => (_context['window'] as num?)?.toInt() ?? 0;
  Map<String, Object?> get _context => session['context'] is Map ? {for (final e in (session['context'] as Map).entries) e.key.toString(): e.value as Object?} : const {};
  RateLimitEvent? get pool => session['pool'] is Map ? RateLimitEvent.fromMap({for (final e in (session['pool'] as Map).entries) e.key.toString(): e.value as Object?}) : null;
  bool get compacting => session['compacting'] == true;

  /// `/compact`, sent by the host as a message on the session.
  Future<void> compact() => CommandSender(db, slug).send({'type': 'compact'}, from: from);

  /// The autopilot as the host publishes it — `session.autopilot`.
  AutopilotState get autopilot => session['autopilot'] is Map ? AutopilotState.fromMap({for (final e in (session['autopilot'] as Map).entries) e.key.toString(): e.value as Object?}) : const AutopilotState();

  /// The toggle: on with a budget and night shift, or off.
  Future<void> setAutopilot({required bool on, int? budget, bool? nightShift}) =>
      CommandSender(db, slug).send({'type': 'autopilot', 'on': on, 'budget': ?budget, 'nightShift': ?nightShift}, from: from);

  /// The run bay as the host publishes it — `session.run`.
  RunState get run => session['run'] is Map ? RunState.fromMap({for (final e in (session['run'] as Map).entries) e.key.toString(): e.value as Object?}) : const RunState();

  /// `{type: run, action: start|reload|restart|stop|devices|reload_on_edit}`
  /// — waited on for the host's one line.
  Future<String> runCommand(String action, {String? device, bool? on}) async {
    final ref = await CommandSender(db, slug).send({'type': 'run', 'action': action, 'device': ?device, 'on': ?on}, from: from);
    final done = await ref.snapshots().firstWhere((d) => d.data()?['doneAt'] != null).timeout(const Duration(seconds: 150), onTimeout: () => throw TimeoutException('The Mac did not answer in 150 s.'));
    return (done.data()?['result'] ?? '').toString();
  }

  /// The run's log, whole, as its documents arrive — the last two
  /// thousand lines at most.
  Stream<List<String>> runLog(String runId) => db.collection('projects').doc(slug).collection('runs').doc(runId).collection('log').orderBy(FieldPath.documentId).snapshots().map((q) => [
        for (final d in q.docs)
          for (final l in (d.data()['lines'] as List? ?? const [])) l.toString(),
      ]);

  /// The Git card's numbers, as the host last read them.
  GitStatus? get git => session['git'] is Map ? GitStatus.fromMap({for (final e in (session['git'] as Map).entries) e.key.toString(): e.value as Object?}) : null;

  /// A `host` command, waited on: the one line the host stamped as its
  /// result. "queued" while the Mac is unreachable — it runs when the Mac
  /// is back, and this waits up to [wait] for that.
  Future<String> hostCommand(Map<String, Object?> command, {Duration wait = const Duration(seconds: 60)}) async {
    final ref = await CommandSender(db, slug).send({'type': 'host', ...command}, from: from);
    final done = await ref.snapshots().firstWhere((d) => d.data()?['doneAt'] != null).timeout(wait, onTimeout: () => throw TimeoutException('The Mac did not answer in ${wait.inSeconds} s.'));
    return (done.data()?['result'] ?? '').toString();
  }

  /// git from the phone: commit, push, revert — the host runs it.
  Future<String> gitOp(String op, {String? message, String? path}) => hostCommand({'action': 'git', 'op': op, 'message': ?message, 'path': ?path});

  /// A file on the Mac, read by the host: the `files/{commandId}` document,
  /// and the whole file from Storage when the document holds only the
  /// start. The document goes once read.
  Future<FileRead> readFile(String path) async {
    final ref = await CommandSender(db, slug).send({'type': 'host', 'action': 'read_file', 'path': path}, from: from);
    final done = await ref.snapshots().firstWhere((d) => d.data()?['doneAt'] != null).timeout(const Duration(seconds: 60), onTimeout: () => throw TimeoutException('The Mac did not answer in 60 s.'));
    final result = (done.data()?['result'] ?? '').toString();
    final fileRef = db.collection('projects').doc(slug).collection('files').doc(ref.id);
    final fd = await fileRef.get();
    final m = fd.data();
    if (m == null) return FileRead.refused(path, result.isEmpty ? 'no answer from the Mac' : result);
    var r = FileRead.fromMap({for (final e in m.entries) e.key: e.value as Object?});
    if (r.truncated && r.blob != null) {
      final blob = r.blob!;
      try {
        final bytes = await _store.get(blob);
        r = FileRead.ok(path: r.path, text: utf8.decode(bytes, allowMalformed: true), lines: r.lines, bytes: r.bytes);
        unawaited(_store.delete(blob).catchError((Object _) {}));
      } on Object {
        // The first part, then, and it says so.
      }
    }
    unawaited(fileRef.delete().catchError((Object _) {}));
    return r;
  }

  /// Takes back a send: one the Mac never saw (the command is deleted
  /// unread), or one the host holds queued behind a running turn (a
  /// `withdraw` command names the row). Nothing happens when it ran.
  Future<void> withdraw(String id) async {
    final ref = _pending[id];
    if (ref == null) {
      if (messages.any((m) => m.id == id && m.queued)) await CommandSender(db, slug).send({'type': 'withdraw', 'messageId': id}, from: from);
      return;
    }
    final echoId = id;
    try {
      final d = await ref.get();
      if (d.exists && d.data()?['doneAt'] != null) return;
      await ref.delete();
    } on Object catch (e) {
      error = 'Could not withdraw: $e';
      notifyListeners();
      return;
    }
    _pending.remove(echoId);
    echoes.removeWhere((m) => m.id == echoId);
    notifyListeners();
  }

  /// Sends a message; [files] go up first, into the bucket, and the command
  /// names them — the host fetches them and hands them to the session.
  Future<void> send(String text, {Map<String, Object?>? about, List<PendingAttachment> files = const []}) async {
    final t = text.trim();
    if (t.isEmpty && files.isEmpty) return;
    final echo = DeckMessage(
      id: 'echo-${(_echoSeq++).toString().padLeft(5, '0')}',
      role: DeckRole.user,
      text: t,
      at: DateTime.now(),
      streaming: true,
      about: about,
      attachments: [for (final f in files) f.describe()],
    );
    echoes.add(echo);
    notifyListeners();
    try {
      final ups = <Map<String, Object?>>[];
      for (final f in files) {
        final key = '${echo.id}/${f.name}';
        ups.add(await UploadSender(_store, slug).send(f, from: from, onProgress: (p) {
          uploadProgress[key] = p;
          notifyListeners();
        }));
      }
      final ref = await CommandSender(db, slug).send({'type': 'send', 'text': t, 'about': ?about, if (ups.isNotEmpty) 'uploads': ups}, from: from);
      _pending[echo.id] = ref;
      _watchResult(ref, echo);
    } on Object catch (e) {
      // The echo goes; the words and the files stay in the composer for
      // another try — the caller hears why.
      echoes.remove(echo);
      error = 'Could not send: $e';
      throw SendFailed(error!);
    } finally {
      uploadProgress.removeWhere((k, _) => k.startsWith('${echo.id}/'));
      notifyListeners();
    }
  }

  /// The host stamps what came of a command. Anything but "sent" — the
  /// session stopped meanwhile, a file that did not arrive — takes the
  /// echo back and says why, instead of leaving a dim bubble forever.
  void _watchResult(DocumentReference<Map<String, dynamic>> ref, DeckMessage echo) {
    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    sub = ref.snapshots().listen((d) {
      final m = d.data();
      if (m == null || m['doneAt'] == null) return;
      sub.cancel();
      _pending.remove(echo.id);
      final result = (m['result'] ?? '').toString();
      if (result.startsWith('sent') || result.startsWith('queued')) return;
      echoes.remove(echo);
      error = 'Not sent: $result';
      notifyListeners();
    }, onError: (Object _) => sub.cancel());
    _subs.add(sub);
  }

  /// Start is a command like any other — except that a Mac that said it
  /// stopped cannot run it, and the phone says so instead of queueing.
  Future<void> startSession({bool resume = false}) async {
    final p = presence;
    if (p.state == HostState.stopped) {
      error = 'The Mac app is stopped — open K.A.T.Y.A on the Mac first.';
      notifyListeners();
      return;
    }
    await CommandSender(db, slug).send({'type': 'start', 'resume': resume}, from: from);
    if (p.state == HostState.unreachable) {
      error = 'Start is queued — the Mac is unreachable; it starts when the Mac is back.';
      notifyListeners();
    }
  }

  /// Stop, like Start, is a command — on a Mac that said it stopped there
  /// is nothing to stop; on one that is unreachable it waits its turn.
  Future<void> stopSession() async {
    final p = presence;
    if (p.state == HostState.stopped) {
      error = 'The Mac app is stopped — nothing is running there.';
      notifyListeners();
      return;
    }
    await CommandSender(db, slug).send({'type': 'stop'}, from: from);
    if (p.state == HostState.unreachable) {
      error = 'Stop is queued — the Mac is unreachable; it stops when the Mac is back.';
      notifyListeners();
    }
  }

  /// The options the host's next Start runs with; `default` for a dial
  /// hands the choice back to the CLI.
  Future<void> setOptions({String? mode, bool? chrome, String? model, String? effort}) =>
      CommandSender(db, slug).send({'type': 'options', 'mode': ?mode, 'chrome': ?chrome, 'model': ?model, 'effort': ?effort}, from: from);

  /// Asks the Mac to push to every registered phone, and waits for what
  /// came of it — or says so when the Mac does not answer.
  Future<String?> testPush() async {
    final ref = await CommandSender(db, slug).send({'type': 'push-test'}, from: from);
    final done = Completer<String?>();
    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    void finish(String r) {
      if (!done.isCompleted) done.complete(r);
      sub.cancel();
    }

    sub = ref.snapshots().listen((d) {
      final m = d.data();
      if (m == null || m['doneAt'] == null) return;
      finish((m['result'] ?? '').toString());
    }, onError: (Object e) => finish('Could not send: $e'));
    _subs.add(sub);
    final giveUp = Timer(const Duration(seconds: 20), () => finish('The Mac did not answer — is the app open there?'));
    final r = await done.future;
    giveUp.cancel();
    return r;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _hostSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}

/// One thread's face on a card: how many rows, the last reply, and what
/// Claude last changed on the thing itself.
class ThreadSummary {
  ThreadSummary({required this.key, required this.about, required this.count, this.lastRole, this.lastText, this.lastAt, this.updatedFields = const [], this.updatedAt});

  factory ThreadSummary.fromDoc(String id, Map<String, Object?> m) {
    Map<String, Object?> map(Object? v) => v is Map ? {for (final e in v.entries) e.key.toString(): e.value} : {};
    final last = map(m['last']);
    final updated = map(m['updated']);
    return ThreadSummary(
      key: id,
      about: map(m['about']),
      count: (m['count'] as num?)?.toInt() ?? 0,
      lastRole: last['role']?.toString(),
      lastText: last['text']?.toString(),
      lastAt: DateTime.tryParse((last['at'] ?? '').toString()),
      updatedFields: [for (final f in (updated['fields'] as List? ?? const [])) f.toString()],
      updatedAt: DateTime.tryParse((updated['at'] ?? '').toString()),
    );
  }

  final String key;
  final Map<String, Object?> about;
  final int count;
  final String? lastRole;
  final String? lastText;
  final DateTime? lastAt;
  final List<String> updatedFields;
  final DateTime? updatedAt;
}

/// Every thread of one project, live — what an item card or step sheet
/// shows without opening the thread.
class ThreadStore extends ChangeNotifier {
  ThreadStore(this.db, this.slug);
  final FirebaseFirestore db;
  final String slug;
  final Map<String, ThreadSummary> summaries = {};
  String? error;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  void start() {
    _sub = db.collection('projects').doc(slug).collection('threads').snapshots().listen((q) {
      summaries
        ..clear()
        ..addEntries(q.docs.map((d) => MapEntry(d.id, ThreadSummary.fromDoc(d.id, {for (final e in d.data().entries) e.key: e.value as Object?}))));
      notifyListeners();
    }, onError: (Object e) {
      error = e.toString();
      notifyListeners();
    });
  }

  ThreadSummary? forItem(String id) => summaries['item:$id'];
  ThreadSummary? forStep(String id) => summaries['step:$id'];

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// The host's side of Send to Claude: every unapplied batch, applied in the
/// order it was sent, and stamped so it is never applied twice.
class InboxListener {
  InboxListener(this.db, this.slug, {required this.apply});

  final FirebaseFirestore db;
  final String slug;
  final Future<InboxResult> Function(Map<String, Object?> batch) apply;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _busy = false;
  final _seen = <String>{};

  void start() {
    _sub = db.collection('projects').doc(slug).collection('inbox').where('appliedAt', isNull: true).snapshots().listen(_onBatchDocs);
  }

  Future<void> _onBatchDocs(QuerySnapshot<Map<String, dynamic>> q) async {
    if (_busy) return;
    _busy = true;
    try {
      final docs = q.docs.where((d) => !_seen.contains(d.id)).toList()..sort((a, b) => (a.data()['sentAt'] ?? '').toString().compareTo((b.data()['sentAt'] ?? '').toString()));
      for (final d in docs) {
        _seen.add(d.id);
        final batch = {for (final e in d.data().entries) e.key: e.value as Object?};
        String summary;
        List<String> lines;
        try {
          final r = await apply(batch);
          summary = r.summary;
          lines = [for (final l in r.lines) l.toString(), for (final id in r.flippable) '$id has nothing left in the way'];
        } on Object catch (e) {
          summary = 'failed: $e';
          lines = const [];
        }
        await d.reference.set({'appliedAt': FieldValue.serverTimestamp(), 'applied': summary, 'lines': lines}, SetOptions(merge: true));
      }
    } finally {
      _busy = false;
    }
  }

  void dispose() => _sub?.cancel();
}

/// The host's side of `commands`: every command the phone sent and nobody
/// has run, in the order sent, each stamped with what came of it.
class CommandListener {
  CommandListener(this.db, this.slug, {required this.apply});

  final FirebaseFirestore db;
  final String slug;

  /// Runs one command; returns a one-line result for the stamp.
  final Future<String> Function(Map<String, Object?> command) apply;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _busy = false;
  final _seen = <String>{};

  void start() {
    _sub = db.collection('projects').doc(slug).collection('commands').where('doneAt', isNull: true).snapshots().listen(_onDocs);
  }

  Future<void> _onDocs(QuerySnapshot<Map<String, dynamic>> q) async {
    if (_busy) return;
    _busy = true;
    try {
      final docs = q.docs.where((d) => !_seen.contains(d.id)).toList()..sort((a, b) => (a.data()['sentAt'] ?? '').toString().compareTo((b.data()['sentAt'] ?? '').toString()));
      for (final d in docs) {
        _seen.add(d.id);
        String result;
        try {
          result = await apply({for (final e in d.data().entries) e.key: e.value as Object?, 'id': d.id});
        } on Object catch (e) {
          result = 'failed: $e';
        }
        await d.reference.set({'doneAt': FieldValue.serverTimestamp(), 'result': result}, SetOptions(merge: true));
      }
    } finally {
      _busy = false;
    }
  }

  void dispose() => _sub?.cancel();
}

/// The phone's side of `commands`.
class CommandSender {
  CommandSender(this.db, this.slug);
  final FirebaseFirestore db;
  final String slug;

  /// Returns the command's document — the host stamps `doneAt` and
  /// `result` on it.
  Future<DocumentReference<Map<String, dynamic>>> send(Map<String, Object?> command, {required String from}) => db.collection('projects').doc(slug).collection('commands').add({
        ...command,
        'from': from,
        'sentAt': DateTime.now().toUtc().toIso8601String(),
        'doneAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> answer(Ask ask, AskAnswer a, {bool remember = false, required String from}) =>
      send({'type': 'answer', 'requestId': ask.requestId, ...a.toMap(), 'remember': remember}, from: from);
}

/// A send that never reached the relay — a file that would not go up, a
/// command that would not write. The composer keeps what it had.
class SendFailed implements Exception {
  const SendFailed(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The phone's side of an upload: the file into the bucket under
/// `projects/{slug}/uploads/{id}/{name}`; what comes back is what the
/// `send` command names — the host fetches, saves and deletes it.
class UploadSender {
  UploadSender(this.blobs, this.slug, {String Function()? newId}) : _newId = newId ?? newBlobId;
  final BlobStore blobs;
  final String slug;
  final String Function() _newId;

  Future<Map<String, Object?>> send(PendingAttachment a, {required String from, void Function(double fraction)? onProgress}) async {
    final id = _newId();
    final path = uploadBlobPath(slug, id, a.name);
    await blobs.put(path, a.bytes, contentType: a.mime, onProgress: onProgress);
    return {'id': id, 'path': path, 'name': a.name, 'mime': a.mime, 'size': a.size, 'from': from, 'sentAt': DateTime.now().toUtc().toIso8601String()};
  }
}

/// The host's side: the file back from the bucket, then gone.
class UploadReader {
  UploadReader(this.blobs, this.slug);
  final BlobStore blobs;
  final String slug;

  String _path(Map<String, Object?> upload) {
    final path = (upload['path'] ?? '').toString();
    if (!path.startsWith('${uploadsPrefix(slug)}/')) throw StateError('upload path "$path" is not under this project');
    return path;
  }

  /// Throws [StateError] when the object is gone or not the size the
  /// phone said.
  Future<PendingAttachment> fetch(Map<String, Object?> upload) async {
    final path = _path(upload);
    final Uint8List bytes;
    try {
      bytes = await blobs.get(path);
    } on StateError {
      throw StateError('upload ${upload['id'] ?? path} is gone');
    }
    final size = (upload['size'] as num?)?.toInt();
    if (size != null && bytes.length != size) throw StateError('upload ${upload['id'] ?? path} came to ${bytes.length} bytes, not $size');
    return PendingAttachment(name: (upload['name'] ?? 'file').toString(), mime: (upload['mime'] ?? 'application/octet-stream').toString(), bytes: bytes);
  }

  Future<void> delete(Map<String, Object?> upload) => blobs.delete(_path(upload));

  /// Drops uploads nobody collected — a phone that died mid-send. Returns
  /// how many went.
  Future<int> prune({Duration olderThan = const Duration(days: 1), DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(olderThan);
    var n = 0;
    for (final e in await blobs.list(uploadsPrefix(slug))) {
      final at = e.updatedAt;
      if (at != null && at.toUtc().isAfter(cutoff)) continue;
      await blobs.delete(e.path);
      n++;
    }
    return n;
  }
}

/// The phone's side.
class InboxSender {
  InboxSender(this.db, this.slug);
  final FirebaseFirestore db;
  final String slug;

  Future<void> send(Map<String, Object?> batch, {required String from}) =>
      db.collection('projects').doc(slug).collection('inbox').add({...batch, 'from': from, 'appliedAt': null, 'createdAt': FieldValue.serverTimestamp()});
}

String slugFor(Manifest m) {
  final base = m.projectSlug ?? m.projectName;
  final s = base.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'project' : s;
}

/// The steps whose `status` the last [RelayPublisher.publish] changed to
/// done — what the phone hears about, once, on the `steps` channel.
List<Step> flippedDone(Map<String, List<String>> lastChanges, Plan plan) => [
      for (final e in lastChanges.entries)
        if (e.key.startsWith('steps/') && e.value.contains('status'))
          if (plan.step(e.key.substring('steps/'.length)) case final s? when s.status == StepStatus.done) s,
    ];
