import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';

/// Watches the hook spool for one project and hands new events on.
class HookWatcher extends ChangeNotifier {
  HookWatcher(this.dir);

  final String dir;
  final List<HookEvent> events = [];
  HookEvent? get latest => events.isEmpty ? null : events.last;
  void Function(HookEvent e)? onEvent;
  String? _lastFile;
  StreamSubscription<FileSystemEvent>? _sub;
  Timer? _debounce;

  void start() {
    final d = Directory(eventsDirFor(dir))..createSync(recursive: true);
    // On start, show what happened while the app was closed — but do not
    // replay it to the relay as if it were new.
    final existing = readSpool(dir);
    events.addAll(existing.length > 200 ? existing.sublist(existing.length - 200) : existing);
    if (existing.isNotEmpty) _lastFile = existing.last.file;
    _sub = d.watch().listen((_) => _schedule());
    notifyListeners();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _scan);
  }

  void _scan() {
    final all = readSpool(dir);
    for (final e in all) {
      if (_lastFile != null && e.file!.compareTo(_lastFile!) <= 0) continue;
      _lastFile = e.file;
      events.add(e);
      if (events.length > 200) events.removeAt(0);
      onEvent?.call(e);
    }
    if (all.length > 600) pruneSpool(dir);
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
