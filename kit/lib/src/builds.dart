/// Try it — the pure half: a build's record as both devices see it
/// (`builds/{id}`), the lines the screens draw, and the version and
/// error lines read off files. Running the build, the bucket and the
/// installer are the host's and the phone's (`app/lib/src/host/builds.dart`,
/// the relay).
library;

import 'bridge.dart' show formatBytes;

enum BuildState { building, ready, failed }

/// How many builds a project keeps in the bucket and the relay.
const buildsKeep = 3;

/// Where a build lives in the bucket.
String buildPath(String slug, String id) => 'projects/$slug/builds/$id.apk';

/// One build of the app under test. [log] holds the tool's last lines —
/// enough to see why a build failed.
class BuildRecord {
  const BuildRecord({
    required this.id,
    this.state = BuildState.building,
    this.sha = '',
    this.branch = '',
    this.version = '',
    this.size = 0,
    this.at,
    this.path,
    this.progress = 0,
    this.error,
    this.log = const [],
    this.by,
    this.name = '',
  });

  factory BuildRecord.fromMap(Map<String, Object?> m) => BuildRecord(
        id: (m['id'] ?? '').toString(),
        state: BuildState.values.firstWhere((s) => s.name == m['state'], orElse: () => BuildState.building),
        sha: (m['sha'] ?? '').toString(),
        branch: (m['branch'] ?? '').toString(),
        version: (m['version'] ?? '').toString(),
        size: (m['size'] as num?)?.toInt() ?? 0,
        at: DateTime.tryParse(m['at']?.toString() ?? ''),
        path: _text(m['path']),
        progress: (m['progress'] as num?)?.toDouble() ?? 0,
        error: _text(m['error']),
        log: [for (final l in (m['log'] as List? ?? const [])) l.toString()],
        by: _text(m['by']),
        name: (m['name'] ?? '').toString(),
      );

  final String id;
  final BuildState state;
  final String sha;
  final String branch;

  /// `1.0.0+1`, from the project's pubspec.
  final String version;
  final int size;
  final DateTime? at;

  /// The object in the bucket, once uploaded.
  final String? path;

  /// 0…1 — the build, then the upload.
  final double progress;
  final String? error;
  final List<String> log;

  /// `phone`, `Mac`, or `flip` when a step's flip started it.
  final String? by;

  /// The app's name, for the installer's line.
  final String name;

  bool get building => state == BuildState.building;
  bool get ready => state == BuildState.ready;
  bool get failed => state == BuildState.failed;

  Map<String, Object?> toMap() => {
        'id': id,
        'state': state.name,
        'sha': sha,
        'branch': branch,
        'version': version,
        'size': size,
        'at': at?.toUtc().toIso8601String(),
        'path': path,
        'progress': progress,
        'error': error,
        'log': log,
        'by': by,
        'name': name,
      };

  BuildRecord copyWith({BuildState? state, String? sha, String? branch, String? version, int? size, DateTime? at, String? path, double? progress, String? error, List<String>? log, String? by, String? name}) => BuildRecord(
        id: id,
        state: state ?? this.state,
        sha: sha ?? this.sha,
        branch: branch ?? this.branch,
        version: version ?? this.version,
        size: size ?? this.size,
        at: at ?? this.at,
        path: path ?? this.path,
        progress: progress ?? this.progress,
        error: error ?? this.error,
        log: log ?? this.log,
        by: by ?? this.by,
        name: name ?? this.name,
      );

  static String? _text(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }
}

/// `Building · 42 %`, `Ready · 1.0.0+1 · 24 MB · 2 min ago`, `Failed · <why>`.
String buildLine(BuildRecord b, {DateTime? now}) {
  switch (b.state) {
    case BuildState.building:
      return 'Building · ${(b.progress * 100).round()} %';
    case BuildState.ready:
      final t = now ?? DateTime.now();
      final age = b.at == null ? '' : ' · ${_ago(t.difference(b.at!))}';
      return 'Ready · ${b.version.isEmpty ? b.sha : b.version} · ${formatBytes(b.size)}$age';
    case BuildState.failed:
      return 'Failed · ${b.error ?? 'see the log'}';
  }
}

String _ago(Duration d) {
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// The first line of a build's output that reads like the reason it
/// failed — `error:`, `FAILURE:`, an exception — else its last line.
String firstErrorLine(List<String> log) {
  final hit = log.where((l) => RegExp(r'\berror\b|FAILURE|Exception|What went wrong', caseSensitive: false).hasMatch(l)).where((l) => !l.contains('warning')).toList();
  if (hit.isNotEmpty) return hit.first.trim();
  return log.isEmpty ? 'the build produced no output' : log.last.trim();
}

/// The `version:` line of a pubspec, `1.0.0+1`; empty when there is none.
String versionOf(String pubspec) => RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1) ?? '';

/// The `name:` line of a pubspec.
String nameOf(String pubspec) => RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1) ?? '';

/// Where `flutter build apk --debug` leaves the APK, relative to the project.
const debugApkPath = 'build/app/outputs/flutter-apk/app-debug.apk';

/// How far the build is, read off its output: the Gradle run is most of it.
double buildProgressFor(String line, double current) {
  if (line.contains('Running Gradle task')) return current < 0.15 ? 0.15 : current;
  if (line.contains('✓ Built') || line.contains('Built build/')) return 0.85;
  return current;
}

/// The stale builds when [ids] are newest first: everything past [buildsKeep].
List<String> staleBuilds(List<String> idsNewestFirst) => idsNewestFirst.length <= buildsKeep ? const [] : idsNewestFirst.sublist(buildsKeep);
