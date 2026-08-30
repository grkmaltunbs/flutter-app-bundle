import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_kit/kit.dart';

/// The relay: Firestore on `flutterappbundle`, one user, owner-only rules.
///
/// ```
/// projects/{slug}                 manifest, dir, machine, session, now, counts
/// projects/{slug}/steps/{id}      Step.toMap()
/// projects/{slug}/items/{id}      Item.toMap()
/// projects/{slug}/inbox/{auto}    a batch from the phone; the host stamps appliedAt
/// projects/{slug}/events/{auto}   milestones from hooks (prompt, stop, notification)
/// projects/{slug}/asks/{requestId} an Ask the bridge raised; the host stamps answeredAt, answer, by
/// projects/{slug}/commands/{auto} phone → host: {type: answer, …}; the host stamps doneAt, result
/// ```
///
/// The host is the only writer of `asks` and `session`; the phone only ever
/// writes `inbox` and `commands`.
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
    final wanted = <String, Map<String, Object?>>{
      for (final s in plan.steps) 'steps/${s.id}': stepDoc(s),
      for (final i in plan.items) 'items/${i.id}': itemDoc(i),
    };
    final ops = <void Function(WriteBatch)>[];
    for (final e in wanted.entries) {
      final json = stableJson(e.value);
      if (_published[e.key] == json) continue;
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

  Future<void> send(Map<String, Object?> command, {required String from}) => db.collection('projects').doc(slug).collection('commands').add({
        ...command,
        'from': from,
        'sentAt': DateTime.now().toUtc().toIso8601String(),
        'doneAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> answer(Ask ask, AskAnswer a, {bool remember = false, required String from}) =>
      send({'type': 'answer', 'requestId': ask.requestId, ...a.toMap(), 'remember': remember}, from: from);
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
