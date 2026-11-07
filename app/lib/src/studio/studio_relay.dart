import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart' show sha1;
import 'package:path/path.dart' as p;

import 'studio_board.dart';
import 'studio_data.dart';
import 'studio_plans.dart';
import 'studio_source.dart';

// The Studio on the phone: the Mac publishes the raw files the Studio reads
// — the lanes' status and history, their step lists, the production plan,
// the reviewer's digest, decisions and issues, recent mail, the docs — and
// the phone runs the same parsers on them, so a lane or a milestone reads
// the same on both. Only what changed is written (a hash per file, kept on
// the main document).
//
//   studio/main               machine, publishedAt, mode, lastReview, digest,
//                             lanes {a: {status, history, engine, model,
//                             effort, inbox, paused, stopping, host}}, hashes
//   studio/main/files/{key}   {rel, text} — steps-<lane>, plan, mail,
//                             decisions, issues, doc:<rel>

/// Firestore's document limit is 1 MiB; a file is cut to fit under it.
const _maxBytes = 900 * 1024;

String _fit(String text, {bool keepEnd = false}) {
  final bytes = utf8.encode(text);
  if (bytes.length <= _maxBytes) return text;
  final cut = keepEnd ? bytes.sublist(bytes.length - _maxBytes) : bytes.sublist(0, _maxBytes);
  return utf8.decode(cut, allowMalformed: true);
}

String _hash(Object v) => sha1.convert(utf8.encode(v is String ? v : jsonEncode(v))).toString();

String fileKey(String rel) => 'doc:${rel.replaceAll('/', '|')}';

/// The game's documents the phone gets for DOCS (the plan travels as `plan`).
List<String> phoneDocs(StudioSource s) => [
      'production/timetable-2027.md',
      'CLAUDE.md',
      'AGENTS.md',
      'design/notes/ai-gone-rogue-direction-2026-09-15.md',
      ...s.gddFiles(),
    ];

/// Publishes the Mac's Studio for the phone after every read that changed
/// something.
class StudioPublisher {
  StudioPublisher({required this.db, required this.source, required this.machine});
  final FirebaseFirestore db;
  final StudioSource source;
  final String machine;

  DocumentReference<Map<String, dynamic>> get main => db.collection('studio').doc('main');
  Map<String, String>? _hashes;
  bool _busy = false;
  bool _again = false;

  /// What came of the last attempt, for a status line.
  String? error;

  void start() {
    source.addListener(_onRead);
    _onRead();
  }

  void stop() => source.removeListener(_onRead);

  void _onRead() {
    if (_busy) {
      _again = true;
      return;
    }
    publish();
  }

  String _read(String path) => File(path).existsSync() ? utf8.decode(File(path).readAsBytesSync(), allowMalformed: true) : '';
  String _auto(String rel) => _read(p.join(source.autopilotDir, rel));

  /// One pass: the main document every time something in it changed, and
  /// each file whose hash moved.
  Future<void> publish() async {
    _busy = true;
    try {
      _hashes ??= await _loadHashes();
      final s = source.snapshot;
      final dir = source.autopilotDir;
      final lanes = <String, Object?>{
        for (final l in s.lanes)
          l.id: {
            'status': _auto(p.join('lane-${l.id}', 'status')).trim(),
            'history': _tail(_auto(p.join('lane-${l.id}', 'history.log')), 120),
            'engine': l.engine,
            'model': l.model,
            'effort': l.effort,
            'inbox': l.inbox,
            'paused': l.paused,
            'stopping': l.stopping,
            'host': l.hostMachine,
          },
      };
      final digest = _lastSection(_auto(p.join('review', 'digest.md')));
      final files = <String, Map<String, Object?>>{
        for (final e in s.tracks.entries)
          if (e.value.source != null) 'steps-${e.key}': {'rel': e.value.source, 'text': _fit(_read(e.value.source!))},
        if (source.gameDir != null) 'plan': {'rel': 'production/production-plan.md', 'text': _fit(source.gameFile('production/production-plan.md'))},
        'mail': {'rel': 'mail/to-user', 'text': jsonEncode([for (final m in s.userMail.take(40)) {'file': m.file, 'body': m.body.length > 8000 ? '${m.body.substring(0, 8000)}\n…' : m.body}])},
        'decisions': {'rel': 'review/afk-decisions.md', 'text': _fit(_lastSections(_auto(p.join('review', 'afk-decisions.md')), 60), keepEnd: true)},
        if (source.boardText.isNotEmpty) 'board': {'rel': 'messaging-board/MESSAGING_BOARD.md', 'text': _fit(source.boardText)},
        'issues': {'rel': 'review/open-issues.md', 'text': _fit([for (final i in s.openIssues.reversed) '- ${i.text}'].join('\n'), keepEnd: true)},
        if (source.gameDir != null)
          for (final rel in phoneDocs(source))
            if (source.gameFile(rel).isNotEmpty) fileKey(rel): {'rel': rel, 'text': _fit(source.gameFile(rel))},
      };
      final batch = db.batch();
      var writes = 0;
      final hashes = Map<String, String>.from(_hashes!);
      for (final e in files.entries) {
        final h = _hash(e.value['text']!);
        if (hashes[e.key] == h) continue;
        hashes[e.key] = h;
        batch.set(main.collection('files').doc(e.key), {...e.value, 'hash': h});
        writes++;
      }
      final head = {'lanes': lanes, 'digest': digest, 'mode': s.mode, 'lastReview': _auto(p.join('review', 'last-review')).trim(), 'files': files.keys.toList()..sort()};
      final hh = _hash(head);
      if (hashes['main'] != hh || writes > 0) {
        hashes['main'] = hh;
        batch.set(main, {...head, 'machine': machine, 'publishedAt': FieldValue.serverTimestamp(), 'hashes': hashes, 'dir': dir}, SetOptions(merge: true));
        writes++;
      }
      if (writes > 0) await batch.commit();
      _hashes = hashes;
      error = null;
    } catch (e) {
      error = '$e';
    } finally {
      _busy = false;
      if (_again) {
        _again = false;
        unawaited(publish());
      }
    }
  }

  Future<Map<String, String>> _loadHashes() async {
    try {
      final d = await main.get();
      final h = d.data()?['hashes'];
      if (h is Map) return {for (final e in h.entries) '${e.key}': '${e.value}'};
    } catch (_) {}
    return {};
  }
}

String _tail(String text, int lines) {
  final l = text.split('\n');
  return l.length <= lines ? text : l.sublist(l.length - lines).join('\n');
}

/// The last `## ` section of a reviewer file, with its heading.
String _lastSection(String text) {
  final i = text.lastIndexOf('\n## ');
  return i < 0 ? text : text.substring(i + 1);
}

/// The last [n] `## ` sections.
String _lastSections(String text, int n) {
  final heads = RegExp(r'^## ', multiLine: true).allMatches(text).map((m) => m.start).toList();
  if (heads.length <= n) return text;
  return text.substring(heads[heads.length - n]);
}

/// The phone's side: the relay's copy, parsed by the same code the Mac runs.
class RemoteStudioData extends StudioData {
  RemoteStudioData(this.db);
  final FirebaseFirestore db;

  @override
  StudioSnapshot snapshot = StudioSnapshot.empty;
  @override
  String? error;

  Map<String, dynamic> _main = const {};
  final Map<String, Map<String, dynamic>> _files = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _mainSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _filesSub;

  /// The Mac that publishes, and when it last did.
  String? get machine => _main['machine'] as String?;

  void start() {
    final main = db.collection('studio').doc('main');
    _mainSub = main.snapshots().listen((d) {
      _main = d.data() ?? const {};
      _rebuild();
    }, onError: (Object e) {
      error = '$e';
      notifyListeners();
    });
    _filesSub = main.collection('files').snapshots().listen((q) {
      for (final c in q.docChanges) {
        if (c.type == DocumentChangeType.removed) {
          _files.remove(c.doc.id);
        } else {
          _files[c.doc.id] = c.doc.data() ?? const {};
        }
      }
      _rebuild();
    }, onError: (Object e) {
      error = '$e';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _mainSub?.cancel();
    _filesSub?.cancel();
    super.dispose();
  }

  String _text(String key) => (_files[key]?['text'] as String?) ?? '';

  void _rebuild() {
    final laneMap = (_main['lanes'] as Map?)?.cast<String, dynamic>() ?? const {};
    final lanes = <Lane>[
      for (final id in laneMap.keys.toList()..sort())
        () {
          final l = (laneMap[id] as Map).cast<String, dynamic>();
          return Lane(
            id: id,
            status: LaneStatus.parse((l['status'] as String?) ?? ''),
            history: parseHistory((l['history'] as String?) ?? ''),
            engine: l['engine'] as String?,
            model: l['model'] as String?,
            effort: l['effort'] as String?,
            inbox: (l['inbox'] as num?)?.toInt() ?? 0,
            paused: l['paused'] == true,
            stopping: l['stopping'] == true,
            hostMachine: l['host'] as String?,
          );
        }(),
    ];
    final mail = <Mail>[];
    try {
      for (final m in (jsonDecode(_text('mail').isEmpty ? '[]' : _text('mail')) as List)) {
        final j = (m as Map).cast<String, dynamic>();
        mail.add(Mail.parse(j['file'] as String, j['body'] as String));
      }
    } catch (_) {}
    mail.sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
    final digest = ReviewSection.parseAll((_main['digest'] as String?) ?? '');
    final tracks = <String, LaneTrack>{
      for (final l in lanes)
        l.id: () {
          final f = _files['steps-${l.id}'];
          if (f == null) return LaneTrack.empty;
          return LaneTrack.from(parseStepList((f['text'] as String?) ?? ''), running: l.status.state == LaneState.running, lastDoneId: leadingId(l.lastDone?.summary), source: f['rel'] as String?);
        }(),
    };
    final plan = _text('plan');
    final published = _main['publishedAt'];
    snapshot = StudioSnapshot(
      lanes: lanes,
      userMail: mail,
      openIssues: OpenIssue.parseAll(_text('issues')).reversed.toList(),
      decisions: ReviewSection.parseAll(_text('decisions')).reversed.toList(),
      digest: digest.isEmpty ? null : digest.last,
      mode: _main['mode'] as String?,
      lastReview: parseStamp((_main['lastReview'] as String?) ?? ''),
      readAt: published is Timestamp ? published.toDate() : null,
      tracks: tracks,
      roadmap: plan.isEmpty ? const [] : _roadmapOf(plan),
      board: _text('board').isEmpty ? const [] : parseBoard(_text('board')),
    );
    error = null;
    notifyListeners();
  }

  String? _planSeen;
  List<Milestone> _roadmap = const [];

  /// The plan is 340 KB: parsed again only when it changed.
  List<Milestone> _roadmapOf(String plan) {
    if (!identical(plan, _planSeen) && plan != _planSeen) {
      _planSeen = plan;
      _roadmap = parseRoadmap(plan);
    }
    return _roadmap;
  }

  @override
  Future<void> refresh() async {}

  @override
  String stepLog(String lane, String step, {int lines = 200}) => '';

  @override
  String? get gameDir => _files.keys.any((k) => k.startsWith('doc:')) || _files.containsKey('plan') ? 'the Mac' : null;

  @override
  String gameFile(String rel) => rel == 'production/production-plan.md' ? _text('plan') : _text(fileKey(rel));

  @override
  List<String> gddFiles() => [
        for (final k in _files.keys)
          if (k.startsWith('doc:design|gdd|')) k.substring(4).replaceAll('|', '/'),
      ]..sort();
}
