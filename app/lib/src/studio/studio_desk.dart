import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart' show DeckMessage, DeckRole;
import 'package:path/path.dart' as p;

import '../host/bridge_session.dart';
import 'studio_draft.dart';

// The step desk: a second Claude session that answers questions about one
// lane step or roadmap item at a time, so the orchestrator's own
// conversation stays on orchestrating. Each step keeps its thread — the
// desk's scoped rows, saved to disk as they finish — and follow-ups land in
// the same conversation. The desk never edits a file: a change it would
// make comes back as a proposal card the person can put in the draft; the
// orchestrator stays the one writer.

/// `{step: 'a/ROOMLAB-1C'}` for a lane step, `{item: 'M3.22'}` for a roadmap item.
Map<String, Object?> stepAbout(String lane, String id) => {'step': '$lane/$id'};
Map<String, Object?> itemAbout(String id) => {'item': id};

/// The thread's key: `step:a/ROOMLAB-1C`, `item:M3.22`.
String? threadKeyOf(Map<String, Object?>? about) {
  if (about == null) return null;
  if (about['step'] != null) return 'step:${about['step']}';
  if (about['item'] != null) return 'item:${about['item']}';
  return null;
}

class StudioDesk {
  static BridgeSession? _bridge;
  static String? _dir;
  static StudioThreads? _threads;

  /// The desk's threads (one store per app).
  static StudioThreads get threads => _threads ??= StudioThreads()..load();

  /// The desk for [dir]. Its record lives under its own home, so it never
  /// takes the orchestrator's place in the same folder.
  static BridgeSession get(String dir, {required String autopilotDir, String? home}) {
    if (_bridge != null && _dir == dir) return _bridge!;
    final old = _bridge;
    if (old != null) {
      if (old.running) old.stop();
      old.dispose();
    }
    _dir = dir;
    final h = home ?? p.join(Platform.environment['HOME'] ?? '.', '.flutter_kit', 'studio-desk');
    final b = _bridge = BridgeSession(dir: dir, home: h)
      ..briefExtra = (() => deskBrief(autopilotDir: autopilotDir))
      ..promptForAbout = deskPrompt
      ..describeAbout = ((about) => threads.context[threadKeyOf(about)]);
    threads.watch(b);
    return b;
  }

  static Future<void> quit() async {
    final b = _bridge;
    if (b != null && b.running) await b.stop();
  }
}

/// What the desk is told at every start.
String deskBrief({required String autopilotDir}) => '''
You are the step desk of the Sivas game autopilot's Studio (K.A.T.Y.A). The user asks you about one lane step or one roadmap item at a time; each message names it and carries its text.
Answer from the files: the autopilot folder $autopilotDir (README.md, lane-<x>/history.log and logs/, mail/, review/), the lanes' step lists and decision logs, and production/production-plan.md. Prefer reading (Read, Grep, Glob) to running commands.
Never edit, create or delete a file, and never commit: the orchestrator is the only writer. When the step or item should change, say so and end your answer with one block per change, exactly in this form:
```studio-proposal
kind: edit | add | remove | link | unlink
lane: a            (omit for a roadmap item)
target: STEP-ID    (the step or item; for add, the one the new step goes after)
other: lane-b/STEP-ID   (link/unlink: what the target waits on)
new_id: NEW-ID     (add only)
text: |
  the full new text (edit/add); indented "  - " lines are substeps
```
The user turns a proposal into a draft order with one tap and sends the draft to the orchestrator.
When the message is exactly "Summarize this step.", read what you need and answer with only this block — two plain sentences for someone who is not a developer: what the step is for, and why it matters to the game:
```studio-summary
…
```
Keep answers short and concrete, for a phone screen. Follow-ups about the same step continue the same thread.''';

/// A scoped message, as the desk reads it.
String deskPrompt(String text, Map<String, Object?> about, String? shown) {
  final what = about['step'] != null ? 'lane step ${about['step']}' : 'roadmap item ${about['item']}';
  return [
    '[Studio desk · $what] $text',
    if (shown != null && shown.trim().isNotEmpty) ...['', '--- as its file holds it ---', shown.trim(), '--- end ---'],
  ].join('\n');
}

/// A change the desk proposes, parsed from a ```studio-proposal block.
DraftOrder? parseProposal(String block) {
  final fields = <String, String>{};
  final lines = block.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final m = RegExp(r'^(\w+):\s?(.*)$').firstMatch(lines[i]);
    if (m == null) continue;
    final k = m.group(1)!;
    var v = m.group(2)!.trim();
    if (v == '|') {
      final body = <String>[];
      while (i + 1 < lines.length && (lines[i + 1].startsWith('  ') || lines[i + 1].trim().isEmpty)) {
        i++;
        body.add(lines[i].startsWith('  ') ? lines[i].substring(2) : '');
      }
      v = body.join('\n').trimRight();
    } else {
      v = v.replaceFirst(RegExp(r'\s+\(.*\)$'), '');
    }
    fields[k] = v;
  }
  final kind = DraftKind.values.where((k) => k.name == fields['kind']).firstOrNull;
  final target = fields['target'];
  if (kind == null || target == null || target.isEmpty) return null;
  final lane = fields['lane']?.toLowerCase().replaceFirst('lane-', '').replaceFirst('lane ', '');
  final text = fields['text'];
  return DraftOrder(
    kind: kind,
    lane: lane == null || lane.isEmpty ? null : lane,
    target: target,
    other: fields['other'],
    newId: fields['new_id'],
    text: kind == DraftKind.edit && lane != null && lane.isNotEmpty && text != null && !text.startsWith('- [') ? '- [ ] $target: $text' : text,
  );
}

/// Splits an answer into its prose, its proposals and its summary.
({String prose, List<DraftOrder> proposals, String? summary}) splitAnswer(String text) {
  final proposals = <DraftOrder>[];
  String? summary;
  var prose = text.replaceAllMapped(RegExp(r'```studio-proposal\n([\s\S]*?)```'), (m) {
    final o = parseProposal(m.group(1)!);
    if (o != null) proposals.add(o);
    return '';
  });
  prose = prose.replaceAllMapped(RegExp(r'```studio-summary\n([\s\S]*?)```'), (m) {
    summary = m.group(1)!.trim();
    return '';
  });
  return (prose: prose.trim(), proposals: proposals, summary: summary);
}

/// The message EXPLAIN sends.
const kSummarize = 'Summarize this step.';

/// Asks the desk [text] about a step, starting the desk when it is not
/// running. Returns an error to show, or null.
Future<String?> askDesk(BridgeSession desk, StudioThreads threads, {required Map<String, Object?> about, required String stepText, required String text}) async {
  threads.context[threadKeyOf(about)!] = stepText;
  if (!desk.running) {
    await desk.start(resume: desk.sessionId != null);
    final ok = await desk.awaitReady(timeout: const Duration(seconds: 30));
    if (!ok) return 'The step desk did not start${desk.error == null ? '' : ': ${desk.error}'}';
  }
  desk.send(text, about: about);
  return null;
}

/// Every step's thread: the desk's finished scoped rows, kept in a file per
/// thread under ~/.flutter_kit/studio/threads so they outlive the session,
/// its 300-row window and a relaunch.
class StudioThreads extends ChangeNotifier {
  StudioThreads({String? dir}) : dir = dir ?? p.join(Platform.environment['HOME'] ?? '.', '.flutter_kit', 'studio', 'threads');
  final String dir;

  final Map<String, List<DeckMessage>> _rows = {};
  final Set<String> _saved = {};

  /// The step's text the desk is shown with each question, by thread key.
  final Map<String, String> context = {};

  BridgeSession? _watched;

  File _file(String key) => File(p.join(dir, '${key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.json'));

  void load() {
    final d = Directory(dir);
    if (!d.existsSync()) return;
    for (final f in d.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      try {
        final j = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
        final key = j['key'] as String;
        final rows = [for (final r in (j['rows'] as List)) DeckMessage.fromMap((r as Map).cast<String, Object?>())];
        _rows[key] = rows;
        for (final r in rows) {
          _saved.add('$key|${r.id}');
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Saves the desk's finished scoped rows as they come.
  void watch(BridgeSession b) {
    _watched?.removeListener(_collect);
    _watched = b;
    b.addListener(_collect);
  }

  void _collect() {
    final b = _watched;
    if (b == null) return;
    final sid = b.sessionId ?? 'x';
    final touched = <String>{};
    for (final m in b.transcript.messages) {
      final key = threadKeyOf(m.about);
      if (key == null || m.streaming || m.role == DeckRole.note) continue;
      if (m.role == DeckRole.tool && m.toolResult == null) continue;
      final id = '$sid-${m.id}';
      if (!_saved.add('$key|$id')) continue;
      final copy = DeckMessage.fromMap({...m.toMap(), 'id': id});
      (_rows[key] ??= []).add(copy);
      touched.add(key);
    }
    for (final k in touched) {
      _write(k);
    }
    notifyListeners();
  }

  void _write(String key) {
    try {
      final f = _file(key)..parent.createSync(recursive: true);
      f.writeAsStringSync(jsonEncode({'key': key, 'rows': [for (final r in _rows[key]!) r.toMap()]}));
    } catch (_) {}
  }

  /// The saved rows of a thread, oldest first.
  List<DeckMessage> rows(String key) => List.unmodifiable(_rows[key] ?? const []);

  /// Questions asked in a thread.
  int questions(String key) => realQuestions(key);

  /// The latest answer's prose, for a panel (a bare summary is not an answer).
  String? lastAnswer(String key) {
    final r = _rows[key];
    if (r == null) return null;
    for (final m in r.reversed) {
      if (m.role != DeckRole.assistant || m.text.trim().isEmpty) continue;
      final prose = splitAnswer(m.text).prose;
      if (prose.isNotEmpty) return prose;
    }
    return null;
  }

  /// What the step is for, as the desk last summarized it.
  String? summary(String key) {
    final r = _rows[key];
    if (r == null) return null;
    for (final m in r.reversed) {
      if (m.role != DeckRole.assistant) continue;
      final s = splitAnswer(m.text).summary;
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  /// Questions asked, not counting EXPLAIN.
  int realQuestions(String key) => (_rows[key] ?? const []).where((m) => m.role == DeckRole.user && !m.text.contains('] $kSummarize')).length;
}
