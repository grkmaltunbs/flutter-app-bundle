import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One rule the CLI wrote to a settings file because the user answered an
/// ask with Always. Kept so the Session tab can list it and take it back.
class AppliedRule {
  const AppliedRule({required this.destination, required this.tool, required this.rule, required this.behavior});

  factory AppliedRule.fromJson(Map<String, Object?> m) => AppliedRule(
        destination: (m['destination'] ?? 'localSettings').toString(),
        tool: (m['tool'] ?? '').toString(),
        rule: (m['rule'] ?? '').toString(),
        behavior: (m['behavior'] ?? 'allow').toString(),
      );

  /// The rules one `permission_suggestions` entry of type `addRules` adds.
  static List<AppliedRule> fromSuggestion(Map<String, Object?> s) {
    if (s['type'] != 'addRules') return const [];
    final destination = (s['destination'] ?? 'localSettings').toString();
    final behavior = (s['behavior'] ?? 'allow').toString();
    return [
      for (final r in (s['rules'] as List? ?? const []))
        if (r is Map) AppliedRule(destination: destination, tool: (r['toolName'] ?? '').toString(), rule: (r['ruleContent'] ?? '').toString(), behavior: behavior),
    ];
  }

  final String destination;
  final String tool;
  final String rule;
  final String behavior;

  /// The settings-file spelling: `Bash(touch:*)`, or the bare tool.
  String get ruleString => rule.isEmpty ? tool : '$tool($rule)';

  Map<String, Object?> toJson() => {'destination': destination, 'tool': tool, 'rule': rule, 'behavior': behavior};

  @override
  bool operator ==(Object other) => other is AppliedRule && other.destination == destination && other.tool == tool && other.rule == rule && other.behavior == behavior;
  @override
  int get hashCode => Object.hash(destination, tool, rule, behavior);
}

/// The settings files the CLI's suggestions name, and taking a rule back
/// out of one.
class PermissionRules {
  static String fileFor(String dir, String destination, {String? home}) {
    switch (destination) {
      case 'projectSettings':
        return p.join(dir, '.claude', 'settings.json');
      case 'userSettings':
        return p.join(home ?? Platform.environment['HOME'] ?? '', '.claude', 'settings.json');
      default:
        return p.join(dir, '.claude', 'settings.local.json');
    }
  }

  static List<String> _list(Map<String, Object?> settings, String behavior) {
    final perms = settings['permissions'];
    if (perms is! Map) return const [];
    final l = perms[behavior];
    return l is List ? [for (final e in l) e.toString()] : const [];
  }

  /// True when [rule] is in the file it names.
  static bool contains(String dir, AppliedRule rule, {String? home}) {
    final settings = _read(fileFor(dir, rule.destination, home: home));
    return settings != null && _list(settings, rule.behavior).contains(rule.ruleString);
  }

  /// Removes [rule] from its file. Returns false when it was not there.
  static bool remove(String dir, AppliedRule rule, {String? home}) {
    final path = fileFor(dir, rule.destination, home: home);
    final settings = _read(path);
    if (settings == null) return false;
    final perms = settings['permissions'];
    if (perms is! Map) return false;
    final l = perms[rule.behavior];
    if (l is! List || !l.contains(rule.ruleString)) return false;
    final kept = [for (final e in l) if (e.toString() != rule.ruleString) e];
    final newPerms = {for (final e in perms.entries) e.key.toString(): e.value}..[rule.behavior] = kept;
    File(path).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({...settings, 'permissions': newPerms})}\n');
    return true;
  }

  static Map<String, Object?>? _read(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      final m = jsonDecode(f.readAsStringSync());
      return m is Map ? {for (final e in m.entries) e.key.toString(): e.value} : null;
    } on Object {
      return null;
    }
  }
}
