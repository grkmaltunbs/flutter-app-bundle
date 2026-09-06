import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;

import '../blobs.dart';
import 'bridge_session.dart' show ProcessStarter;
import 'claude_cli.dart';
import 'run_bay.dart' show CommandRunner;

Future<Process> _startProcess(String executable, List<String> args, {String? workingDirectory, Map<String, String>? environment}) =>
    Process.start(executable, args, workingDirectory: workingDirectory, environment: environment);

Future<ProcessResult> _runCommand(String executable, List<String> args, {String? workingDirectory, Map<String, String>? environment}) =>
    Process.run(executable, args, workingDirectory: workingDirectory, environment: environment);

/// Try it: the host builds the app under test — `flutter build apk
/// --debug --target-platform android-arm64` in the project — puts the APK in the bucket at
/// `projects/{slug}/builds/{id}.apk`, writes `builds/{id}` for the phone,
/// pushes "Build ready" (or "Build failed" with the first error line),
/// and keeps the last [buildsKeep] builds, deleting older objects. TRY
/// IT starts one; with [buildOnFlip] on, so does a step flipping to done
/// or code complete. No model, no quota.
class Builds extends ChangeNotifier {
  Builds({
    required this.dir,
    required this.blobs,
    required this.slug,
    this.publish,
    this.prune,
    this.remove,
    this.push,
    ProcessStarter? starter,
    CommandRunner? runner,
    Future<String> Function()? shellPath,
    this.findBinary,
    this.home,
    DateTime Function()? now,
  })  : _starter = starter ?? _startProcess,
        _runner = runner ?? _runCommand,
        _shellPath = shellPath ?? ClaudeCli.shellPath,
        _now = now ?? DateTime.now {
    _load();
  }

  final String dir;
  final BlobStore? blobs;
  final String? Function() slug;

  /// Writes `builds/{id}`; deletes the documents not in the list kept;
  /// deletes one document by id.
  final Future<void> Function(String id, Map<String, Object?> doc)? publish;
  final Future<void> Function(List<String> keepIds)? prune;
  final Future<void> Function(String id)? remove;

  /// The push: ready, or failed.
  final void Function(Notice n)? push;
  final ProcessStarter _starter;
  final CommandRunner _runner;
  final Future<String> Function() _shellPath;
  final String? Function(String name)? findBinary;

  /// Overrides `~/.flutter_kit` — a test keeps its switch in a temp folder.
  final String? home;
  final DateTime Function() _now;

  /// Newest first, the last [buildsKeep].
  final List<BuildRecord> builds = [];

  /// Build on its own when a step flips — a switch per project, kept.
  bool buildOnFlip = false;
  Process? _proc;
  bool _busy = false;

  bool get building => _busy;
  BuildRecord? get latest => builds.isEmpty ? null : builds.first;

  /// What the session document carries: the newest build's state.
  Map<String, Object?> get relay {
    final b = latest;
    return {
      'state': b?.state.name,
      'id': b?.id,
      'progress': b?.progress ?? 0,
      'version': b?.version,
      'error': b?.error,
      'buildOnFlip': buildOnFlip,
    };
  }

  File get _settingsFile => File(p.join(kitHome(home: home), 'builds', '${claudeProjectSlug(dir)}.json'));

  void _load() {
    try {
      final f = _settingsFile;
      if (!f.existsSync()) return;
      final j = jsonDecode(f.readAsStringSync());
      if (j is Map) buildOnFlip = j['buildOnFlip'] == true;
    } on Object {
      // The switch is a convenience; off is the default.
    }
  }

  void setBuildOnFlip(bool on) {
    buildOnFlip = on;
    try {
      _settingsFile
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({'buildOnFlip': on}));
    } on Object {
      // Kept for the session at least.
    }
    notifyListeners();
  }

  /// A step flipped: build, when the switch says so and nothing runs.
  Future<void> onFlip() async {
    if (!buildOnFlip || _busy) return;
    await start(by: 'flip');
  }

  Future<Map<String, String>> _env() async => {...Platform.environment, 'PATH': await _shellPath()};

  Future<String> _bin(String name) async {
    final found = findBinary?.call(name);
    if (found != null) return found;
    for (final d in (await _shellPath()).split(':')) {
      final f = File(p.join(d, name));
      if (f.existsSync()) return f.path;
    }
    return name;
  }

  Future<String> _git(List<String> args, Map<String, String> env) async {
    try {
      final r = await _runner(await _bin('git'), args, workingDirectory: dir, environment: env).timeout(const Duration(seconds: 15));
      return r.exitCode == 0 ? r.stdout.toString().trim() : '';
    } on Object {
      return '';
    }
  }

  void _set(BuildRecord b) {
    final i = builds.indexWhere((x) => x.id == b.id);
    if (i < 0) {
      builds.insert(0, b);
    } else {
      builds[i] = b;
    }
    notifyListeners();
    final pub = publish;
    if (pub != null) unawaited(pub(b.id, b.toMap()).catchError((Object _) {}));
  }

  /// Starts a build. Returns the one line to toast; the work goes on
  /// after it, and the record says how far.
  Future<String> start({String by = 'phone'}) async {
    if (_busy) return 'a build is running';
    _busy = true;
    final env = await _env();
    String pubspec = '';
    try {
      pubspec = File(p.join(dir, 'pubspec.yaml')).readAsStringSync();
    } on Object {
      _busy = false;
      return 'no pubspec.yaml in this folder';
    }
    final id = 'b${_now().toUtc().millisecondsSinceEpoch ~/ 1000}';
    var b = BuildRecord(id: id, at: _now(), sha: await _git(['rev-parse', '--short', 'HEAD'], env), branch: await _git(['rev-parse', '--abbrev-ref', 'HEAD'], env), version: versionOf(pubspec), name: nameOf(pubspec), by: by);
    _set(b);
    unawaited(_run(b, env));
    return 'building ${b.version.isEmpty ? '' : '${b.version} '}on the Mac';
  }

  Future<void> _run(BuildRecord b, Map<String, String> env) async {
    final log = <String>[];
    void line(String l) {
      final t = l.trimRight();
      if (t.isEmpty) return;
      log.add(t);
      if (log.length > 200) log.removeAt(0);
      final progress = buildProgressFor(t, b.progress);
      if (progress != b.progress) _set(b = b.copyWith(progress: progress, log: List.of(log)));
    }

    try {
      final bin = await _bin('flutter');
      // The phone in hand is arm64; a fat debug APK is three times the size.
      _proc = await _starter(bin, ['build', 'apk', '--debug', '--target-platform', 'android-arm64'], workingDirectory: dir, environment: env);
      final out = _proc!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(line);
      final err = _proc!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(line);
      final code = await _proc!.exitCode;
      // The last lines, if the pipes are still draining; a process that
      // never closes them does not hold the build up.
      await Future.wait([out.asFuture<void>(), err.asFuture<void>()]).timeout(const Duration(milliseconds: 400), onTimeout: () => const []);
      await out.cancel();
      await err.cancel();
      _proc = null;
      if (code != 0) {
        await _fail(b, firstErrorLine(log), log);
        return;
      }
      final apk = File(p.join(dir, debugApkPath));
      if (!apk.existsSync()) {
        await _fail(b, 'the build ended but left no APK at $debugApkPath', log);
        return;
      }
      final bytes = apk.readAsBytesSync();
      _set(b = b.copyWith(progress: 0.9, size: bytes.length, log: List.of(log)));
      final s = slug();
      final store = blobs;
      if (store == null || s == null) {
        await _fail(b, 'no bucket to put the build in', log);
        return;
      }
      final path = buildPath(s, b.id);
      await store.put(path, bytes, contentType: 'application/vnd.android.package-archive', onProgress: (f) {
        final progress = 0.9 + f * 0.1;
        if (progress - b.progress >= 0.02) _set(b = b.copyWith(progress: progress));
      });
      _set(b = b.copyWith(state: BuildState.ready, progress: 1, path: path, size: bytes.length, at: _now(), log: List.of(log)));
      push?.call(noticeForBuild(project: b.name.isEmpty ? p.basename(dir) : b.name, buildId: b.id, ready: true, version: b.version, size: b.size));
      await _pruneOld();
    } on Object catch (e) {
      await _fail(b, 'build failed: $e', log);
    } finally {
      _busy = false;
      _proc = null;
      notifyListeners();
    }
  }

  Future<void> _fail(BuildRecord b, String why, List<String> log) async {
    _set(b.copyWith(state: BuildState.failed, error: why, log: List.of(log), at: _now()));
    push?.call(noticeForBuild(project: b.name.isEmpty ? p.basename(dir) : b.name, buildId: b.id, ready: false, version: b.version, error: why));
  }

  /// The last [buildsKeep] stay; older objects and documents go.
  Future<void> _pruneOld() async {
    final stale = staleBuilds([for (final b in builds) b.id]);
    for (final id in stale) {
      final b = builds.firstWhere((x) => x.id == id);
      builds.remove(b);
      final path = b.path;
      final store = blobs;
      if (path != null && store != null) unawaited(store.delete(path).catchError((Object _) {}));
    }
    final pr = prune;
    if (pr != null && stale.isNotEmpty) await pr([for (final b in builds) b.id]).catchError((Object _) {});
    notifyListeners();
  }

  /// Removes one build: the object and the document — by id alone when
  /// the record is not in memory (a host that just came up).
  Future<String> delete(String id) async {
    if (id.isEmpty) return 'no build named';
    final i = builds.indexWhere((b) => b.id == id);
    final b = i < 0 ? null : builds.removeAt(i);
    final store = blobs;
    final s = slug();
    final path = b?.path ?? (s == null ? null : buildPath(s, id));
    if (path != null && store != null) await store.delete(path).catchError((Object _) {});
    final rm = remove;
    if (rm != null) await rm(id).catchError((Object _) {});
    notifyListeners();
    return 'removed ${b == null || b.version.isEmpty ? id : b.version}';
  }

  /// Takes what the relay already holds, newest first — a host restart.
  void seed(List<BuildRecord> existing) {
    if (builds.isNotEmpty) return;
    builds.addAll(existing.take(buildsKeep));
    notifyListeners();
  }

  @override
  void dispose() {
    _proc?.kill(ProcessSignal.sigterm);
    super.dispose();
  }
}
