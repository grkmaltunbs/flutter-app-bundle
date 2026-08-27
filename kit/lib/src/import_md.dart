/// Imports the hand-written `PROJECT_PLAN.md` and the prose journal
/// (`things_for_human_eye.md`) into the plan schema.
///
/// This is a *first pass*: it is lossless on prose (every section body and
/// every journal entry is carried verbatim) and *heuristic* on the fields
/// that were never written down — what an item needs, which step it blocks,
/// when it was added. Those are for a person to review on the board, which
/// is why unknowns are left empty rather than guessed confidently.
library;

import 'markdown_split.dart';
import 'model.dart';

/// Marker left in a section body where a human-box list was lifted out, so
/// the renderer can put the (now item-backed) list back in the same place.
const humanBoxesMarker = '<!-- kit:human-boxes -->';

class ImportResult {
  ImportResult(this.steps, this.items, this.notes);
  final List<Step> steps;
  final List<Item> items;

  /// Things the importer was unsure about, one per line, for the report.
  final List<String> notes;
}

// ---------------------------------------------------------------------------
// PROJECT_PLAN.md

final _stepHeading = RegExp(r'^## Step\s+([A-Za-z]*\d+[A-Za-z]*)\s+[—–-]\s+(.+?)\s*$');
final _sectionHeading = RegExp(r'^### (.+?)\s*$');
final _checkbox = RegExp(r'^- \[([ xX])\]\s*(.*)$');
final _field = RegExp(r'^- ([a-z_]+):\s*(.*)$');
final _humanLead = RegExp(r'^\s*\*\*Your part \(human\)', caseSensitive: false);
final _boxLine = RegExp(r'^(\s*)- \[([ xX])\]\s*(.*)$');

List<Step> importPlanMarkdown(String text, {List<String> activeIds = const [], List<Item>? itemsOut, List<String>? notes}) {
  final lines = scanLines(text).toList();
  final starts = <int>[];
  for (final l in lines) {
    if (!l.inFence && _stepHeading.hasMatch(l.text)) starts.add(l.index);
  }
  final steps = <Step>[];
  for (var k = 0; k < starts.length; k++) {
    final from = starts[k];
    final to = k + 1 < starts.length ? starts[k + 1] : lines.length;
    final chunk = lines.sublist(from, to);
    final step = _parseStep(chunk, rank: (k + 1) * 10, itemsOut: itemsOut, notes: notes);
    if (activeIds.contains(step.id) && step.status == StepStatus.pending) {
      step.status = StepStatus.active;
      for (final g in step.gates.values) {
        g.status = GateStatus.passed;
        g.note = 'recorded at import';
      }
    }
    steps.add(step);
  }
  return steps;
}

Step _parseStep(List<ScannedLine> chunk, {required int rank, List<Item>? itemsOut, List<String>? notes}) {
  final head = _stepHeading.firstMatch(chunk.first.text)!;
  final number = head.group(1)!;
  final title = head.group(2)!;

  var status = StepStatus.pending;
  String? id;
  var dependsOn = <String>[];
  final meta = <String, Object?>{};

  // Preamble: lines up to the first ### heading.
  var i = 1;
  while (i < chunk.length && !(_sectionHeading.hasMatch(chunk[i].text) && !chunk[i].inFence)) {
    final t = chunk[i].text;
    final cb = _checkbox.firstMatch(t);
    if (cb != null && !_field.hasMatch(t)) {
      status = cb.group(1)! == ' ' ? StepStatus.pending : StepStatus.done;
    } else {
      final f = _field.firstMatch(t);
      if (f != null) {
        final key = f.group(1)!;
        final val = f.group(2)!.trim();
        switch (key) {
          case 'id':
            id = val;
          case 'depends_on':
            dependsOn = val == 'none' || val.isEmpty
                ? []
                : [for (final p in val.split(',')) p.trim()].where((s) => s.isNotEmpty).toList();
          default:
            meta[key] = _coerce(val);
        }
      }
    }
    i++;
  }
  id ??= _slug(title);

  // Sections.
  final sections = <Section>[];
  String? current;
  final body = StringBuffer();
  void flush() {
    if (current != null) {
      sections.add(Section(current, _trimSectionBody(body.toString())));
    }
    body.clear();
  }

  for (; i < chunk.length; i++) {
    final l = chunk[i];
    final m = l.inFence ? null : _sectionHeading.firstMatch(l.text);
    if (m != null) {
      flush();
      current = m.group(1)!;
    } else {
      body.writeln(l.text);
    }
  }
  flush();

  // Lift human boxes out of any section into items.
  final lifted = <Section>[];
  var boxIndex = 0;
  for (final s in sections) {
    final r = _liftHumanBoxes(s.body, stepId: id, startIndex: boxIndex, sectionTitle: s.title, stepDone: status == StepStatus.done);
    boxIndex += r.items.length;
    itemsOut?.addAll(r.items);
    lifted.add(Section(s.title, r.body));
  }

  final gates = {
    for (final g in const ['analyze', 'tests', 'qa'])
      g: Gate(g, status: status == StepStatus.done ? GateStatus.passed : GateStatus.pending,
          note: status == StepStatus.done ? 'recorded at import' : null),
  };

  return Step(
    id: id,
    number: number,
    title: title,
    rank: rank,
    status: status,
    dependsOn: dependsOn,
    meta: meta,
    gates: gates,
    sections: lifted,
    history: [
      HistoryEntry(_today(), 'imported', 'from PROJECT_PLAN.md, heading "Step $number"'),
    ],
  );
}

class _Lift {
  _Lift(this.body, this.items);
  final String body;
  final List<Item> items;
}

/// Finds a `**Your part (human)…**` lead followed by a checkbox list (or a
/// section that is nothing but a checkbox list) and replaces the list with
/// [humanBoxesMarker].
_Lift _liftHumanBoxes(String body, {required String stepId, required int startIndex, required String sectionTitle, required bool stepDone}) {
  final lines = body.split('\n');
  final items = <Item>[];
  final out = <String>[];
  final isHumanSection = sectionTitle.toLowerCase().startsWith('your part');
  var n = startIndex;
  var i = 0;
  while (i < lines.length) {
    final t = lines[i];
    final lead = _humanLead.hasMatch(t);
    if (lead || (isHumanSection && _boxLine.hasMatch(t) && items.isEmpty)) {
      if (lead) {
        out.add(t);
        i++;
        // Skip blank lines between the lead and the list.
        while (i < lines.length && lines[i].trim().isEmpty) {
          out.add(lines[i]);
          i++;
        }
      }
      // Consume the list.
      final boxes = <List<String>>[];
      while (i < lines.length) {
        final m = _boxLine.firstMatch(lines[i]);
        if (m != null) {
          boxes.add([m.group(2)!, m.group(3)!]);
          i++;
          // Continuation lines: indented, non-empty, not a new box.
          while (i < lines.length &&
              lines[i].trim().isNotEmpty &&
              lines[i].startsWith(RegExp(r'\s{2,}')) &&
              !_boxLine.hasMatch(lines[i])) {
            boxes.last[1] = '${boxes.last[1]} ${lines[i].trim()}';
            i++;
          }
        } else if (lines[i].trim().isEmpty && i + 1 < lines.length && _boxLine.hasMatch(lines[i + 1])) {
          i++; // blank line between boxes
        } else {
          break;
        }
      }
      if (boxes.isEmpty) continue;
      for (final b in boxes) {
        n++;
        final text = b[1].trim();
        final checked = b[0] != ' ';
        // A box left open under a step somebody already flipped to done was
        // satisfied by that flip — the step's checkbox is the stronger
        // statement. Close it, and say so, rather than contradict the plan.
        final closedByStep = !checked && stepDone;
        items.add(Item(
          id: '$stepId-h$n',
          title: _titleFrom(text),
          status: checked || closedByStep ? ItemStatus.done : ItemStatus.open,
          needs: guessNeeds(text),
          blocks: [stepId],
          step: stepId,
          body: text,
          note: closedByStep ? 'closed at import: the step was already marked done in PROJECT_PLAN.md while this box was unchecked' : null,
          source: ItemSource(file: 'PROJECT_PLAN.md', section: 'Step $stepId / $sectionTitle'),
        ));
      }
      out.add(humanBoxesMarker);
      continue;
    }
    out.add(t);
    i++;
  }
  return _Lift(out.join('\n'), items);
}

// ---------------------------------------------------------------------------
// things_for_human_eye.md

final _journalSection = RegExp(r'^## ([A-Z])\.\s+(.+?)\s*$');
final _topBox = RegExp(r'^- \[([ xX])\]\s+(.*)$');
final _provenance = RegExp(r'\(\s*Step\s+([A-Za-z]*\d+[A-Za-z]*)[^)]*?(\d{4}-\d{2}-\d{2})');
final _anyDate = RegExp(r'\d{4}-\d{2}-\d{2}');
final _stepMention = RegExp(r'\bStep\s+([A-Za-z]*\d+[A-Za-z]*)\b');

List<Item> importJournalMarkdown(
  String text, {
  required Map<String, String> numberToStepId,
  String? releaseStep,
  Set<String> existingIds = const {},
  Set<String> doneStepIds = const {},
  List<String>? notes,
}) {
  final lines = scanLines(text).toList();
  final items = <Item>[];
  final usedIds = {...existingIds};
  String? sectionLetter;
  String? sectionTitle;

  var i = 0;
  while (i < lines.length) {
    final l = lines[i];
    if (!l.inFence) {
      final sm = _journalSection.firstMatch(l.text);
      if (sm != null) {
        sectionLetter = sm.group(1);
        sectionTitle = sm.group(2);
        i++;
        continue;
      }
      final bm = _topBox.firstMatch(l.text);
      if (bm != null) {
        final startLine = l.index + 1;
        final buf = <String>[bm.group(2)!];
        i++;
        while (i < lines.length) {
          final t = lines[i].text;
          final structural = !lines[i].inFence &&
              (_topBox.hasMatch(t) || _journalSection.hasMatch(t) || t.startsWith('## ') || t == '---');
          if (structural) break;
          if (t.trim().isEmpty) {
            // Blank: item continues only if the next non-blank line is indented.
            var j = i + 1;
            while (j < lines.length && lines[j].text.trim().isEmpty) {
              j++;
            }
            if (j < lines.length && (lines[j].text.startsWith('  ') || lines[j].inFence)) {
              buf.add('');
              i++;
              continue;
            }
            break;
          }
          if (!t.startsWith(' ') && !lines[i].inFence) break;
          buf.add(t.length >= 2 && t.startsWith('  ') ? t.substring(2) : t);
          i++;
        }
        final body = buf.join('\n').trimRight();
        final checked = bm.group(1)! != ' ';
        final title = _journalTitle(body);
        var id = _slug(title);
        var k = 2;
        while (usedIds.contains(id)) {
          id = '${_slug(title)}-$k';
          k++;
        }
        usedIds.add(id);

        final prov = _provenance.firstMatch(body);
        final stepNumber = prov?.group(1) ?? _stepMention.firstMatch(body)?.group(1);
        final stepId = stepNumber == null ? null : numberToStepId[stepNumber];
        final dates = _anyDate.allMatches(body).map((m) => m.group(0)!).toList();
        final added = prov?.group(2) ?? (dates.isEmpty ? null : dates.first);

        final needs = <String>{};
        switch (sectionLetter) {
          case 'B':
            needs.add('device');
          case 'C':
            needs.add('console');
          case 'D':
            needs.add('decision');
        }
        final guessed = guessNeeds(body);
        // Section default first, keyword guesses after — the first need is
        // the sitting the board files it under.
        final needsList = [...needs, ...guessed.where((g) => !needs.contains(g))];

        final blocks = <String>{};
        if (!checked) {
          if (sectionLetter == 'A' && releaseStep != null) blocks.add(releaseStep);
          // A mention of a step is a weak signal, and never one that can
          // gate a step already done — that would contradict the invariant
          // validate() enforces.
          for (final m in _stepMention.allMatches(body)) {
            final sid = numberToStepId[m.group(1)!];
            if (sid != null && sid != stepId && !doneStepIds.contains(sid)) blocks.add(sid);
          }
        }

        String? deadline;
        if (RegExp(r'deadline|decommission|cut-?off|shuts? off|end of life', caseSensitive: false).hasMatch(body) && dates.isNotEmpty) {
          deadline = dates.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
          if (added != null && deadline == added) deadline = null;
        }

        items.add(Item(
          id: id,
          title: title,
          status: checked ? ItemStatus.done : ItemStatus.open,
          needs: needsList,
          blocks: blocks.toList(),
          step: stepId,
          added: added,
          deadline: deadline,
          doneAt: checked ? (dates.isEmpty ? null : dates.last) : null,
          body: body,
          source: ItemSource(file: 'things_for_human_eye.md', section: '$sectionLetter. $sectionTitle', line: startLine),
        ));
        if (needsList.isEmpty) notes?.add('items/$id: could not tell what it needs');
        if (stepNumber != null && stepId == null) {
          notes?.add('items/$id: mentions Step $stepNumber, which is not in the plan');
        }
        continue;
      }
    }
    i++;
  }
  return items;
}

// ---------------------------------------------------------------------------
// Heuristics

final _needRules = <String, RegExp>{
  'decision': RegExp(r'\b(decide|decision|confirm you (still )?agree|your call|product call|which (one|way)|approve|choose)\b', caseSensitive: false),
  'console': RegExp(r'\b(console|Remote Config|Secret Manager|Cloud Functions? console|dashboard|Firebase console|App Store Connect|Play Console|RevenueCat|Porkbun|registrar|DNS|GA4|DebugView|Crashlytics)\b', caseSensitive: false),
  'device': RegExp(r'\b(physical (iPhone|device|phone)|real (iPhone|device|phone|hardware)|second (device|handset|phone)|on (a|your) (device|phone|iPhone)|handset|TestFlight build on)\b', caseSensitive: false),
  'read': RegExp(r'\b(read (it |the |this |them )?(out loud|aloud)|Turkish (copy|text|reason|strings?|reads?)|proof-?read|wording)\b', caseSensitive: false),
  'look': RegExp(r'\b(look at|have a look|eyeball|in both themes|sign-?off on the look|does it look)\b', caseSensitive: false),
  'store': RegExp(r'\b(App Store|Play (Store|listing|Console)|store listing|TestFlight|data[- ]safety|review notes|SHA-?256|submission)\b', caseSensitive: false),
  'money': RegExp(r'\b(buy|purchase|pay|paid plan|domain|\$\d|₺\d|card on file|Blaze)\b', caseSensitive: false),
  'secret': RegExp(r'\b(API key|secret|credential|certificate|token|signing key|keystore)\b', caseSensitive: false),
};

List<String> guessNeeds(String text) {
  final out = <String>[];
  for (final e in _needRules.entries) {
    if (e.value.hasMatch(text)) out.add(e.key);
  }
  return out;
}

String _journalTitle(String body) {
  final m = RegExp(r'\*\*(.+?)\*\*', dotAll: true).firstMatch(body);
  var t = m != null ? m.group(1)! : body.split(RegExp(r'(?<=[.!?])\s')).first;
  t = t.replaceAll(RegExp(r'\s+'), ' ').replaceAll('~~', '').trim();
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  return t.length > 140 ? '${t.substring(0, 137).trimRight()}…' : t;
}

String _titleFrom(String text) {
  var t = text.replaceAll(RegExp(r'\*\*'), '').replaceAll('~~', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  final cut = RegExp(r'(?<=[.!?])\s').firstMatch(t);
  if (cut != null) t = t.substring(0, cut.start);
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  return t.length > 140 ? '${t.substring(0, 137).trimRight()}…' : t;
}

final _nonSlug = RegExp(r'[^a-z0-9]+');

String _slug(String s) {
  var t = s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ç', 'c')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll(_nonSlug, '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (t.length > 48) {
    t = t.substring(0, 48);
    final cut = t.lastIndexOf('-');
    if (cut > 20) t = t.substring(0, cut);
  }
  return t.isEmpty ? 'item' : t;
}

Object? _coerce(String v) {
  if (v == 'true') return true;
  if (v == 'false') return false;
  final n = int.tryParse(v);
  if (n != null) return n;
  return v;
}

/// Keeps the body verbatim — including the blank line (or its absence)
/// after the heading — so the rendered plan is byte-for-byte the original.
/// Only the plan's own `---` step separator is removed.
String _trimSectionBody(String s) {
  var t = s;
  t = t.replaceFirst(RegExp(r'\n---\s*$'), '\n');
  t = t.trimRight();
  return t.isEmpty ? '' : '$t\n';
}

String _today() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
