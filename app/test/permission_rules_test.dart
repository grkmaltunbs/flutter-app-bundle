import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/permission_rules.dart';
import 'package:path/path.dart' as p;

void main() {
  test('a suggestion of type addRules becomes one rule per entry, spelled as the settings file spells it', () {
    final rules = AppliedRule.fromSuggestion({
      'type': 'addRules',
      'rules': [
        {'toolName': 'Bash', 'ruleContent': 'touch:*'},
        {'toolName': 'WebFetch', 'ruleContent': ''},
      ],
      'behavior': 'allow',
      'destination': 'projectSettings',
    });
    expect(rules.map((r) => r.ruleString), ['Bash(touch:*)', 'WebFetch']);
    expect(rules.first.destination, 'projectSettings');
    expect(AppliedRule.fromSuggestion({'type': 'setMode', 'mode': 'acceptEdits'}), isEmpty);
    expect(AppliedRule.fromJson(rules.first.toJson()), rules.first);
  });

  test('destinations map to the files the CLI uses', () {
    expect(PermissionRules.fileFor('/p', 'localSettings'), p.join('/p', '.claude', 'settings.local.json'));
    expect(PermissionRules.fileFor('/p', 'projectSettings'), p.join('/p', '.claude', 'settings.json'));
    expect(PermissionRules.fileFor('/p', 'userSettings', home: '/h'), p.join('/h', '.claude', 'settings.json'));
    expect(PermissionRules.fileFor('/p', 'somethingNew'), p.join('/p', '.claude', 'settings.local.json'), reason: 'unknown → local, the least reaching');
  });

  test('remove takes one rule out and leaves the rest of the file alone', () {
    final dir = Directory.systemTemp.createTempSync('kit_rules_');
    addTearDown(() => dir.deleteSync(recursive: true));
    const rule = AppliedRule(destination: 'localSettings', tool: 'Bash', rule: 'touch:*', behavior: 'allow');
    expect(PermissionRules.contains(dir.path, rule), isFalse, reason: 'no file yet');
    expect(PermissionRules.remove(dir.path, rule), isFalse);
    final f = File(PermissionRules.fileFor(dir.path, 'localSettings'))..createSync(recursive: true);
    f.writeAsStringSync(jsonEncode({'permissions': {'allow': ['Read', 'Bash(touch:*)'], 'deny': ['Bash(rm:*)']}, 'enabledPlugins': {'x': true}}));
    expect(PermissionRules.contains(dir.path, rule), isTrue);
    expect(PermissionRules.remove(dir.path, rule), isTrue);
    final m = jsonDecode(f.readAsStringSync()) as Map;
    expect(m['permissions']['allow'], ['Read']);
    expect(m['permissions']['deny'], ['Bash(rm:*)']);
    expect(m['enabledPlugins'], {'x': true});
    expect(f.readAsStringSync(), endsWith('\n'));
  });
}
