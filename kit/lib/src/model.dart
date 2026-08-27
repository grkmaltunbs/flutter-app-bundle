/// The plan model: a manifest, steps Claude works, items the human works,
/// and the edges between them.
///
/// Two rules shape everything here:
///
/// * **An edge lives on the side that changes most.** Items are created and
///   closed far more often than steps, so the item carries `blocks:` and a
///   step's human gate is *computed* from the items that name it. Nothing is
///   stored twice.
/// * **Stored state is minimal; display state is derived.** A step stores
///   `pending | active | done`. Whether it is blocked, ready, or code-complete
///   is worked out in `graph.dart` from dependencies, gates and items — so it
///   cannot go stale in a file.
library;

/// The built-in vocabulary for what an item needs from the human.
///
/// A project can extend this from `kit.yaml` (`needs:`), but these eight
/// cover every entry a Flutter + Firebase project has produced so far and the
/// board groups sittings by them.
const Map<String, NeedKind> builtinNeeds = {
  'console': NeedKind('console', 'A console',
      'Firebase, App Store Connect, Play, RevenueCat, a registrar — somewhere only your account can log in.'),
  'device': NeedKind('device', 'A real phone',
      'A physical device, or a second handset — pushes, links, cameras, sandbox purchases.'),
  'read': NeedKind('read', 'Your eyes on copy',
      'Text in a language Claude drafted and nobody has read out loud.'),
  'look': NeedKind('look', 'Your eyes on a screen',
      'A visual sign-off that a test cannot give.'),
  'decision': NeedKind('decision', 'A call only you can make',
      'A product, privacy or money decision. Claude recommends; you decide.'),
  'store': NeedKind('store', 'Store accounts',
      'Listings, TestFlight, review submissions, data-safety forms.'),
  'money': NeedKind('money', 'Money',
      'A purchase, a domain, a paid plan, a card on file.'),
  'secret': NeedKind('secret', 'Keys and credentials',
      'API keys, certificates, tokens — things that must never be in the repo.'),
  'know': NeedKind('know', 'Worth knowing',
      'A finding to read once and acknowledge. Nothing to do unless it changes your mind.'),
};

class NeedKind {
  const NeedKind(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;

  Map<String, Object?> toMap() => {'label': label, 'description': description};
}

/// `plan/kit.yaml` — the project manifest. Everything that used to be
/// hard-coded into a project's `/step` lives here so the commands stay
/// generic.
class Manifest {
  Manifest({
    required this.projectName,
    this.projectSlug,
    this.firebaseProject,
    this.qa = const {},
    this.platforms = const ['ios', 'android'],
    this.releaseStep,
    this.boardTitle,
    this.boardArtifactUrl,
    this.boardOutput = 'docs/board/launch_board.html',
    this.boardFonts = const {},
    this.boardColors = const {},
    this.planMarkdown = 'PROJECT_PLAN.md',
    this.extraNeeds = const {},
    this.journal,
  });

  factory Manifest.fromMap(Map<String, Object?> m) {
    final project = _map(m['project']);
    final firebase = _map(m['firebase']);
    final board = _map(m['board']);
    final needsRaw = _map(m['needs']);
    final needs = <String, NeedKind>{};
    for (final e in needsRaw.entries) {
      final v = _map(e.value);
      needs[e.key] = NeedKind(
        e.key,
        (v['label'] ?? e.key).toString(),
        (v['description'] ?? '').toString(),
      );
    }
    return Manifest(
      projectName: (project['name'] ?? 'Project').toString(),
      projectSlug: project['slug']?.toString(),
      firebaseProject: firebase['project']?.toString(),
      qa: _map(m['qa']),
      platforms: _stringList(m['platforms'], fallback: const ['ios', 'android']),
      releaseStep: m['release_step']?.toString(),
      boardTitle: board['title']?.toString(),
      boardArtifactUrl: board['artifact_url']?.toString(),
      boardOutput: (board['output'] ?? 'docs/board/launch_board.html').toString(),
      boardFonts: {for (final e in _map(board['fonts']).entries) e.key: e.value.toString()},
      boardColors: {
        for (final e in _map(board['colors']).entries)
          e.key: {for (final c in _map(e.value).entries) c.key: c.value.toString()},
      },
      planMarkdown: (m['plan_markdown'] ?? 'PROJECT_PLAN.md').toString(),
      extraNeeds: needs,
      journal: m['journal']?.toString(),
    );
  }

  final String projectName;
  final String? projectSlug;
  final String? firebaseProject;
  final Map<String, Object?> qa;
  final List<String> platforms;

  /// The step whose blockers count as launch blockers (e.g. `store-submission`).
  final String? releaseStep;
  final String? boardTitle;
  final String? boardArtifactUrl;
  final String boardOutput;

  /// `board.fonts`: `display`, `body`, `mono` — Google Fonts family names.
  final Map<String, String> boardFonts;

  /// `board.colors.light` / `board.colors.dark`: token overrides
  /// (`bg`, `surface`, `ink`, `ink2`, `muted`, `line`, `accent`, `accent_soft`,
  /// `good`, `warn`, `critical`).
  final Map<String, Map<String, String>> boardColors;
  final String planMarkdown;
  final Map<String, NeedKind> extraNeeds;

  /// Path of the append-only prose journal, if the project keeps one.
  final String? journal;

  Map<String, NeedKind> get needs => {...builtinNeeds, ...extraNeeds};

  Map<String, Object?> toMap() => {
        'kit': 2,
        'project': {
          'name': projectName,
          if (projectSlug != null) 'slug': projectSlug,
        },
        if (firebaseProject != null) 'firebase': {'project': firebaseProject},
        if (qa.isNotEmpty) 'qa': qa,
        'platforms': platforms,
        if (releaseStep != null) 'release_step': releaseStep,
        'board': {
          if (boardTitle != null) 'title': boardTitle,
          if (boardArtifactUrl != null) 'artifact_url': boardArtifactUrl,
          'output': boardOutput,
          if (boardFonts.isNotEmpty) 'fonts': boardFonts,
          if (boardColors.isNotEmpty) 'colors': boardColors,
        },
        'plan_markdown': planMarkdown,
        if (journal != null) 'journal': journal,
        if (extraNeeds.isNotEmpty)
          'needs': {for (final n in extraNeeds.values) n.id: n.toMap()},
      };
}

enum StepStatus { pending, active, done }

enum GateStatus { pending, passed, failed }

/// One machine gate on a step: something Claude proves (analyze, tests, qa).
class Gate {
  Gate(this.name, {this.status = GateStatus.pending, this.at, this.note});

  factory Gate.fromMap(String name, Object? raw) {
    final m = _map(raw);
    return Gate(
      name,
      status: GateStatus.values.byName((m['status'] ?? 'pending').toString()),
      at: m['at']?.toString(),
      note: m['note']?.toString(),
    );
  }

  final String name;
  GateStatus status;
  String? at;
  String? note;

  Map<String, Object?> toMap() => {
        'status': status.name,
        if (at != null) 'at': at,
        if (note != null) 'note': note,
      };
}

/// A `### Heading` and its markdown body, kept verbatim and in order so the
/// generated `PROJECT_PLAN.md` reads exactly like the hand-written one did.
class Section {
  const Section(this.title, this.body);
  final String title;
  final String body;

  Map<String, Object?> toMap() => {'title': title, 'body': body};
}

class HistoryEntry {
  const HistoryEntry(this.at, this.event, [this.note]);
  final String at;
  final String event;
  final String? note;

  Map<String, Object?> toMap() =>
      {'at': at, 'event': event, if (note != null) 'note': note};
}

/// `plan/steps/<id>.yaml` — one unit of Claude's work.
class Step {
  Step({
    required this.id,
    required this.title,
    this.number,
    required this.rank,
    this.status = StepStatus.pending,
    this.dependsOn = const [],
    this.meta = const {},
    Map<String, Gate>? gates,
    this.sections = const [],
    this.history = const [],
  }) : gates = gates ?? {};

  factory Step.fromMap(Map<String, Object?> m) {
    final gatesRaw = _map(m['gates']);
    return Step(
      id: m['id'].toString(),
      title: (m['title'] ?? m['id']).toString(),
      number: m['number']?.toString(),
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      status: StepStatus.values.byName((m['status'] ?? 'pending').toString()),
      dependsOn: _stringList(m['depends_on']),
      meta: _map(m['meta']),
      gates: {
        for (final e in gatesRaw.entries) e.key: Gate.fromMap(e.key, e.value),
      },
      sections: [
        for (final s in (m['sections'] as List? ?? const []))
          Section(
            (_map(s)['title'] ?? '').toString(),
            (_map(s)['body'] ?? '').toString(),
          ),
      ],
      history: [
        for (final h in (m['history'] as List? ?? const []))
          HistoryEntry(
            (_map(h)['at'] ?? '').toString(),
            (_map(h)['event'] ?? '').toString(),
            _map(h)['note']?.toString(),
          ),
      ],
    );
  }

  final String id;
  final String title;

  /// The display number ("29", "G10", "H4"). Headings move; ids do not.
  final String? number;

  /// Work order. Independent of [number], because the file order *is* the
  /// work order and numbers have been renumbered before.
  final int rank;
  StepStatus status;
  final List<String> dependsOn;

  /// Free-form passthrough (`max_turns`, `qa_required`, `spec_refs`, …).
  final Map<String, Object?> meta;
  final Map<String, Gate> gates;
  final List<Section> sections;
  final List<HistoryEntry> history;

  Section? section(String title) {
    final t = title.toLowerCase();
    for (final s in sections) {
      if (s.title.toLowerCase().startsWith(t)) return s;
    }
    return null;
  }

  bool get allGatesPassed =>
      gates.isEmpty || gates.values.every((g) => g.status == GateStatus.passed);

  Map<String, Object?> toMap() => {
        'id': id,
        if (number != null) 'number': number,
        'title': title,
        'status': status.name,
        'rank': rank,
        'depends_on': dependsOn,
        if (meta.isNotEmpty) 'meta': meta,
        if (gates.isNotEmpty)
          'gates': {for (final g in gates.values) g.name: g.toMap()},
        'sections': [for (final s in sections) s.toMap()],
        if (history.isNotEmpty) 'history': [for (final h in history) h.toMap()],
      };
}

enum ItemStatus { open, done, dropped }

/// One line of a runbook: what to do, what you should see, what to do if you
/// don't. `verify` is an optional shell command a machine can run to confirm
/// the line — the read-back after a deploy, the `dig` after a DNS change.
class RunbookLine {
  const RunbookLine({required this.doText, this.expect, this.ifFails, this.verify});

  factory RunbookLine.fromMap(Object? raw) {
    final m = _map(raw);
    return RunbookLine(
      doText: (m['do'] ?? '').toString(),
      expect: m['expect']?.toString(),
      ifFails: m['if_fails']?.toString(),
      verify: m['verify']?.toString(),
    );
  }

  final String doText;
  final String? expect;
  final String? ifFails;
  final String? verify;

  Map<String, Object?> toMap() => {
        'do': doText,
        if (expect != null) 'expect': expect,
        if (ifFails != null) 'if_fails': ifFails,
        if (verify != null) 'verify': verify,
      };
}

class QuestionOption {
  const QuestionOption(this.label, {this.recommended = false, this.why});

  factory QuestionOption.fromMap(Object? raw) {
    final m = _map(raw);
    return QuestionOption(
      (m['label'] ?? '').toString(),
      recommended: m['recommended'] == true,
      why: m['why']?.toString(),
    );
  }

  final String label;
  final bool recommended;
  final String? why;

  Map<String, Object?> toMap() => {
        'label': label,
        if (recommended) 'recommended': true,
        if (why != null) 'why': why,
      };
}

/// A decision item's question. The recommended option is listed first on
/// every surface, matching how Claude asks in the terminal.
class Question {
  const Question({required this.ask, this.options = const [], this.answer});

  factory Question.fromMap(Object? raw) {
    final m = _map(raw);
    return Question(
      ask: (m['ask'] ?? '').toString(),
      options: [
        for (final o in (m['options'] as List? ?? const []))
          QuestionOption.fromMap(o),
      ],
      answer: m['answer']?.toString(),
    );
  }

  final String ask;
  final List<QuestionOption> options;
  final String? answer;

  Map<String, Object?> toMap() => {
        'ask': ask,
        if (options.isNotEmpty) 'options': [for (final o in options) o.toMap()],
        if (answer != null) 'answer': answer,
      };
}

class ItemSource {
  const ItemSource({this.file, this.section, this.line});

  factory ItemSource.fromMap(Object? raw) {
    final m = _map(raw);
    return ItemSource(
      file: m['file']?.toString(),
      section: m['section']?.toString(),
      line: (m['line'] as num?)?.toInt(),
    );
  }

  final String? file;
  final String? section;
  final int? line;

  Map<String, Object?> toMap() => {
        if (file != null) 'file': file,
        if (section != null) 'section': section,
        if (line != null) 'line': line,
      };
}

/// `plan/items/<id>.yaml` — one unit of the human's work.
class Item {
  Item({
    required this.id,
    required this.title,
    this.status = ItemStatus.open,
    this.needs = const [],
    this.blocks = const [],
    this.step,
    this.added,
    this.deadline,
    this.doneAt,
    this.body = '',
    this.runbook = const [],
    this.question,
    this.source,
    this.note,
  });

  factory Item.fromMap(Map<String, Object?> m) => Item(
        id: m['id'].toString(),
        title: (m['title'] ?? m['id']).toString(),
        status: ItemStatus.values.byName((m['status'] ?? 'open').toString()),
        needs: _stringList(m['needs']),
        blocks: _stringList(m['blocks']),
        step: m['step']?.toString(),
        added: m['added']?.toString(),
        deadline: m['deadline']?.toString(),
        doneAt: m['done_at']?.toString(),
        body: (m['body'] ?? '').toString(),
        runbook: [
          for (final r in (m['runbook'] as List? ?? const []))
            RunbookLine.fromMap(r),
        ],
        question: m['question'] == null ? null : Question.fromMap(m['question']),
        source: m['source'] == null ? null : ItemSource.fromMap(m['source']),
        note: m['note']?.toString(),
      );

  final String id;
  final String title;
  ItemStatus status;
  final List<String> needs;

  /// Step ids this item gates. A step is not done while an open item names it.
  final List<String> blocks;

  /// The step that produced the item (provenance, not a gate).
  final String? step;
  final String? added;
  final String? deadline;
  String? doneAt;
  final String body;
  final List<RunbookLine> runbook;
  final Question? question;
  final ItemSource? source;
  String? note;

  bool get isOpen => status == ItemStatus.open;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'status': status.name,
        'needs': needs,
        'blocks': blocks,
        if (step != null) 'step': step,
        if (added != null) 'added': added,
        if (deadline != null) 'deadline': deadline,
        if (doneAt != null) 'done_at': doneAt,
        if (body.isNotEmpty) 'body': body,
        if (runbook.isNotEmpty) 'runbook': [for (final r in runbook) r.toMap()],
        if (question != null) 'question': question!.toMap(),
        if (source != null) 'source': source!.toMap(),
        if (note != null) 'note': note,
      };
}

/// The whole plan in memory. Steps are kept in rank order.
class Plan {
  Plan({required this.manifest, required List<Step> steps, required List<Item> items})
      : steps = List.of(steps)..sort((a, b) => a.rank.compareTo(b.rank)),
        items = List.of(items);

  final Manifest manifest;
  final List<Step> steps;
  final List<Item> items;

  Step? step(String id) {
    for (final s in steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  Item? item(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Open items that name [stepId] in `blocks:`.
  List<Item> blockersOf(String stepId) =>
      [for (final i in items) if (i.isOpen && i.blocks.contains(stepId)) i];
}

// ---------------------------------------------------------------------------

Map<String, Object?> _map(Object? raw) {
  if (raw is Map) {
    return {for (final e in raw.entries) e.key.toString(): deepPlain(e.value)};
  }
  return {};
}

List<String> _stringList(Object? raw, {List<String> fallback = const []}) {
  if (raw is List) return [for (final v in raw) v.toString()];
  if (raw is String && raw.trim().isNotEmpty && raw.trim() != 'none') {
    return [for (final p in raw.split(',')) p.trim()].where((s) => s.isNotEmpty).toList();
  }
  return fallback;
}

/// Converts `YamlMap`/`YamlList` trees into plain Dart collections so the
/// model never leaks the parser's types.
Object? deepPlain(Object? v) {
  if (v is Map) {
    return {for (final e in v.entries) e.key.toString(): deepPlain(e.value)};
  }
  if (v is List) return [for (final x in v) deepPlain(x)];
  return v;
}
