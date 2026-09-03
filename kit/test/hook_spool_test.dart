import 'dart:convert';
import 'dart:io';

import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;
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

  // `kit hook` runs on every tool call, in every project the plugin is
  // installed in. The spool feeds the host app, and the host only opens a
  // folder that has a plan — so a folder without one must leave nothing
  // behind. Runs the real CLI: the admission test lives in its entry point.
  test('kit hook spools a project with a plan and ignores one without', () async {
    final project = Directory.systemTemp.createTempSync('kit_hook_');
    addTearDown(() => project.deleteSync(recursive: true));

    Future<void> fire() async {
      final proc = await Process.start(
        Platform.resolvedExecutable,
        ['run', 'bin/kit.dart', '--project', project.path, 'hook'],
        environment: {'FLUTTER_KIT_HOME': home.path},
      );
      proc.stdin.write(jsonEncode({'hook_event_name': 'Stop', 'cwd': project.path, 'session_id': 's1'}));
      await proc.stdin.close();
      expect(await proc.exitCode, 0, reason: 'a hook must never fail the turn');
    }

    await fire();
    expect(readSpool(project.path, home: home.path), isEmpty, reason: 'no plan/kit.yaml — nothing to spool for');

    Directory(p.join(project.path, 'plan')).createSync();
    File(p.join(project.path, 'plan', 'kit.yaml')).writeAsStringSync('kit: 2\nproject: { name: T, slug: t }\n');
    await fire();
    expect(readSpool(project.path, home: home.path).map((e) => e.name), ['Stop']);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('kit notify spools a line the host pushes; says so without a plan', () async {
    final project = Directory.systemTemp.createTempSync('kit_notify_');
    addTearDown(() => project.deleteSync(recursive: true));
    Future<ProcessResult> run(List<String> words) => Process.run(
          Platform.resolvedExecutable,
          ['run', 'bin/kit.dart', '--project', project.path, 'notify', ...words],
          environment: {'FLUTTER_KIT_HOME': home.path},
        );
    expect((await run(['Build', 'uploaded'])).exitCode, 1, reason: 'no plan — nothing listens');
    expect(readSpool(project.path, home: home.path), isEmpty);
    Directory(p.join(project.path, 'plan')).createSync();
    File(p.join(project.path, 'plan', 'kit.yaml')).writeAsStringSync('kit: 2\nproject: { name: T, slug: t }\n');
    expect((await run([])).exitCode, 2, reason: 'nothing to say');
    final r = await run(['Build uploaded — 0 errors']);
    expect(r.exitCode, 0, reason: r.stderr.toString());
    final events = readSpool(project.path, home: home.path);
    expect(events.map((e) => e.name), ['Notify']);
    expect(events.single.summary, 'Build uploaded — 0 errors');
    expect(events.single.needsYou, isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));

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
