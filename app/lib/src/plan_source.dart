import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;

/// Where a screen gets its [Plan]. The host reads `plan/`; the phone reads
/// the mirror. Both hand the screens the same object and the same [Graph],
/// so a bubble is the same colour on both.
abstract class PlanSource extends ChangeNotifier {
  Plan? get plan;
  String? get error;
  Graph? get graph => plan == null ? null : Graph(plan!);
}

/// `plan/` on disk, re-read whenever a file under it changes (Claude's
/// `kit gate`, `kit step done`, the host applying an inbox batch…).
class LocalPlanSource extends PlanSource {
  LocalPlanSource(this.projectDir) : store = PlanStore(p.join(projectDir, 'plan'));

  final String projectDir;
  final PlanStore store;
  Plan? _plan;
  String? _error;
  StreamSubscription<FileSystemEvent>? _sub;
  Timer? _debounce;

  @override
  Plan? get plan => _plan;
  @override
  String? get error => _error;

  void start() {
    reload();
    final dir = Directory(store.dir);
    if (dir.existsSync()) {
      _sub = dir.watch(recursive: true).listen((_) => _schedule());
    }
  }

  void _schedule() {
    _debounce?.cancel();
    // Claude writes a YAML file in one go, but an editor may not; 400 ms
    // lets a burst of writes settle into one reload.
    _debounce = Timer(const Duration(milliseconds: 400), reload);
  }

  void reload() {
    try {
      _plan = store.load();
      _error = null;
    } on Object catch (e) {
      // Keep the last good plan; a half-written file is not a reason to
      // blank the screen.
      _error = e.toString();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

/// The mirror on the relay project: one document per step and item, plus
/// the project document carrying the manifest. Rebuilt on every change.
class RemotePlanSource extends PlanSource {
  RemotePlanSource(this.db, this.slug);

  final FirebaseFirestore db;
  final String slug;
  Map<String, Object?>? _manifest;
  Map<String, Map<String, Object?>>? _steps;
  Map<String, Map<String, Object?>>? _items;
  Plan? _plan;
  String? _error;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  Plan? get plan => _plan;
  @override
  String? get error => _error;

  DocumentReference<Map<String, dynamic>> get projectRef => db.collection('projects').doc(slug);

  void start() {
    _subs.add(projectRef.snapshots().listen((d) {
      final m = d.data()?['manifest'];
      _manifest = m is Map ? {for (final e in m.entries) e.key.toString(): e.value} : null;
      _rebuild();
    }, onError: _onError));
    _subs.add(projectRef.collection('steps').snapshots().listen((q) {
      _steps = {for (final d in q.docs) d.id: d.data()};
      _rebuild();
    }, onError: _onError));
    _subs.add(projectRef.collection('items').snapshots().listen((q) {
      _items = {for (final d in q.docs) d.id: d.data()};
      _rebuild();
    }, onError: _onError));
  }

  void _onError(Object e) {
    _error = e.toString();
    notifyListeners();
  }

  void _rebuild() {
    if (_manifest == null || _steps == null || _items == null) return;
    try {
      _plan = planFromDocs(manifest: _manifest!, steps: _steps!.values, items: _items!.values);
      _error = null;
    } on Object catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
