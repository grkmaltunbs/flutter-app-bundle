/// The run bay's pure half: the daemon protocol `flutter run --machine`
/// speaks, the run's state as both devices see it (`session.run`), the
/// log ring, and the lines the screens draw. The process, the clock and
/// the relay are the host's (`app/lib/src/host/run_bay.dart`).
library;

import 'dart:convert';

/// One device `flutter devices --machine` lists — or an emulator
/// `flutter emulators` knows that is not booted ([off]).
class RunDevice {
  const RunDevice({required this.id, required this.name, this.platform = '', this.emulator = false, this.off = false});

  factory RunDevice.fromMap(Map<String, Object?> m) => RunDevice(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        platform: (m['platform'] ?? '').toString(),
        emulator: m['emulator'] == true,
        off: m['off'] == true,
      );

  /// From one entry of `flutter devices --machine`.
  factory RunDevice.fromFlutter(Map<String, Object?> m) => RunDevice(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        platform: (m['targetPlatform'] ?? '').toString(),
        emulator: m['emulator'] == true,
      );

  final String id;
  final String name;

  /// `ios`, `android-arm64`, `darwin`, `web-javascript`…
  final String platform;
  final bool emulator;

  /// Listed but not booted — picking it boots it first.
  final bool off;

  /// `ios`, `android`, `macos`, `web`, or the platform as given.
  String get kind {
    final p = platform.toLowerCase();
    if (p.startsWith('ios')) return 'ios';
    if (p.startsWith('android')) return 'android';
    if (p.startsWith('darwin') || p == 'macos') return 'macos';
    if (p.startsWith('web')) return 'web';
    return p;
  }

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'platform': platform, 'emulator': emulator, 'off': off};
}

/// The device a plan's `qa.runtime` names — `ios-simulator` → a booted
/// iOS simulator, `android`/`android-emulator` → an Android device or
/// emulator, `macos` → the Mac — else the first one there is.
RunDevice? defaultDevice(List<RunDevice> devices, String? runtime) {
  if (devices.isEmpty) return null;
  final r = (runtime ?? '').toLowerCase();
  bool fits(RunDevice d) {
    if (r.startsWith('ios')) return d.kind == 'ios' && (!r.contains('simulator') || d.emulator);
    if (r.startsWith('android')) return d.kind == 'android';
    if (r.startsWith('macos') || r == 'desktop') return d.kind == 'macos';
    if (r.startsWith('web') || r == 'chrome') return d.kind == 'web';
    return false;
  }

  for (final d in devices) {
    if (!d.off && fits(d)) return d;
  }
  for (final d in devices) {
    if (fits(d)) return d;
  }
  return devices.firstWhere((d) => !d.off, orElse: () => devices.first);
}

/// One line of the daemon protocol: an event the tool raised, or the
/// answer to a command by its id. A line that is neither is the app's
/// own output — a log line.
sealed class DaemonLine {
  const DaemonLine();
}

class DaemonEvent extends DaemonLine {
  const DaemonEvent(this.event, this.params);
  final String event;
  final Map<String, Object?> params;
}

class DaemonResponse extends DaemonLine {
  const DaemonResponse(this.id, {this.result, this.error});
  final int id;
  final Object? result;
  final String? error;
}

/// `[{"event":"app.started","params":{…}}]` → the event; `[{"id":1,"result":…}]`
/// → the response; anything else → null.
DaemonLine? parseDaemonLine(String line) {
  final s = line.trim();
  if (!s.startsWith('[{') || !s.endsWith('}]')) return null;
  final Object? raw;
  try {
    raw = jsonDecode(s);
  } on FormatException {
    return null;
  }
  if (raw is! List || raw.isEmpty || raw.first is! Map) return null;
  final m = {for (final e in (raw.first as Map).entries) e.key.toString(): e.value as Object?};
  final event = m['event']?.toString();
  if (event != null) {
    final p = m['params'];
    return DaemonEvent(event, p is Map ? {for (final e in p.entries) e.key.toString(): e.value as Object?} : const {});
  }
  final id = m['id'];
  if (id is num) return DaemonResponse(id.toInt(), result: m['result'], error: m['error']?.toString());
  return null;
}

/// A command to the daemon: `[{"id":1,"method":"app.restart","params":{…}}]`.
String encodeDaemonCommand(int id, String method, Map<String, Object?> params) => jsonEncode([
      {'id': id, 'method': method, 'params': params}
    ]);

/// The DTD URI `--print-dtd` prints, when [line] carries one.
String? dtdUriIn(String line) {
  if (!line.contains('Dart Tooling Daemon')) return null;
  return RegExp(r'ws://\S+').firstMatch(line)?.group(0);
}

enum RunPhase { idle, starting, running, stopped, failed }

/// The run as both devices see it — `session.run`. Every key is written,
/// null when unset, since the host merges the session document.
class RunState {
  const RunState({
    this.phase = RunPhase.idle,
    this.runId,
    this.device,
    this.deviceName,
    this.appId,
    this.since,
    this.vmUri,
    this.dtdUri,
    this.error,
    this.exceptions = 0,
    this.lastError,
    this.lines = 0,
    this.reloadOnEdit = false,
    this.devices = const [],
    this.devicesAt,
  });

  factory RunState.fromMap(Map<String, Object?> m) => RunState(
        phase: RunPhase.values.firstWhere((p) => p.name == m['phase'], orElse: () => RunPhase.idle),
        runId: _text(m['runId']),
        device: _text(m['device']),
        deviceName: _text(m['deviceName']),
        appId: _text(m['appId']),
        since: DateTime.tryParse(m['since']?.toString() ?? ''),
        vmUri: _text(m['vmUri']),
        dtdUri: _text(m['dtdUri']),
        error: _text(m['error']),
        exceptions: (m['exceptions'] as num?)?.toInt() ?? 0,
        lastError: _text(m['lastError']),
        lines: (m['lines'] as num?)?.toInt() ?? 0,
        reloadOnEdit: m['reloadOnEdit'] == true,
        devices: [for (final d in (m['devices'] as List? ?? const [])) if (d is Map) RunDevice.fromMap({for (final e in d.entries) e.key.toString(): e.value as Object?})],
        devicesAt: DateTime.tryParse(m['devicesAt']?.toString() ?? ''),
      );

  final RunPhase phase;

  /// The document under `runs/` the log lives in — one per start.
  final String? runId;
  final String? device;
  final String? deviceName;
  final String? appId;
  final DateTime? since;
  final String? vmUri;
  final String? dtdUri;

  /// Why the run failed or could not start.
  final String? error;

  /// Error lines the app wrote since it started — the pill goes amber.
  final int exceptions;
  final String? lastError;

  /// Lines in the log so far.
  final int lines;
  final bool reloadOnEdit;

  /// The devices the host last listed.
  final List<RunDevice> devices;
  final DateTime? devicesAt;

  bool get up => phase == RunPhase.starting || phase == RunPhase.running;
  bool get running => phase == RunPhase.running;

  Map<String, Object?> toMap() => {
        'phase': phase.name,
        'runId': runId,
        'device': device,
        'deviceName': deviceName,
        'appId': appId,
        'since': since?.toUtc().toIso8601String(),
        'vmUri': vmUri,
        'dtdUri': dtdUri,
        'error': error,
        'exceptions': exceptions,
        'lastError': lastError,
        'lines': lines,
        'reloadOnEdit': reloadOnEdit,
        'devices': [for (final d in devices) d.toMap()],
        'devicesAt': devicesAt?.toUtc().toIso8601String(),
      };

  RunState copyWith({
    RunPhase? phase,
    String? runId,
    String? device,
    String? deviceName,
    String? appId,
    DateTime? since,
    String? vmUri,
    String? dtdUri,
    String? error,
    int? exceptions,
    String? lastError,
    int? lines,
    bool? reloadOnEdit,
    List<RunDevice>? devices,
    DateTime? devicesAt,
    bool clear = false,
  }) =>
      RunState(
        phase: phase ?? this.phase,
        runId: clear ? runId : runId ?? this.runId,
        device: clear ? device : device ?? this.device,
        deviceName: clear ? deviceName : deviceName ?? this.deviceName,
        appId: clear ? appId : appId ?? this.appId,
        since: clear ? since : since ?? this.since,
        vmUri: clear ? vmUri : vmUri ?? this.vmUri,
        dtdUri: clear ? dtdUri : dtdUri ?? this.dtdUri,
        error: clear ? error : error ?? this.error,
        exceptions: clear ? (exceptions ?? 0) : exceptions ?? this.exceptions,
        lastError: clear ? lastError : lastError ?? this.lastError,
        lines: clear ? (lines ?? 0) : lines ?? this.lines,
        reloadOnEdit: reloadOnEdit ?? this.reloadOnEdit,
        devices: devices ?? this.devices,
        devicesAt: devicesAt ?? this.devicesAt,
      );

  static String? _text(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }
}

/// `Running · iPhone 17 Pro · 4 min`, `Starting · iPhone 17 Pro`,
/// `Failed · <why>` — the pill on both devices. Null while idle.
String? runLine(RunState r, {DateTime? now}) {
  final name = r.deviceName ?? r.device ?? '';
  switch (r.phase) {
    case RunPhase.idle:
      return null;
    case RunPhase.starting:
      return 'Starting · $name';
    case RunPhase.running:
      final since = r.since;
      final mins = since == null ? null : (now ?? DateTime.now()).difference(since).inMinutes;
      final age = mins == null ? '' : mins < 1 ? ' · just now' : mins < 60 ? ' · $mins min' : ' · ${mins ~/ 60} h ${mins % 60} min';
      final exc = r.exceptions == 0 ? '' : ' · ${r.exceptions} exception${r.exceptions == 1 ? '' : 's'}';
      return 'Running · $name$age$exc';
    case RunPhase.stopped:
      return 'Stopped · $name';
    case RunPhase.failed:
      return 'Failed · ${r.error ?? name}';
  }
}

/// What the session is told while a run is up — the brief at Start, and
/// a host note the moment a run starts or stops.
String runBrief(RunState r) {
  if (!r.up) return 'Run bay: no app is running from the Mac. If a task needs the app running, say so — the user starts it from the phone (or run it yourself if the user asks).';
  return [
    'Run bay: the app under test is already running from the Mac on ${r.deviceName ?? r.device} (started by the host, not by you).',
    if (r.vmUri != null) 'VM service: ${r.vmUri}',
    if (r.dtdUri != null) 'Dart Tooling Daemon: ${r.dtdUri} — connect the Dart MCP server to it (its `dtd` tool) for runtime errors, the widget tree and hot reload.',
    'Do not start a second `flutter run`; the host owns the process. Edits under lib/ hot-reload on save when the user has reload-on-edit on; otherwise ask the user to reload from the phone, or use the MCP server\'s hot reload.',
  ].join('\n');
}

/// The last [keep] lines the app wrote, numbered from the first, so the
/// relay can write only what is new.
class RunLog {
  RunLog({this.keep = 2000});
  final int keep;
  final List<String> _lines = [];
  int _first = 0;

  /// The sequence of the next line — how many were ever added.
  int get seq => _first + _lines.length;
  int get length => _lines.length;
  List<String> get lines => List.unmodifiable(_lines);

  void add(String line) {
    _lines.add(line);
    if (_lines.length > keep) {
      final drop = _lines.length - keep;
      _lines.removeRange(0, drop);
      _first += drop;
    }
  }

  /// Lines from sequence [from] on, with the sequence of the first.
  (int, List<String>) since(int from) {
    final start = (from - _first).clamp(0, _lines.length);
    return (_first + start, _lines.sublist(start));
  }

  void clear() {
    _lines.clear();
    _first = 0;
  }
}
