import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';

import 'attachments.dart';
import 'host/bridge_session.dart' show BridgeState;

/// The relay: Firestore on `flutterappbundle`, one user, owner-only rules.
///
/// ```
/// projects/{slug}                 manifest, dir, machine, session, now, counts
/// projects/{slug}/steps/{id}      Step.toMap()
/// projects/{slug}/items/{id}      Item.toMap()
/// projects/{slug}/inbox/{auto}    a batch from the phone; the host stamps appliedAt
/// projects/{slug}/events/{auto}   milestones from hooks (prompt, stop, notification)
/// projects/{slug}/asks/{requestId} an Ask the bridge raised; the host stamps answeredAt, answer, by
/// projects/{slug}/commands/{auto} phone → host: {type: answer|send|start|stop|options|push-test, …}; the host stamps doneAt, result
/// projects/{slug}/chat/{messageId} the transcript, one DeckMessage.toMap() per row, the last 300
/// projects/{slug}/threads/{about}   `item:<id>` or `step:<id>`: {about, count, last, updated}
/// projects/{slug}/threads/{about}/messages/{sessionId-messageId}  the scoped rows, kept forever
/// projects/{slug}/uploads/{id}      a file on its way from the phone: {name, mime, size, parts, complete, from, sentAt}
/// projects/{slug}/uploads/{id}/parts/{n}  base64 of [uploadChunk] bytes each; the host reassembles, saves, deletes
/// devices/{fcmToken}                a phone that takes pushes: {platform, name, uid, registeredAt, seenAt}; the host drops one FCM no longer knows
/// ```
///
/// The host is the only writer of `asks`, `chat` and `session`; the phone
/// only ever writes `inbox`, `commands`, `uploads` and its own `devices` row.
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

  /// An ask the bridge raised, for the phone to answer.
  Future<void> publishAsk(Ask ask) async {
    await ref.collection('asks').doc(ask.requestId).set({...ask.toMap(), 'answeredAt': null, 'createdAt': FieldValue.serverTimestamp()});
    _asks++;
    if (_asks % 20 == 0) await _pruneAsks();
  }

  /// Whoever answered, the phone's card drops on this.
  Future<void> resolveAsk(String requestId, {required String summary, required String by}) =>
      ref.collection('asks').doc(requestId).set({'answeredAt': FieldValue.serverTimestamp(), 'answer': summary, 'by': by}, SetOptions(merge: true));

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
  RemoteDeck(this.db, this.slug, {this.from = 'phone'});

  final FirebaseFirestore db;
  final String slug;
  final String from;
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
  bool get skipPermissions => session['skipPermissions'] == true;
  bool get chrome => session['chrome'] == true;
  String? get chromeStatus => session['chromeStatus']?.toString();

  /// The transcript with this device's unconfirmed sends at the end.
  List<DeckMessage> get view => [...messages, ...echoes];

  void start() {
    _subs.add(ref.snapshots().listen((d) {
      final m = d.data()?['session'];
      session = m is Map ? {for (final e in m.entries) e.key.toString(): e.value, 'machine': d.data()?['machine']} : const {};
      error = session['error']?.toString();
      notifyListeners();
    }, onError: _onError));
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

  /// Sends a message; [files] go up first, in parts, and the command names
  /// them — the host reassembles and hands them to the session.
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
      final ids = [for (final f in files) await UploadSender(db, slug).send(f, from: from)];
      final ref = await CommandSender(db, slug).send({'type': 'send', 'text': t, 'about': ?about, if (ids.isNotEmpty) 'uploads': ids}, from: from);
      _watchResult(ref, echo);
    } on Object catch (e) {
      echoes.remove(echo);
      error = 'Could not send: $e';
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
      final result = (m['result'] ?? '').toString();
      if (result.startsWith('sent')) return;
      echoes.remove(echo);
      error = 'Not sent: $result';
      notifyListeners();
    }, onError: (Object _) => sub.cancel());
    _subs.add(sub);
  }

  Future<void> startSession({bool resume = false}) => CommandSender(db, slug).send({'type': 'start', 'resume': resume}, from: from);

  Future<void> stopSession() => CommandSender(db, slug).send({'type': 'stop'}, from: from);

  /// The options the host's next Start runs with.
  Future<void> setOptions({bool? skipPermissions, bool? chrome}) =>
      CommandSender(db, slug).send({'type': 'options', 'skipPermissions': ?skipPermissions, 'chrome': ?chrome}, from: from);

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
          result = await apply({for (final e in d.data().entries) e.key: e.value as Object?});
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

/// A Firestore document holds a megabyte; a file goes up in pieces this
/// big (base64 makes them a third larger, still well under).
const uploadChunk = 600 * 1024;

/// The phone's side of `uploads`: one file → a header and its parts, the
/// header stamped `complete` last, so the host never reads half a file.
class UploadSender {
  UploadSender(this.db, this.slug);
  final FirebaseFirestore db;
  final String slug;

  /// Returns the upload's id — what the `send` command names.
  Future<String> send(PendingAttachment a, {required String from}) async {
    final ref = db.collection('projects').doc(slug).collection('uploads').doc();
    final n = max(1, (a.size / uploadChunk).ceil());
    await ref.set({
      'name': a.name,
      'mime': a.mime,
      'size': a.size,
      'parts': n,
      'complete': false,
      'from': from,
      'sentAt': DateTime.now().toUtc().toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (var i = 0; i < n; i++) {
      final start = i * uploadChunk;
      final end = min(a.size, start + uploadChunk);
      await ref.collection('parts').doc(i.toString().padLeft(4, '0')).set({'i': i, 'data': base64Encode(a.bytes.sublist(start, end))});
    }
    await ref.set({'complete': true}, SetOptions(merge: true));
    return ref.id;
  }
}

/// The host's side of `uploads`: the file back in one piece, then gone.
class UploadReader {
  UploadReader(this.db, this.slug);
  final FirebaseFirestore db;
  final String slug;

  CollectionReference<Map<String, dynamic>> get _coll => db.collection('projects').doc(slug).collection('uploads');

  /// Throws [StateError] when the upload is missing or not complete.
  Future<PendingAttachment> fetch(String id) async {
    final ref = _coll.doc(id);
    final m = (await ref.get()).data();
    if (m == null) throw StateError('upload $id is gone');
    if (m['complete'] != true) throw StateError('upload $id is not complete');
    final n = (m['parts'] as num?)?.toInt() ?? 0;
    final size = (m['size'] as num?)?.toInt() ?? 0;
    final q = await ref.collection('parts').get();
    final parts = {for (final d in q.docs) (d.data()['i'] as num).toInt(): (d.data()['data'] ?? '').toString()};
    final bytes = Uint8List(size);
    var at = 0;
    for (var i = 0; i < n; i++) {
      final part = parts[i];
      if (part == null) throw StateError('upload $id is missing part $i of $n');
      final b = base64Decode(part);
      bytes.setRange(at, at + b.length, b);
      at += b.length;
    }
    if (at != size) throw StateError('upload $id came to $at bytes, not $size');
    return PendingAttachment(name: (m['name'] ?? 'file').toString(), mime: (m['mime'] ?? 'application/octet-stream').toString(), bytes: bytes);
  }

  Future<void> delete(String id) async {
    final ref = _coll.doc(id);
    final q = await ref.collection('parts').get();
    final b = db.batch();
    for (final d in q.docs) {
      b.delete(d.reference);
    }
    b.delete(ref);
    await b.commit();
  }

  /// Drops uploads nobody collected — a phone that died mid-send. Returns
  /// how many went.
  Future<int> prune({Duration olderThan = const Duration(days: 1), DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(olderThan).toIso8601String();
    final q = await _coll.get();
    var n = 0;
    for (final d in q.docs) {
      final sentAt = (d.data()['sentAt'] ?? '').toString();
      if (sentAt.isNotEmpty && sentAt.compareTo(cutoff) > 0) continue;
      await delete(d.id);
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
