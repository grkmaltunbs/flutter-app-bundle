// The two plans the Studio draws: each lane's step list (checkbox markdown,
// "the first unchecked item is next") and the game's roadmap
// (`production/production-plan.md`, milestone tables). Pure Dart; shapes are
// pinned by test/studio_plans_test.dart from the real files of 2026-11-06.

/// A link to a step: `lane-b/COLLAPSE-PIT-LINER`, `b/674`, or a bare id in
/// the same lane ([lane] null). [run] is set instead of [id] for a mention
/// like "lane C 468", which names a run, not an id.
class DepRef {
  const DepRef({this.lane, this.id, this.run});
  final String? lane;
  final String? id;
  final String? run;

  @override
  String toString() => [if (lane != null) 'lane-$lane', id ?? 'run $run'].join('/');

  @override
  bool operator ==(Object other) => other is DepRef && other.lane == lane && other.id == id && other.run == run;
  @override
  int get hashCode => Object.hash(lane, id, run);
}

/// The `after:` tag of a step line: `after: lane-b/X, a/Y, Z` — what must be
/// ticked before the step starts. Stops at `)`, `]`, `;`, ` — ` or the end.
List<DepRef> parseAfterTag(String line) {
  final m = RegExp(r'\bafter:\s*([^)\];\n]+?)(?=\s+[—–]\s|[)\];]|$)').firstMatch(line);
  if (m == null) return const [];
  return [
    for (final raw in m.group(1)!.split(','))
      if (raw.trim().isNotEmpty)
        () {
          final r = raw.trim().replaceAll('`', '');
          final at = r.indexOf('/');
          if (at < 0) return DepRef(id: r);
          final lane = r.substring(0, at).toLowerCase().replaceFirst('lane-', '').replaceFirst('lane', '');
          return DepRef(lane: lane, id: r.substring(at + 1));
        }(),
  ];
}

/// Mentions of another lane's run in a step's text — "lane C 468",
/// "lane B run 674": a hint that two steps belong together, offered as a
/// suggested link, never drawn as a dependency on its own.
List<DepRef> parseLaneMentions(String text, {String? ownLane}) {
  final out = <DepRef>{};
  for (final m in RegExp(r'\blane ([A-Da-d])(?: run)? ?(\d{2,5})\b').allMatches(text)) {
    final lane = m.group(1)!.toLowerCase();
    if (lane == ownLane) continue;
    out.add(DepRef(lane: lane, run: m.group(2)));
  }
  return out.toList();
}

/// Roadmap ids a text names: M3.41, SR.6 …
List<String> parseRoadmapIds(String text) => {for (final m in RegExp(r'\b(M\d+\.\d+[A-Z]?|SR\.\d+)\b').allMatches(text)) m.group(1)!}.toList();

/// One `- [ ]` / `- [x]` item of a lane's step list.
class StepItem {
  const StepItem({required this.id, required this.title, required this.done, required this.text, this.section, this.run});

  /// The first token: `CARGO-DECK-FLOOR`, `C01`, `ROOMLAB-1C` …
  final String id;

  /// A short line for a bubble's caption and a list row.
  final String title;
  final bool done;

  /// The item with its indented sub-bullets, as markdown.
  final String text;

  /// The `##` heading it sits under.
  final String? section;

  /// The autopilot run that finished it, when the line says (`run 1052`).
  final String? run;

  /// What must be ticked first — the line's `after:` tag.
  List<DepRef> get after => parseAfterTag(text.split('\n').first);

  /// The roadmap items this step names (in its line or its sub-bullets).
  List<String> get roadmapIds => parseRoadmapIds(text);

  /// An open item the list says is on hold or waiting on someone.
  bool get held => !done && RegExp(r'\b(HOLD|HELD|held|on hold|blocked|waits? (on|for)|gated)\b').hasMatch(text.split('\n').first);
}

/// Parses a lane's step list. Only top-level items count; indented lines
/// belong to the item above them.
List<StepItem> parseStepList(String raw) {
  final out = <StepItem>[];
  String? section;
  String? head;
  bool? done;
  final buf = StringBuffer();
  void flush() {
    final h = head;
    if (h != null) out.add(_item(h, done!, buf.toString().trimRight(), section));
    head = null;
    buf.clear();
  }

  for (final l in raw.split('\n')) {
    final m = RegExp(r'^- \[([ xX])\]\s+(.*)$').firstMatch(l);
    if (m != null) {
      flush();
      done = m.group(1) != ' ';
      head = m.group(2)!;
      buf.writeln(head);
      continue;
    }
    if (l.startsWith('## ')) {
      flush();
      section = l.substring(3).trim();
      continue;
    }
    if (head != null) {
      if (l.startsWith(' ') || l.startsWith('\t') || l.trim().isEmpty) {
        buf.writeln(l);
      } else {
        flush();
      }
    }
  }
  flush();
  return out;
}

StepItem _item(String head, bool done, String text, String? section) {
  // Lane C's copy writes "step 476: …" — the number is the id and the run.
  // Lane B's older items write "run 657: …" the same way.
  final stepNo = RegExp(r'^(?:[Ss]tep|[Rr]un) (\d+)[a-z]?:?\s*').firstMatch(head);
  if (stepNo != null) {
    var title = head.substring(stepNo.end).replaceAll('**', '').replaceAll('`', '');
    if (title.length > 140) title = '${title.substring(0, 137)}…';
    return StepItem(id: stepNo.group(1)!, title: title, done: done, text: text, section: section, run: stepNo.group(1));
  }
  final token = head.split(RegExp(r'\s+')).first;
  final first = token.replaceAll('*', '').replaceAll(RegExp(r'[:.,]+$'), '');
  final bold = RegExp(r'\*\*(.+?)\*\*').firstMatch(head);
  var rest = head.substring(token.length).trim();
  String title;
  // Lane C names a step in bold right after its id (`C01 **Setup — …**`); bold
  // further along is emphasis, not a title.
  if (bold != null && rest.startsWith('**')) {
    title = bold.group(1)!.trim();
  } else {
    // "(run 1052): the thing" / ": the thing" → "the thing"
    rest = rest.replaceFirst(RegExp(r'^\([^)]*\)\s*'), '').replaceFirst(RegExp(r'^[:—-]\s*'), '');
    title = rest.replaceAll('**', '').replaceAll('`', '');
  }
  if (title.length > 140) title = '${title.substring(0, 137)}…';
  final run = RegExp(r'\bruns? ?(\d{2,5})').firstMatch(head)?.group(1);
  return StepItem(id: first.isEmpty ? '?' : first, title: title.isEmpty ? first : title, done: done, text: text, section: section, run: run);
}

/// A lane's track: what it finished, what it is on, what comes next.
class LaneTrack {
  const LaneTrack({required this.done, required this.next, this.current, this.source});

  /// Finished items, in list order (the last is the most recent tick).
  final List<StepItem> done;

  /// The item the running step works on — the first unchecked one, when the
  /// lane runs; null while it waits.
  final StepItem? current;

  /// Unchecked items after [current], in order.
  final List<StepItem> next;

  /// The file it was read from.
  final String? source;

  int get total => done.length + next.length + (current == null ? 0 : 1);

  /// [lastDoneId] is the id the lane's last DONE verdict starts with
  /// ("ROOMLAB-1B: …"): the running step works on the first open item after
  /// it in the list, since held items stay unchecked above. Without it, or
  /// when it is not in the list, the first open item that is not held.
  static LaneTrack from(List<StepItem> items, {required bool running, String? lastDoneId, String? source}) {
    final done = items.where((i) => i.done).toList();
    final open = items.where((i) => !i.done).toList();
    if (!running || open.isEmpty) return LaneTrack(done: done, next: open, source: source);
    StepItem? current;
    final at = lastDoneId == null ? -1 : items.indexWhere((i) => i.id == lastDoneId);
    if (at >= 0) {
      for (final i in items.skip(at + 1)) {
        if (!i.done) {
          current = i;
          break;
        }
      }
    }
    current ??= open.firstWhere((i) => !i.held, orElse: () => open.first);
    return LaneTrack(done: done, current: current, next: [for (final i in open) if (!identical(i, current)) i], source: source);
  }

  static const empty = LaneTrack(done: [], next: []);
}

// --- the roadmap ----------------------------------------------------------------

/// [built]: the work is in but its runtime check is still owed.
enum ItemStatus { done, built, inProgress, notStarted, other }

class RoadmapItem {
  const RoadmapItem({required this.id, required this.task, required this.status, required this.statusText, required this.milestone, this.size, this.owner, this.summary = ''});
  final String id;
  final String task;
  final ItemStatus status;

  /// The Status cell (open work) or the date it was done.
  final String statusText;

  /// `M3`, `M4`, `R` …
  final String milestone;
  final String? size;
  final String? owner;
  final String summary;

  /// Items this one waits on, as its own text says ("after M3.21", "needs M2.36").
  List<String> get after => {
        for (final m in RegExp(r'\b(?:after|needs|waits (?:on|for)|blocked by|depends on|gated on)\s+(M\d+\.\d+[A-Z]?|SR\.\d+)\b', caseSensitive: false).allMatches('$statusText $summary'))
          if (m.group(1) != id) m.group(1)!,
      }.toList();
}

class Milestone {
  const Milestone({required this.key, required this.name, this.goal = '', this.ladderStatus = '', this.items = const []});

  /// `M0` … `M4`, `R`.
  final String key;
  final String name;
  final String goal;

  /// The ladder table's Status cell.
  final String ladderStatus;
  final List<RoadmapItem> items;

  int get doneCount => items.where((i) => i.status == ItemStatus.done).length;
  int get inProgressCount => items.where((i) => i.status == ItemStatus.inProgress).length;
}

String _cell(String s) => s.replaceAll(RegExp(r'\*\*|\*|`'), '').trim();

List<String> _cells(String row) {
  final t = row.trim();
  final inner = t.substring(1, t.endsWith('|') ? t.length - 1 : t.length);
  return inner.split('|').map((c) => c.trim()).toList();
}

ItemStatus _status(String s) {
  final l = s.toLowerCase();
  if (l.startsWith('in progress') || l.contains('in progress')) return ItemStatus.inProgress;
  if (l.startsWith('not started')) return ItemStatus.notStarted;
  if (l.startsWith('done') || l.startsWith('closed')) return ItemStatus.done;
  if (l.startsWith('built')) return ItemStatus.built;
  return ItemStatus.other;
}

/// `### M3 — Alpha …` → M3; `### Release — …` → R.
String? _milestoneKey(String heading) {
  final m = RegExp(r'^(M\d+)\b').firstMatch(heading);
  if (m != null) return m.group(1);
  if (heading.startsWith('Release')) return 'R';
  return null;
}

/// The ladder, with every Open work and Done row under its milestone.
List<Milestone> parseRoadmap(String raw) {
  final lines = raw.split('\n');
  final ladder = <String, ({String name, String goal, String status})>{};
  final items = <String, List<RoadmapItem>>{};
  String? h2;
  String? key;
  List<String>? header;
  for (final l in lines) {
    if (l.startsWith('## ')) {
      h2 = l.substring(3).trim();
      key = null;
      header = null;
      continue;
    }
    if (l.startsWith('### ')) {
      key = _milestoneKey(l.substring(4).trim());
      header = null;
      continue;
    }
    if (!l.trimLeft().startsWith('|')) {
      header = null;
      continue;
    }
    final cells = _cells(l);
    if (cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c))) continue;
    if (header == null) {
      header = cells.map((c) => c.toLowerCase()).toList();
      continue;
    }
    if (h2 == 'Milestone ladder' && cells.length >= 5) {
      ladder[_cell(cells[0])] = (name: _cell(cells[1]).replaceAll(RegExp(r'\s*\(v[\d.]+\)'), ''), goal: _cell(cells[2]), status: _cell(cells[4]));
      continue;
    }
    if (key == null || (h2 != 'Open work' && h2 != 'Done')) continue;
    int col(String name) => header!.indexWhere((h) => h.startsWith(name));
    final iId = col('id'), iTask = col('task'), iSize = col('size'), iOwner = col('owner'), iStatus = col('status'), iDone = col('done'), iSum = col('summary');
    if (iId < 0 || iTask < 0 || cells.length <= iTask) continue;
    String at(int i) => i >= 0 && i < cells.length ? cells[i] : '';
    final isDone = h2 == 'Done';
    final statusText = _cell(isDone ? at(iDone) : at(iStatus));
    items.putIfAbsent(key, () => []).add(RoadmapItem(
          id: _cell(at(iId)),
          task: _cell(at(iTask)).replaceAll(RegExp(r'\s*\((was|code keeps)[^)]*\)'), ''),
          status: isDone ? ItemStatus.done : _status(statusText),
          statusText: statusText,
          milestone: key,
          size: _cell(at(iSize)).isEmpty ? null : _cell(at(iSize)),
          owner: _cell(at(iOwner)).isEmpty ? null : _cell(at(iOwner)),
          summary: at(iSum),
        ));
  }
  final keys = {...ladder.keys, ...items.keys}.toList()..sort((a, b) => _order(a).compareTo(_order(b)));
  return [
    for (final k in keys)
      Milestone(
        key: k,
        name: ladder[k]?.name ?? k,
        goal: ladder[k]?.goal ?? '',
        ladderStatus: ladder[k]?.status ?? '',
        items: items[k] ?? const [],
      ),
  ];
}

int _order(String key) => key == 'R' ? 999 : int.tryParse(key.substring(1)) ?? 500;
