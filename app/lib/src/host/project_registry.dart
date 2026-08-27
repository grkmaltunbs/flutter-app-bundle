import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Folders the host has opened, newest first.
class ProjectRegistry extends ChangeNotifier {
  final List<String> dirs = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    dirs
      ..clear()
      ..addAll(prefs.getStringList('projects') ?? const []);
    notifyListeners();
  }

  Future<void> add(String dir) async {
    dirs
      ..remove(dir)
      ..insert(0, dir);
    await _save();
  }

  Future<void> remove(String dir) async {
    dirs.remove(dir);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('projects', dirs);
    notifyListeners();
  }

  static bool hasPlan(String dir) => File(p.join(dir, 'plan', 'kit.yaml')).existsSync();
}
