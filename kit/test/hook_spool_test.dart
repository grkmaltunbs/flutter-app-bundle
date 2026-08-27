import 'dart:io';

import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

void main() {
  late Directory home;
  setUp(() => home = Directory.systemTemp.createTempSync('kit_spool_'));
  tearDown(() => home.deleteSync(recursive: true));

  test('slug matches Claude Code\'s own project folder name', () {
    expect(claudeProjectSlug('/Users/ren/StudioProjects/nahmatik'), '-Users-ren-StudioProjects-nahmatik');
    expect(claudeProjectSlug('/a/b_c.d'), '-a-b-c-d');
  });

  test('events spool in arrival order and read back with a summary', () {
    final t0 = DateTime.utc(2026, 8, 28, 9, 0, 0);
    spoolHookEvent({'hook_event_name': 'PostToolUse', 'cwd': '/p/x', 'session_id': 's1', 'tool_name': 'Bash', 'tool_input': {'command': 'flutter test'}}, now: t0, home: home.path);
    spoolHookEvent({'hook_event_name': 'Stop', 'cwd': '/p/x', 'session_id': 's1'}, now: t0.add(const Duration(milliseconds: 1)), home: home.path);
    spoolHookEvent({'hook_event_name': 'Notification', 'cwd': '/p/x', 'session_id': 's1', 'message': 'Claude needs your permission to use Bash'}, now: t0.add(const Duration(seconds: 2)), home: home.path);
    final events = readSpool('/p/x', home: home.path);
    expect(events.map((e) => e.name), ['PostToolUse', 'Stop', 'Notification']);
    expect(events[0].summary, 'Bash · flutter test');
    expect(events[0].needsYou, isFalse);
    expect(events[1].summary, 'Claude finished a turn');
    expect(events[2].needsYou, isTrue);
    expect(events[2].summary, contains('permission'));
    expect(events[0].at, t0);
    expect(readSpool('/p/other', home: home.path), isEmpty);
  });

  test('prune keeps the newest', () {
    for (var i = 0; i < 5; i++) {
      spoolHookEvent({'hook_event_name': 'Stop', 'cwd': '/p/x'}, now: DateTime.utc(2026, 1, 1, 0, 0, i), home: home.path);
    }
    pruneSpool('/p/x', keep: 2, home: home.path);
    final left = readSpool('/p/x', home: home.path);
    expect(left.length, 2);
    expect(left.last.at, DateTime.utc(2026, 1, 1, 0, 0, 4));
  });
}
