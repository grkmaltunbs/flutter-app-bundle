/// Claude Code hook events, spooled to disk for the host app.
///
/// A hook is a command Claude Code runs on `SessionStart`, `UserPromptSubmit`,
/// `PostToolUse`, `Stop`, `Notification`… with a JSON payload on stdin.
/// `kit hook` writes that payload as one file under
/// `~/.flutter_kit/events/<project slug>/`, named so that lexical order is
/// arrival order. The host watches the directory; the phone gets a mirror.
/// Nothing here needs the app to be running — a hook that fires while the
/// app is closed leaves a file, and the app reads it on the next start.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Claude Code's own project slug: every character that is not a letter or a
/// digit becomes `-`, so `/Users/ren/StudioProjects/nahmatik` is
/// `-Users-ren-StudioProjects-nahmatik` — the same folder name it uses under
/// `~/.claude/projects/`.
String claudeProjectSlug(String dir) => dir.replaceAll(RegExp('[^A-Za-z0-9]'), '-');

String kitHome({String? home}) {
  if (home != null) return home;
  final env = Platform.environment;
  final userHome = env['HOME'] ?? env['USERPROFILE'] ?? '.';
  return env['FLUTTER_KIT_HOME'] ?? p.join(userHome, '.flutter_kit');
}

String eventsDirFor(String projectDir, {String? home}) => p.join(kitHome(home: home), 'events', claudeProjectSlug(projectDir));

/// One spooled hook event, as the host reads it.
class HookEvent {
  HookEvent({required this.at, required this.name, required this.cwd, required this.sessionId, required this.payload, this.file});

  factory HookEvent.fromJson(Map<String, Object?> m, {String? file}) => HookEvent(
        at: DateTime.tryParse(m['at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        name: (m['hook_event_name'] ?? m['name'] ?? '').toString(),
        cwd: (m['cwd'] ?? '').toString(),
        sessionId: (m['session_id'] ?? '').toString(),
        payload: m,
        file: file,
      );

  final DateTime at;
  final String name;
  final String cwd;
  final String sessionId;
  final Map<String, Object?> payload;
  final String? file;

  String get toolName => (payload['tool_name'] ?? '').toString();

  /// A one-line, human reading of the event — what the "Now" strip shows.
  String get summary {
    switch (name) {
      case 'SessionStart':
        return 'Session started';
      case 'UserPromptSubmit':
        final prompt = (payload['prompt'] ?? '').toString().trim();
        return prompt.isEmpty ? 'You sent a prompt' : 'You: ${_clip(prompt, 120)}';
      case 'PreToolUse':
      case 'PostToolUse':
        final input = payload['tool_input'];
        final tool = toolName;
        String detail = '';
        if (input is Map) {
          detail = (input['command'] ?? input['file_path'] ?? input['pattern'] ?? input['description'] ?? input['prompt'] ?? '').toString();
        }
        return detail.isEmpty ? tool : '$tool · ${_clip(detail.replaceAll('\n', ' '), 120)}';
      case 'Stop':
        return 'Claude finished a turn';
      case 'SubagentStop':
        return 'A subagent finished';
      case 'Notification':
        return _clip((payload['message'] ?? 'Claude needs you').toString(), 160);
      case 'SessionEnd':
        return 'Session ended';
      case 'Notify':
        return _clip((payload['message'] ?? '').toString().trim(), 240);
      default:
        return name.isEmpty ? 'Event' : name;
    }
  }

  /// True when Claude is waiting on the person rather than working.
  bool get needsYou => name == 'Notification' || name == 'Stop';

  Map<String, Object?> toJson() => {'at': at.toIso8601String(), 'name': name, 'cwd': cwd, 'session_id': sessionId, 'tool': toolName, 'summary': summary, 'needsYou': needsYou};
}

String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1)}…';

/// Writes one hook payload to the spool. Returns the file written.
File spoolHookEvent(Map<String, Object?> payload, {DateTime? now, String? home}) {
  final at = now ?? DateTime.now();
  final cwd = (payload['cwd'] ?? Directory.current.path).toString();
  final dir = Directory(eventsDirFor(cwd, home: home))..createSync(recursive: true);
  final stamped = {...payload, 'at': at.toUtc().toIso8601String()};
  // Millis + pid: lexical order is arrival order, and two hooks in the same
  // millisecond (a PreToolUse and its PostToolUse) still get distinct names.
  final name = '${at.millisecondsSinceEpoch.toString().padLeft(15, '0')}-${pid.toString().padLeft(7, '0')}-${(payload['hook_event_name'] ?? 'event').toString()}.json';
  final f = File(p.join(dir.path, name));
  f.writeAsStringSync(jsonEncode(stamped));
  return f;
}

/// Reads every spooled event for [projectDir], oldest first.
List<HookEvent> readSpool(String projectDir, {String? home}) {
  final dir = Directory(eventsDirFor(projectDir, home: home));
  if (!dir.existsSync()) return const [];
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()..sort((a, b) => a.path.compareTo(b.path));
  final out = <HookEvent>[];
  for (final f in files) {
    try {
      final m = jsonDecode(f.readAsStringSync());
      if (m is Map) out.add(HookEvent.fromJson({for (final e in m.entries) e.key.toString(): e.value}, file: f.path));
    } on FormatException {
      // A half-written file — the writer is not done; the next scan gets it.
    }
  }
  return out;
}

/// Deletes spooled files older than [keep] entries, oldest first.
void pruneSpool(String projectDir, {int keep = 500, String? home}) {
  final dir = Directory(eventsDirFor(projectDir, home: home));
  if (!dir.existsSync()) return;
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()..sort((a, b) => a.path.compareTo(b.path));
  for (var i = 0; i < files.length - keep; i++) {
    try {
      files[i].deleteSync();
    } on FileSystemException {
      // Already gone — the host and a hook raced; nothing to do.
    }
  }
}
