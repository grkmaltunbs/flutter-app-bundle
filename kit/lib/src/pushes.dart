/// Rich pushes — the pure half: what a lock screen can decide on, and
/// when a phone would rather not be woken.
///
/// The host (`app/lib/src/host/push_sender.dart`) turns a [Notice] into
/// one FCM message a phone; this file decides the words a push carries
/// beyond its first line — the changed lines of an edit, the outline of
/// a plan, the error line as it was — and the quiet hours: a window per
/// phone, kept on its `devices/{token}` row, in which "Turn ended" and a
/// problem that is not a dead session wait on the Mac and go out as one
/// digest at the window's end. Asks never wait.
library;

import 'bridge.dart';

/// The changed lines of a unified diff — `+` and `-` lines, not the file
/// headers — at most [lines] of them, each clipped to [width], so an edit
/// ask's push shows what changes rather than only where.
List<String> diffPreview(String diff, {int lines = 3, int width = 96}) {
  final out = <String>[];
  for (final raw in diff.split('\n')) {
    if (out.length >= lines) break;
    if (raw.startsWith('+++') || raw.startsWith('---')) continue;
    if (!(raw.startsWith('+') || raw.startsWith('-'))) continue;
    final body = raw.substring(1).trimRight();
    if (body.trim().isEmpty) continue;
    out.add(_clip('${raw[0]} ${body.trimLeft()}', width));
  }
  return out;
}

/// A plan's shape for a lock screen: its first heading (the first
/// non-empty line when it has none) and how many steps it lists —
/// numbered items first, else bullets, else the headings under the first.
({String heading, int steps}) planOutline(String plan) {
  final lines = plan.split('\n');
  String? heading;
  var numbered = 0, subheads = 0, bullets = 0;
  var seenHeading = false;
  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) continue;
    final h = RegExp(r'^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$').firstMatch(line);
    if (h != null) {
      if (!seenHeading) {
        heading ??= h.group(1)!.trim();
        seenHeading = true;
      } else {
        subheads++;
      }
      continue;
    }
    heading ??= line.trim();
    if (RegExp(r'^\s*\d+[.)]\s+').hasMatch(line)) {
      numbered++;
    } else if (RegExp(r'^\s*[-*•]\s+').hasMatch(line)) {
      bullets++;
    }
  }
  final steps = numbered > 0 ? numbered : (bullets > 0 ? bullets : subheads);
  return (heading: _clip(heading ?? '', 120), steps: steps);
}

/// The one line under "Plan ready": the heading and the count.
String planPreview(String plan) {
  final o = planOutline(plan);
  if (o.heading.isEmpty) return '';
  return o.steps == 0 ? o.heading : '${o.heading} · ${o.steps} step${o.steps == 1 ? '' : 's'}';
}

/// The first line of an error, as it was — a lock screen reads the
/// error's own words, not a summary of them.
String errorLine(String error, {int width = 480}) {
  for (final line in error.split('\n')) {
    if (line.trim().isNotEmpty) return _clip(line.trim(), width);
  }
  return error.trim();
}

/// A phone's quiet hours: a daily window in the phone's own clock, kept
/// as minutes from midnight with the phone's UTC offset at the time it
/// was set (`devices/{token}.quiet {on, start, end, offset}` — `start`
/// and `end` as "HH:MM"). A window may cross midnight (23:00–08:00).
class QuietWindow {
  const QuietWindow({required this.on, required this.start, required this.end, required this.offset});

  /// The default window a phone offers before the user moves it.
  static const defaultStart = 23 * 60;
  static const defaultEnd = 8 * 60;

  /// Null when [m] is not a window — nothing set on the row.
  static QuietWindow? fromMap(Object? m) {
    if (m is! Map) return null;
    final start = parseHm(m['start']);
    final end = parseHm(m['end']);
    if (start == null || end == null) return null;
    final offset = (m['offset'] as num?)?.toInt() ?? 0;
    return QuietWindow(on: m['on'] == true, start: start, end: end, offset: offset);
  }

  final bool on;

  /// Minutes from midnight, phone time.
  final int start;
  final int end;

  /// The phone's clock against UTC, in minutes east.
  final int offset;

  Map<String, Object?> toMap() => {'on': on, 'start': hm(start), 'end': hm(end), 'offset': offset};

  QuietWindow copyWith({bool? on, int? start, int? end, int? offset}) => QuietWindow(on: on ?? this.on, start: start ?? this.start, end: end ?? this.end, offset: offset ?? this.offset);

  /// "23:00–08:00".
  String get label => '${hm(start)}–${hm(end)}';

  /// The phone's clock at [utc], as minutes into its day.
  int _minuteOf(DateTime utc) {
    final local = utc.toUtc().add(Duration(minutes: offset));
    return local.hour * 60 + local.minute;
  }

  /// Inside the window at [utc] — and the window is on. A window whose
  /// start and end agree is a whole day.
  bool contains(DateTime utc) {
    if (!on) return false;
    final m = _minuteOf(utc);
    if (start == end) return true;
    return start < end ? (m >= start && m < end) : (m >= start || m < end);
  }

  /// When the window that holds [utc] ends — or, outside it, [utc]
  /// itself: nothing to wait for.
  DateTime endAfter(DateTime utc) {
    final u = utc.toUtc();
    if (!contains(u)) return u;
    final local = u.add(Duration(minutes: offset));
    final midnight = DateTime.utc(local.year, local.month, local.day);
    var endLocal = midnight.add(Duration(minutes: end));
    if (!endLocal.isAfter(local)) endLocal = endLocal.add(const Duration(days: 1));
    return endLocal.subtract(Duration(minutes: offset));
  }

  /// "HH:MM" → minutes, or null.
  static int? parseHm(Object? v) {
    if (v is num) return v.toInt().clamp(0, 24 * 60 - 1);
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.toString().trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!), mm = int.parse(m.group(2)!);
    if (h > 23 || mm > 59) return null;
    return h * 60 + mm;
  }

  static String hm(int minutes) {
    final m = minutes.clamp(0, 24 * 60 - 1);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }
}

/// What waits through quiet hours: a turn that ended, Claude's own line,
/// and a problem that is not a dead session. An ask, a step that flipped,
/// a build, and a session that died go out at once.
bool heldInQuiet(Notice n) => switch (n.kind) {
      NoticeKind.done || NoticeKind.note => true,
      NoticeKind.problem => !n.urgent,
      _ => false,
    };

/// The one push at the window's end for what waited: how many turns
/// ended and how many problems, then the last turn's first line. On the
/// problems channel when a problem is among them.
Notice digestNotice({required String project, required List<Notice> held}) {
  final turns = held.where((n) => n.kind != NoticeKind.problem).length;
  final problems = held.length - turns;
  final counts = [
    if (turns > 0) '$turns turn${turns == 1 ? '' : 's'} ended',
    if (problems > 0) '$problems problem${problems == 1 ? '' : 's'}',
  ].join(' · ');
  final last = held.isEmpty ? '' : held.last.body.split('\n').first.trim();
  final body = [counts, if (last.isNotEmpty) _clip(last, 160)].join('\n');
  final urgentTail = held.lastWhere((n) => n.kind == NoticeKind.problem, orElse: () => held.last);
  return Notice(
    kind: problems > 0 ? NoticeKind.problem : NoticeKind.done,
    title: 'While you slept · $project',
    body: body,
    extra: {...urgentTail.extra, 'digest': '${held.length}'},
  );
}

String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1)}…';
