import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart' show Ask, AskAnswer, DeckMessage;

import '../host/bridge_session.dart';
import '../relay.dart';
import 'studio_desk.dart';

// The step desk on the phone, part 3. The Mac publishes every step's thread
// — the saved rows and each new one as it finishes — with the counts a panel
// shows, and the desk's state (which thread it is answering, a permission it
// waits on); it carries out what the phone sends: a question about a step,
// an answer to the desk's ask.
//
//   studio/main/threads/{key}        {key, questions, lastAnswer, summary}
//   studio/main/threads/{key}/rows   the thread's rows (DeckMessage maps)
//   projects/studio-desk             {studio: true, busy: key?, ask: {...}?}
//   projects/studio-desk/commands    {type: ask, about, stepText, text} ·
//                                    {type: answer, requestId, …}
//
// A key holds a "/" (step:a/ROOMLAB-1C), which a document id cannot: it is
// written with "|" instead.

const kDeskSlug = 'studio-desk';

String threadDocId(String key) => key.replaceAll('/', '|');

class DeskRelay {
  DeskRelay({required this.db, required this.desk, required this.threads});
  final FirebaseFirestore db;
  final BridgeSession desk;
  final StudioThreads threads;

  final Set<String> _published = {};
  CommandListener? _commands;
  Timer? _stateTimer, _rowsTimer;
  bool _publishing = false;

  CollectionReference<Map<String, dynamic>> get _threads => db.collection('studio').doc('main').collection('threads');
  DocumentReference<Map<String, dynamic>> get _deskDoc => db.collection('projects').doc(kDeskSlug);

  void start() {
    unawaited(_deskDoc.set({'studio': true, 'name': 'Step desk'}, SetOptions(merge: true)).catchError((Object _) {}));
    threads.addListener(_rowsSoon);
    desk.addListener(_stateSoon);
    _rowsSoon();
    _publishState();
    _commands = CommandListener(db, kDeskSlug, apply: apply)..start();
  }

  void stop() {
    threads.removeListener(_rowsSoon);
    desk.removeListener(_stateSoon);
    _commands?.dispose();
    _stateTimer?.cancel();
    _rowsTimer?.cancel();
  }

  void _rowsSoon() {
    _rowsTimer?.cancel();
    _rowsTimer = Timer(const Duration(milliseconds: 300), () => unawaited(publishRows()));
  }

  void _stateSoon() {
    _stateTimer?.cancel();
    _stateTimer = Timer(const Duration(milliseconds: 300), _publishState);
  }

  /// Rows not published yet, per thread, with the thread's counts.
  Future<void> publishRows() async {
    if (_publishing) return _rowsSoon();
    _publishing = true;
    try {
      for (final key in threads.keys) {
        final rows = threads.rows(key);
        final fresh = [for (final r in rows) if (!_published.contains('$key|${r.id}')) r];
        if (fresh.isEmpty) continue;
        final doc = _threads.doc(threadDocId(key));
        final batch = db.batch();
        for (final r in fresh) {
          batch.set(doc.collection('rows').doc(r.id), {...r.toMap(), 'order': rows.indexOf(r)});
        }
        batch.set(doc, {'key': key, 'questions': threads.questions(key), 'lastAnswer': threads.lastAnswer(key), 'summary': threads.summary(key), 'updatedAt': FieldValue.serverTimestamp()});
        await batch.commit();
        for (final r in fresh) {
          _published.add('$key|${r.id}');
        }
      }
    } catch (_) {
      // Offline: the next change tries again.
    } finally {
      _publishing = false;
    }
  }

  void _publishState() {
    final t = desk.transcript;
    final busy = t.turnOpen ? threadKeyOf(t.messages.lastOrNull?.about) : null;
    unawaited(_deskDoc.set({'busy': busy, 'ask': t.pending?.toMap(), 'running': desk.running}, SetOptions(merge: true)).catchError((Object _) {}));
  }

  Future<String> apply(Map<String, Object?> cmd) async {
    switch (cmd['type']) {
      case 'ask':
        final about = cmd['about'];
        if (about is! Map) return 'no step named';
        final err = await askDesk(desk, threads, about: {for (final e in about.entries) e.key.toString(): e.value}, stepText: (cmd['stepText'] ?? '').toString(), text: (cmd['text'] ?? '').toString());
        return err ?? 'asked';
      case 'answer':
        final requestId = (cmd['requestId'] ?? '').toString();
        if (desk.transcript.pending?.requestId != requestId) return 'stale: that ask was already answered';
        desk.answer(AskAnswer.fromMap(cmd), requestId: requestId, by: 'phone', remember: cmd['remember'] == true);
        return 'answered';
      default:
        return 'not on the step desk: ${cmd['type']}';
    }
  }
}

/// The phone's threads: the counts for every panel, a thread's rows once it
/// is opened, the desk's state; questions and answers go to the Mac.
class RemoteThreads extends ChangeNotifier implements ThreadsApi {
  RemoteThreads(this.db) : _sender = CommandSender(db, kDeskSlug);
  final FirebaseFirestore db;
  final CommandSender _sender;

  final Map<String, Map<String, dynamic>> _heads = {};
  final Map<String, List<DeckMessage>> _rows = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _rowSubs = {};
  Map<String, dynamic> _desk = const {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _headSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _deskSub;

  /// Questions sent from here whose answer has not come yet, by thread.
  final Set<String> _waiting = {};

  void start() {
    _headSub = db.collection('studio').doc('main').collection('threads').snapshots().listen((q) {
      for (final d in q.docs) {
        final key = d.data()['key'] as String?;
        if (key != null) _heads[key] = d.data();
      }
      notifyListeners();
    });
    _deskSub = db.collection('projects').doc(kDeskSlug).snapshots().listen((d) {
      _desk = d.data() ?? const {};
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _headSub?.cancel();
    _deskSub?.cancel();
    for (final s in _rowSubs.values) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  List<DeckMessage> rowsFor(String key) {
    _rowSubs.putIfAbsent(
      key,
      () => db.collection('studio').doc('main').collection('threads').doc(threadDocId(key)).collection('rows').orderBy('order').snapshots().listen((q) {
        _rows[key] = [for (final d in q.docs) DeckMessage.fromMap(d.data())];
        if (_rows[key]!.isNotEmpty && _rows[key]!.last.role.name == 'assistant') _waiting.remove(key);
        notifyListeners();
      }),
    );
    return _rows[key] ?? const [];
  }

  @override
  int questions(String key) => (_heads[key]?['questions'] as num?)?.toInt() ?? 0;
  @override
  String? lastAnswer(String key) => _heads[key]?['lastAnswer'] as String?;
  @override
  String? summary(String key) => _heads[key]?['summary'] as String?;

  @override
  bool busy(String key) => _desk['busy'] == key || _waiting.contains(key);

  @override
  Ask? get pendingAsk {
    final a = _desk['ask'];
    return a is Map ? Ask.fromMap(a.cast<String, Object?>()) : null;
  }

  @override
  void answer(AskAnswer a, {bool remember = false}) {
    final ask = pendingAsk;
    if (ask == null) return;
    unawaited(_sender.answer(ask, a, remember: remember, from: 'phone'));
  }

  @override
  Future<String?> ask(Map<String, Object?> about, {required String stepText, required String text}) async {
    final key = threadKeyOf(about);
    try {
      await _sender.send({'type': 'ask', 'about': about, 'stepText': stepText, 'text': text}, from: 'phone');
      if (key != null) _waiting.add(key);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not reach the Mac: $e';
    }
  }
}
