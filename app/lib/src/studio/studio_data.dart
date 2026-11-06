import 'studio_plans.dart';

// Studio: what the game's autopilot is doing, read from the files its loop
// and reviewer write (`sivas-autopilot/`). Pure Dart — parsing only, no IO —
// so every shape here is pinned by test/studio_data_test.dart.
//
// The folder, as `run-lane.sh` and the reviewer write it:
//   lane-<x>/status        one line: "<yyyy-mm-dd hh:mm:ss>  <text>"
//   lane-<x>/history.log   one line per event, same stamp
//   lane-<x>/engine|model|effort
//   mail/to-<x>/*.md       a lane's inbox; mail/to-user/*.md the user's
//   review/digest.md       the reviewer's running digest ("## <stamp> — …" sections)
//   review/afk-decisions.md what it decided while the user was away
//   review/open-issues.md  one line per issue; "· closed" marks the done ones
//   control/PAUSE[-x], STOP[-x]

/// The loop's own stamp: local time, `yyyy-mm-dd hh:mm:ss`.
DateTime? parseStamp(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(s.trim());
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i) ?? '0');
  return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
}

/// `<stamp>  <text>` → (at, text). A line with no stamp keeps its text.
({DateTime? at, String text}) splitStamped(String line) {
  final m = RegExp(r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}(?::\d{2})?)\s+(.*)$').firstMatch(line.trim());
  if (m == null) return (at: null, text: line.trim());
  return (at: parseStamp(m.group(1)!), text: m.group(2)!.trim());
}

enum LaneState { running, waiting, paused, stopped, failed, notStarted, unknown }

/// What a lane's one-line `status` file says, read for a person.
class LaneStatus {
  const LaneStatus({required this.state, required this.text, this.at, this.step, this.engineLabel, this.machine});

  final LaneState state;

  /// The status in plain words, without the stamp and the `tail -f` hint.
  final String text;
  final DateTime? at;

  /// The running step's number, when it runs one.
  final String? step;

  /// "claude claude-opus-5-5/high" — what runs the step.
  final String? engineLabel;

  /// "Mac mini" / "Windows PC" when the status names one.
  final String? machine;

  static LaneStatus parse(String raw) {
    final line = raw.trim().split('\n').first;
    if (line.isEmpty) return const LaneStatus(state: LaneState.unknown, text: 'no status yet');
    final s = splitStamped(line);
    // "(tail -f /path/step-N.log)" is for the terminal, not for a person.
    var text = s.text.replaceAll(RegExp(r'\s*\(tail -f [^)]*\)'), '').trim();
    final run = RegExp(r'^running step (\S+) \(([^)]*)\)').firstMatch(text);
    if (run != null) {
      final inside = run.group(2)!;
      final parts = inside.split(',').map((e) => e.trim()).toList();
      return LaneStatus(
        state: LaneState.running,
        text: 'running step ${run.group(1)}',
        at: s.at,
        step: run.group(1),
        engineLabel: parts.first,
        machine: parts.length > 1 ? parts[1] : null,
      );
    }
    final lower = text.toLowerCase();
    final LaneState state;
    if (lower.startsWith('waiting')) {
      state = LaneState.waiting;
      text = text.replaceFirst(RegExp(r'^waiting:\s*'), 'waiting for ');
      // "waiting for new mail in /Users/…/mail/to-b (why)" → "waiting for new mail (why)"
      text = text.replaceAll(RegExp(r' in /\S+/mail/to-\w+'), '');
    } else if (lower.startsWith('paused')) {
      state = LaneState.paused;
    } else if (lower.startsWith('not started')) {
      state = LaneState.notStarted;
    } else if (lower.contains('stopped')) {
      state = LaneState.stopped;
    } else if (lower.contains('failed')) {
      state = LaneState.failed;
    } else {
      state = LaneState.unknown;
    }
    return LaneStatus(state: state, text: text, at: s.at);
  }
}

enum EventKind { started, done, waitForMail, waitFor, planComplete, failed, waiting, waitOver, push, paused, continued, stopped, loopStarted, mail, unity, other }

/// One line of a lane's `history.log`.
class LaneEvent {
  const LaneEvent({required this.kind, required this.text, this.at, this.step, this.summary});

  final EventKind kind;
  final DateTime? at;

  /// The line without its stamp.
  final String text;
  final String? step;

  /// For a verdict (DONE, WAIT-FOR-MAIL, FAILED …): what the step said.
  final String? summary;

  bool get isVerdict => const {EventKind.done, EventKind.waitForMail, EventKind.waitFor, EventKind.planComplete, EventKind.failed}.contains(kind);

  static LaneEvent parse(String line) {
    final s = splitStamped(line);
    final t = s.text;
    final started = RegExp(r'^step (\S+) started').firstMatch(t);
    if (started != null) return LaneEvent(kind: EventKind.started, at: s.at, text: t, step: started.group(1));
    final verdict = RegExp(r'^step (\S+)\s+(DONE|WAIT-FOR-MAIL|WAIT-FOR|PLAN-COMPLETE|FAILED)\b:?\s*(.*)$').firstMatch(t);
    if (verdict != null) {
      final kind = switch (verdict.group(2)) {
        'DONE' => EventKind.done,
        'WAIT-FOR-MAIL' => EventKind.waitForMail,
        'WAIT-FOR' => EventKind.waitFor,
        'PLAN-COMPLETE' => EventKind.planComplete,
        _ => EventKind.failed,
      };
      return LaneEvent(kind: kind, at: s.at, text: t, step: verdict.group(1), summary: (verdict.group(3) ?? '').trim());
    }
    final kind = switch (t) {
      _ when t.startsWith('waiting:') => EventKind.waiting,
      _ when t.startsWith('wait over:') => EventKind.waitOver,
      _ when t.startsWith('push:') => EventKind.push,
      _ when t.startsWith('paused') => EventKind.paused,
      _ when t.startsWith('continued') => EventKind.continued,
      _ when t.startsWith('stopped') => EventKind.stopped,
      _ when t.startsWith('loop started') => EventKind.loopStarted,
      _ when t.startsWith('delivered') || t.startsWith('relayed') => EventKind.mail,
      _ when t.contains('Unity') => EventKind.unity,
      _ => EventKind.other,
    };
    return LaneEvent(kind: kind, at: s.at, text: t);
  }
}

List<LaneEvent> parseHistory(String raw) => [
      for (final l in raw.split('\n'))
        if (l.trim().isNotEmpty) LaneEvent.parse(l),
    ];

/// One lane, everything the board shows about it.
class Lane {
  Lane({
    required this.id,
    required this.status,
    required this.history,
    this.engine,
    this.model,
    this.effort,
    this.inbox = 0,
    this.paused = false,
    this.stopping = false,
    this.hostMachine,
  });

  /// The machine `run-lane.sh` sends this lane's steps to, when not the
  /// loop's own Mac (see [laneHosts]).
  final String? hostMachine;

  /// "a", "b" …
  final String id;
  final LaneStatus status;

  /// Oldest first, as the file has it.
  final List<LaneEvent> history;
  final String? engine;
  final String? model;
  final String? effort;

  /// Unread mail waiting in `mail/to-<id>`.
  final int inbox;

  /// A PAUSE flag is set: the lane stops after its current step.
  final bool paused;

  /// A STOP flag is set: the loop ends after its current step.
  final bool stopping;

  String get name => 'Lane ${id.toUpperCase()}';

  /// Where it runs: what the status says, else the host `run-lane.sh`
  /// gives the lane ([hostMachine]), else the MacBook, the loop's own Mac.
  String get machine => status.machine ?? hostMachine ?? 'MacBook';

  /// "claude · opus-5-5 · high"
  String get engineLine => [
        if (engine != null && engine!.isNotEmpty) engine!,
        if (model != null && model!.isNotEmpty) model!.replaceFirst('claude-', ''),
        if (effort != null && effort!.isNotEmpty) effort!,
      ].join(' · ');

  /// The last step that ended DONE.
  LaneEvent? get lastDone {
    for (final e in history.reversed) {
      if (e.kind == EventKind.done) return e;
    }
    return null;
  }

  /// The last verdict of any kind.
  LaneEvent? get lastVerdict {
    for (final e in history.reversed) {
      if (e.isVerdict) return e;
    }
    return null;
  }

  /// Steps that ended DONE on [day].
  int doneOn(DateTime day) => history.where((e) => e.kind == EventKind.done && e.at != null && _sameDay(e.at!, day)).length;

  /// FAILED verdicts in a row at the end of the history (two pause the lane).
  int get failStreak {
    var n = 0;
    for (final e in history.reversed) {
      if (!e.isVerdict) continue;
      if (e.kind != EventKind.failed) break;
      n++;
    }
    return n;
  }

  /// A step runs past the loop's 4-hour timeout: the status is probably stale.
  bool staleAt(DateTime now) => status.state == LaneState.running && status.at != null && now.difference(status.at!) > const Duration(hours: 4, minutes: 15);
}

/// `run-lane.sh`'s repos per lane: `a) REPO=/Users/ren/…` and, for a lane on
/// another machine, its `WREPO=` there. `"$CTL"` (the autopilot folder) is skipped.
Map<String, List<String>> laneRepos(String runLane) {
  final out = <String, List<String>>{};
  for (final m in RegExp(r'^\s*([a-z])\)\s(.*(?:\n\s+[A-Z]+=.*)*)', multiLine: true).allMatches(runLane)) {
    final body = m.group(2)!;
    final repos = [
      for (final r in RegExp(r'\b(?:REPO|WREPO)=([^;\s]+)').allMatches(body))
        r.group(1)!.replaceAll(RegExp(r'''^['"]|['"]$'''), ''),
    ].where((r) => !r.contains(r'$')).toList();
    out[m.group(1)!] = repos;
  }
  return out;
}

/// The step list a lane's prompt names: `production/autopilot/lane-a-steps.md` …
String? stepsFileIn(String prompt) => RegExp(r'[A-Za-z0-9_./-]*steps\.md').firstMatch(prompt)?.group(0);

/// "ROOMLAB-1B: the window …" → "ROOMLAB-1B".
String? leadingId(String? summary) {
  if (summary == null) return null;
  final m = RegExp(r'^([A-Za-z0-9][A-Za-z0-9._-]*)\s*[:(—]').firstMatch(summary.trim());
  return m?.group(1);
}

/// `run-lane.sh`'s lane table: `c) …; WHOST=sivas-win; …` → {c: Windows PC}.
/// A lane without a WHOST runs on the loop's own Mac.
Map<String, String> laneHosts(String runLane) {
  const names = {'sivas-win': 'Windows PC', 'mac-mini': 'Mac mini'};
  return {
    for (final m in RegExp(r'^\s*([a-z])\)\s.*?\bWHOST=([^;\s]+)', multiLine: true).allMatches(runLane)) m.group(1)!: names[m.group(2)!] ?? m.group(2)!,
  };
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// One file in `mail/to-user` (or a lane's inbox).
class Mail {
  const Mail({required this.file, required this.title, required this.body, this.at});

  /// The file name: `YYYYMMDD-HHMM-slug.md`.
  final String file;
  final DateTime? at;
  final String title;
  final String body;

  static DateTime? stampOf(String file) {
    final m = RegExp(r'(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})?').firstMatch(file);
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i) ?? '0');
    return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
  }

  static Mail parse(String file, String body) {
    final heading = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(body);
    var slug = file.replaceAll(RegExp(r'\.md$'), '').replaceFirst(RegExp(r'^(from-\w+-)?\d{8}-\d{4,6}-'), '');
    slug = slug.replaceAll('-', ' ');
    return Mail(file: file, at: stampOf(file), title: heading?.group(1)!.trim() ?? slug, body: body);
  }
}

/// A line of `review/open-issues.md` that is not closed.
class OpenIssue {
  const OpenIssue({required this.text, this.lane});
  final String text;

  /// "A", "B", "F/A" … when the line names one.
  final String? lane;

  static List<OpenIssue> parseAll(String raw) {
    final out = <OpenIssue>[];
    for (final l in raw.split('\n')) {
      if (!l.startsWith('- ')) continue;
      if (RegExp(r'·\s*closed\b').hasMatch(l) || RegExp(r'\bclosed \d{4}-\d{2}-\d{2}').hasMatch(l)) continue;
      final body = l.substring(2).trim();
      final lead = RegExp(r'^([A-DF](?:/[A-DF])*)\s+(?:·\s+)?').firstMatch(body);
      final mid = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2} · ([A-DF](?:/[A-DF])*) · ').firstMatch(body);
      out.add(OpenIssue(text: body, lane: lead?.group(1) ?? mid?.group(1)));
    }
    return out;
  }
}

/// One `## <stamp> — <title>` section of a reviewer file.
class ReviewSection {
  const ReviewSection({required this.title, required this.body, this.at});
  final String title;
  final String body;
  final DateTime? at;

  static List<ReviewSection> parseAll(String raw) {
    final out = <ReviewSection>[];
    String? title;
    final buf = StringBuffer();
    void flush() {
      if (title != null) {
        final m = RegExp(r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s*[—·-]*\s*(.*)$').firstMatch(title);
        out.add(ReviewSection(title: m?.group(2)?.trim().isNotEmpty == true ? m!.group(2)!.trim() : title, at: m == null ? null : parseStamp(m.group(1)!), body: buf.toString().trim()));
      }
      buf.clear();
    }

    for (final l in raw.split('\n')) {
      if (l.startsWith('## ')) {
        flush();
        title = l.substring(3).trim();
      } else if (title != null) {
        buf.writeln(l);
      }
    }
    flush();
    return out;
  }

  /// The bullets under a `**<label>**` line (e.g. "Waiting for the user"),
  /// up to the next bold line or heading.
  List<String> bulletsUnder(String label) {
    final lines = body.split('\n');
    final start = lines.indexWhere((l) => l.trim().toLowerCase().startsWith('**${label.toLowerCase()}'));
    if (start < 0) return const [];
    final out = <String>[];
    for (final l in lines.skip(start + 1)) {
      final t = l.trim();
      if (t.startsWith('**') || t.startsWith('#')) break;
      if (t.startsWith('- ')) {
        out.add(t.substring(2).trim());
      } else if (t.isNotEmpty && out.isNotEmpty && l.startsWith('  ')) {
        out[out.length - 1] = '${out.last} $t';
      }
    }
    return out;
  }

  /// The `### hh:mm review` notes inside this section, newest last.
  List<ReviewSection> get subsections {
    final out = <ReviewSection>[];
    String? title;
    final buf = StringBuffer();
    void flush() {
      if (title != null) out.add(ReviewSection(title: title, body: buf.toString().trim()));
      buf.clear();
    }

    for (final l in body.split('\n')) {
      if (l.startsWith('### ')) {
        flush();
        title = l.substring(4).trim();
      } else if (title != null) {
        buf.writeln(l);
      }
    }
    flush();
    return out;
  }
}

/// Everything the Studio shows, at one moment.
class StudioSnapshot {
  const StudioSnapshot({
    required this.lanes,
    required this.userMail,
    required this.openIssues,
    required this.decisions,
    this.digest,
    this.mode,
    this.lastReview,
    this.readAt,
    this.tracks = const {},
    this.roadmap = const [],
  });

  /// Each lane's step track, by lane id.
  final Map<String, LaneTrack> tracks;

  /// The game's milestone ladder with its items.
  final List<Milestone> roadmap;

  final List<Lane> lanes;

  /// Newest first.
  final List<Mail> userMail;
  final List<OpenIssue> openIssues;

  /// The reviewer's decisions, newest first.
  final List<ReviewSection> decisions;

  /// The newest digest section — the reviewer's own "where things stand".
  final ReviewSection? digest;

  /// "afk" / "watch" — the reviewer's mode.
  final String? mode;
  final DateTime? lastReview;

  /// When this was read from disk.
  final DateTime? readAt;

  /// What waits on the user, as the reviewer listed it last.
  List<String> get waitingForUser => digest?.bulletsUnder('Waiting for the user') ?? const [];

  static const empty = StudioSnapshot(lanes: [], userMail: [], openIssues: [], decisions: []);
}

/// One readable document of the game repo, cut at its `##` headings so a
/// 300 KB plan opens one part at a time.
class DocPart {
  const DocPart({required this.title, required this.body, required this.level});
  final String title;
  final String body;

  /// 1 for the text before the first `##`, 2 for a `##` part.
  final int level;

  static List<DocPart> split(String raw, {String intro = 'Overview'}) {
    final out = <DocPart>[];
    var title = intro;
    var level = 1;
    final buf = StringBuffer();
    var inFence = false;
    void flush() {
      final body = buf.toString().trim();
      if (body.isNotEmpty || level == 2) out.add(DocPart(title: title, body: body, level: level));
      buf.clear();
    }

    for (final l in raw.split('\n')) {
      if (l.trimLeft().startsWith('```')) inFence = !inFence;
      if (!inFence && l.startsWith('## ')) {
        flush();
        title = l.substring(3).trim();
        level = 2;
      } else {
        buf.writeln(l);
      }
    }
    flush();
    return out;
  }
}
