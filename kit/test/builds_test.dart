// Try it, the pure half: the build's record, the lines, what is read
// off a pubspec and a log, the notice.
import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

void main() {
  test('the record round-trips with every key', () {
    final at = DateTime.utc(2026, 9, 6, 7);
    final b = BuildRecord(id: 'b1', state: BuildState.ready, sha: 'abc1234', branch: 'main', version: '1.0.0+1', size: 24000000, at: at, path: 'projects/demo/builds/b1.apk', progress: 1, log: const ['✓ Built'], by: 'phone', name: 'kit_scratch');
    final m = b.toMap();
    expect(m.keys, containsAll(['id', 'state', 'sha', 'branch', 'version', 'size', 'at', 'path', 'progress', 'error', 'log', 'by', 'name']));
    expect(m['error'], isNull);
    final back = BuildRecord.fromMap(m);
    expect(back.ready, isTrue);
    expect(back.version, '1.0.0+1');
    expect(back.path, 'projects/demo/builds/b1.apk');
    expect(back.log, ['✓ Built']);
    expect(back.by, 'phone');
    expect(BuildRecord.fromMap(const {'id': 'x'}).building, isTrue);
    expect(b.copyWith(state: BuildState.failed, error: 'no').failed, isTrue);
  });

  test('the lines: building with a percentage, ready with version, size and age, failed with the reason', () {
    final at = DateTime.utc(2026, 9, 6, 7);
    expect(buildLine(const BuildRecord(id: 'b', progress: 0.42)), 'Building · 42 %');
    expect(buildLine(BuildRecord(id: 'b', state: BuildState.ready, version: '1.0.0+1', size: 24 * 1024 * 1024, at: at), now: at.add(const Duration(minutes: 2))), 'Ready · 1.0.0+1 · 24.0 MB · 2 min ago');
    expect(buildLine(BuildRecord(id: 'b', state: BuildState.ready, sha: 'abc1234', size: 1024, at: at), now: at.add(const Duration(hours: 3))), 'Ready · abc1234 · 1 KB · 3 h ago');
    expect(buildLine(const BuildRecord(id: 'b', state: BuildState.failed, error: 'FAILURE: Build failed with an exception.')), 'Failed · FAILURE: Build failed with an exception.');
    expect(buildLine(const BuildRecord(id: 'b', state: BuildState.failed)), 'Failed · see the log');
  });

  test('the version and the name off a pubspec; the first error line off a log; the progress off the output', () {
    const pubspec = 'name: kit_scratch\ndescription: x\nversion: 1.2.3+45\n';
    expect(versionOf(pubspec), '1.2.3+45');
    expect(nameOf(pubspec), 'kit_scratch');
    expect(versionOf('name: x'), '');
    expect(firstErrorLine(const ['Running Gradle task...', "warning: unused", 'FAILURE: Build failed with an exception.', '* What went wrong:']), 'FAILURE: Build failed with an exception.');
    expect(firstErrorLine(const ['lib/main.dart:3:1: Error: Expected a declaration.']), 'lib/main.dart:3:1: Error: Expected a declaration.');
    expect(firstErrorLine(const ['just output']), 'just output');
    expect(firstErrorLine(const []), 'the build produced no output');
    expect(buildProgressFor("Running Gradle task 'assembleDebug'...", 0), 0.15);
    expect(buildProgressFor('some line', 0.15), 0.15);
    expect(buildProgressFor('✓ Built build/app/outputs/flutter-apk/app-debug.apk (24.0MB)', 0.15), 0.85);
    expect(staleBuilds(['d', 'c', 'b', 'a']), ['a']);
    expect(staleBuilds(['b', 'a']), isEmpty);
    expect(buildPath('demo', 'b1'), 'projects/demo/builds/b1.apk');
  });

  test('the notice: ready names the version and carries the id; failed carries the reason', () {
    final ok = noticeForBuild(project: 'Nahmatik', buildId: 'b1', ready: true, version: '3.2.0+41', size: 24 * 1024 * 1024);
    expect(ok.kind, NoticeKind.build);
    expect(ok.channel, 'done');
    expect(ok.title, 'Build ready · Nahmatik · 3.2.0+41');
    expect(ok.body, 'Tap to install · 24.0 MB.');
    expect(ok.data('nahmatik'), {'slug': 'nahmatik', 'kind': 'build', 'buildId': 'b1'});
    final bad = noticeForBuild(project: 'Nahmatik', buildId: 'b2', ready: false, version: '', error: 'FAILURE: Build failed with an exception.');
    expect(bad.title, 'Build failed · Nahmatik');
    expect(bad.body, 'FAILURE: Build failed with an exception.');
    expect(bad.data('nahmatik')['buildId'], 'b2');
  });
}
