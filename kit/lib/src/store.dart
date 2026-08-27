/// Reads a `plan/` directory into a [Plan] and writes changes back.
///
/// Two write paths, deliberately:
///
/// * **Whole-file writes** (`writeStep`, `writeItem`) go through the emitter.
///   Used for files the tool creates — an import, a new item.
/// * **Patches** (`patch`) go through `yaml_edit`, which preserves comments
///   and formatting. Used for state flips on files a person or Claude wrote
///   by hand, so `kit done` never rewrites their prose.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'model.dart';
import 'yaml_emit.dart';

class PlanStore {
  PlanStore(this.dir);

  /// The `plan/` directory.
  final String dir;

  String get manifestPath => p.join(dir, 'kit.yaml');
  String get stepsDir => p.join(dir, 'steps');
  String get itemsDir => p.join(dir, 'items');
  String stepPath(String id) => p.join(stepsDir, '$id.yaml');
  String itemPath(String id) => p.join(itemsDir, '$id.yaml');

  bool get exists => File(manifestPath).existsSync();

  Plan load() {
    if (!exists) {
      throw StateError('No plan at $dir (missing kit.yaml). Run `kit import` or `kit init`.');
    }
    final manifest = Manifest.fromMap(_readMap(manifestPath));
    final steps = <Step>[];
    for (final f in _yamlFiles(stepsDir)) {
      final m = _readMap(f.path);
      final s = Step.fromMap(m);
      _checkIdMatchesFile(f.path, s.id);
      steps.add(s);
    }
    final items = <Item>[];
    for (final f in _yamlFiles(itemsDir)) {
      final m = _readMap(f.path);
      final i = Item.fromMap(m);
      _checkIdMatchesFile(f.path, i.id);
      items.add(i);
    }
    return Plan(manifest: manifest, steps: steps, items: items);
  }

  void writeManifest(Manifest m) => _write(manifestPath, emitYaml(m.toMap()));
  void writeStep(Step s) => _write(stepPath(s.id), emitYaml(s.toMap()));
  void writeItem(Item i) => _write(itemPath(i.id), emitYaml(i.toMap()));

  /// Sets `path` (e.g. `['status']` or `['gates', 'qa', 'status']`) to
  /// `value` in the file, preserving everything else. Creates intermediate
  /// maps as needed.
  void patch(String file, List<Object> path, Object? value) {
    final editor = YamlEditor(File(file).readAsStringSync());
    // Ensure parents exist: yaml_edit throws when assigning under a missing key.
    for (var i = 1; i < path.length; i++) {
      final parent = path.sublist(0, i);
      if (_lookup(editor, parent) == null) {
        editor.update(parent, <String, Object?>{});
      }
    }
    editor.update(path, value);
    _write(file, editor.toString());
  }

  /// Appends to a list at `path`, creating it if absent.
  void appendTo(String file, List<Object> path, Object? value) {
    final editor = YamlEditor(File(file).readAsStringSync());
    final existing = _lookup(editor, path);
    if (existing == null) {
      editor.update(path, [value]);
    } else {
      editor.appendToList(path, value);
    }
    _write(file, editor.toString());
  }

  Object? _lookup(YamlEditor e, List<Object> path) {
    try {
      return e.parseAt(path).value;
    } on ArgumentError {
      return null;
    } on StateError {
      return null;
    }
  }

  Map<String, Object?> _readMap(String path) {
    final doc = loadYaml(File(path).readAsStringSync(), sourceUrl: Uri.file(path));
    final plain = deepPlain(doc);
    if (plain is! Map<String, Object?>) {
      throw FormatException('$path: expected a mapping at the top level');
    }
    return plain;
  }

  Iterable<File> _yamlFiles(String d) {
    final directory = Directory(d);
    if (!directory.existsSync()) return const [];
    final files = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  void _checkIdMatchesFile(String path, String id) {
    final stem = p.basenameWithoutExtension(path);
    if (stem != id) {
      throw FormatException('$path: id "$id" does not match the file name "$stem"');
    }
  }

  void _write(String path, String content) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }
}
