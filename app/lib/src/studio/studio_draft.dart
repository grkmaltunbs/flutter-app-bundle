import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Changes the person makes on the constellations — link, unlink, add, edit,
// remove — kept as a draft until SEND TO ORCHESTRATOR, as K.A.T.Y.A keeps
// ticks and notes until Send to Claude. The app never writes a step list:
// the lanes edit and commit those files themselves, so every change is an
// order the orchestrator carries out the autopilot's own way.

enum DraftKind { link, unlink, add, edit, remove, move }

class DraftOrder {
  const DraftOrder({required this.kind, required this.target, this.lane, this.other, this.text, this.newId});

  final DraftKind kind;

  /// The lane ('a' …) for a lane step; null for a roadmap item.
  final String? lane;

  /// The step or item the order is about (for [DraftKind.add], the one the
  /// new step goes after).
  final String target;

  /// For link/unlink: what [target] waits on — `lane-b/ID` for a step,
  /// an item id on the roadmap. For move: the step it goes right after
  /// (`^` for the top of the open steps), or `milestone:M4` on the roadmap.
  final String? other;

  /// For add and edit: the step's text (markdown; indented sub-bullets
  /// are its substeps).
  final String? text;

  /// For add: the new step's id.
  final String? newId;

  bool get onRoadmap => lane == null;

  /// The graph's key of the step this order is about.
  String? get key => lane == null ? null : '$lane/$target';

  Map<String, Object?> toJson() => {'kind': kind.name, 'lane': lane, 'target': target, 'other': other, 'text': text, 'newId': newId};

  static DraftOrder fromJson(Map<String, Object?> j) => DraftOrder(
        kind: DraftKind.values.byName(j['kind'] as String),
        lane: j['lane'] as String?,
        target: j['target'] as String,
        other: j['other'] as String?,
        text: j['text'] as String?,
        newId: j['newId'] as String?,
      );

  /// "Lane A · ROOMLAB-1D" / "Roadmap · M3.22".
  String get where => lane == null ? 'Roadmap · $target' : 'Lane ${lane!.toUpperCase()} · $target';

  /// One line for the review sheet.
  String get summary => switch (kind) {
        DraftKind.link => '$where waits on $other',
        DraftKind.unlink => '$where no longer waits on $other',
        DraftKind.add => '${lane == null ? 'Roadmap' : 'Lane ${lane!.toUpperCase()}'} · new ${lane == null ? 'item' : 'step'} $newId after $target',
        DraftKind.edit => '$where — new text',
        DraftKind.remove => '$where — remove',
        DraftKind.move => other == '^' ? '$where — move to the front' : (other!.startsWith('milestone:') ? '$where — move into ${other!.substring(10)}' : '$where — move after $other'),
      };

  /// What the orchestrator is asked to do.
  String get instruction {
    final step = lane == null ? 'item' : 'step';
    return switch (kind) {
      DraftKind.link => lane == null
          ? '$where — make it wait on $other: say so in its row ("after $other").'
          : '$where — make it wait on $other: append ` (after: $other)` to the end of the step\'s first line, or add `$other` to the `after:` tag it already has.',
      DraftKind.unlink => lane == null ? '$where — it no longer waits on $other: take that out of its row.' : '$where — it no longer waits on $other: take `$other` out of its `after:` tag (drop the tag when it is empty).',
      DraftKind.add => lane == null
          ? 'Roadmap — add a new item $newId to the milestone of $target, after $target:\n${_indent(text ?? '')}'
          : 'Lane ${lane!.toUpperCase()} — add a new open step right after $target:\n${_indent('- [ ] $newId: ${text ?? ''}')}',
      DraftKind.edit => '$where — replace the $step\'s text with (keep its checkbox and its tags unless the new text changes them):\n${_indent(text ?? '')}',
      DraftKind.remove => '$where — remove this $step${lane == null ? '' : ' from the list (only if it is not done and no step is running it; otherwise say so)'}.',
      DraftKind.move => lane == null
          ? (other!.startsWith('milestone:') ? '$where — move this item into milestone ${other!.substring(10)} (its table in Open work), keeping its row as it is.' : '$where — move this item\'s row to right after $other (into $other\'s milestone if that differs), keeping the row as it is.')
          : (other == '^'
              ? '$where — move this step up to be the first open step of the list, keeping its text and tags.'
              : '$where — move this step to right after $other in the list, keeping its text and tags (only if it is not done and no step is running it).'),
    };
  }
}

String _indent(String s) => s.trimRight().split('\n').map((l) => '    $l').join('\n');

/// The whole message SEND TO ORCHESTRATOR sends.
String draftPrompt(List<DraftOrder> orders) {
  final b = StringBuffer()
    ..writeln('[Studio · plan changes] The user sends ${orders.length} change${orders.length == 1 ? '' : 's'} from the Studio\'s graphs.')
    ..writeln('Apply each the autopilot\'s own way: edit the lane\'s step list and commit it on the lane\'s branch when the lane is not mid-step on that list, or leave a /autopilot-tell note so the lane makes the change in its next step. Roadmap changes go in production/production-plan.md; when one belongs to someone else\'s side, say so instead.')
    ..writeln('Write dependency tags exactly as given. Then answer with one line per change: done, left as a note for lane X, or not done and why.')
    ..writeln();
  for (final (i, o) in orders.indexed) {
    b.writeln('${i + 1}. ${o.instruction}');
  }
  return b.toString().trimRight();
}

/// The draft, remembered across launches until it is sent or cleared.
class StudioDraft extends ChangeNotifier {
  StudioDraft({this.persist = true});
  final bool persist;
  static const _key = 'studio.draft';

  final List<DraftOrder> orders = [];

  bool get isEmpty => orders.isEmpty;
  int get length => orders.length;

  Future<void> restore() async {
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      orders
        ..clear()
        ..addAll([for (final j in jsonDecode(raw) as List) DraftOrder.fromJson((j as Map).cast<String, Object?>())]);
      notifyListeners();
    } catch (_) {}
  }

  void _save() {
    notifyListeners();
    if (!persist) return;
    final raw = jsonEncode([for (final o in orders) o.toJson()]);
    SharedPreferences.getInstance().then((p) => p.setString(_key, raw)).catchError((Object _) => false);
  }

  /// Adds [o]; a link that undoes a pending unlink (or the other way round)
  /// cancels it, and a second edit of a step replaces the first.
  void add(DraftOrder o) {
    final opposite = o.kind == DraftKind.link ? DraftKind.unlink : (o.kind == DraftKind.unlink ? DraftKind.link : null);
    if (opposite != null) {
      final i = orders.indexWhere((x) => x.kind == opposite && x.lane == o.lane && x.target == o.target && x.other == o.other);
      if (i >= 0) {
        orders.removeAt(i);
        _save();
        return;
      }
      if (orders.any((x) => x.kind == o.kind && x.lane == o.lane && x.target == o.target && x.other == o.other)) return;
    }
    if (o.kind == DraftKind.move) orders.removeWhere((x) => x.kind == DraftKind.move && x.lane == o.lane && x.target == o.target);
    if (o.kind == DraftKind.edit || o.kind == DraftKind.remove) orders.removeWhere((x) => (x.kind == DraftKind.edit || x.kind == DraftKind.remove) && x.lane == o.lane && x.target == o.target);
    orders.add(o);
    _save();
  }

  void removeAt(int i) {
    orders.removeAt(i);
    _save();
  }

  void clear() {
    orders.clear();
    _save();
  }

  // What the graph draws on top of the plan.

  /// Pending links on lane steps: (waits on key, step key).
  List<(String, String)> get laneLinks => [
        for (final o in orders)
          if (o.kind == DraftKind.link && o.lane != null) (_keyOf(o.other!, o.lane!), o.key!),
      ];

  /// Pending unlinks on lane steps: (waits on key, step key).
  Set<String> get laneUnlinks => {
        for (final o in orders)
          if (o.kind == DraftKind.unlink && o.lane != null) '${_keyOf(o.other!, o.lane!)}>${o.key}',
      };

  /// Pending moves on lane steps: step key → the key it goes after (`lane/^` for the front).
  Map<String, String> get moved => {for (final o in orders) if (o.kind == DraftKind.move && o.key != null) o.key!: '${o.lane}/${o.other}'};

  Set<String> get removed => {for (final o in orders) if (o.kind == DraftKind.remove && o.key != null) o.key!};
  Set<String> get edited => {for (final o in orders) if (o.kind == DraftKind.edit && o.key != null) o.key!};

  /// Pending new lane steps: (the step they follow, their id).
  List<(String, String)> get added => [for (final o in orders) if (o.kind == DraftKind.add && o.key != null) (o.key!, o.newId ?? '?')];

  /// Pending roadmap links: (waits on, item).
  List<(String, String)> get roadmapLinks => [for (final o in orders) if (o.kind == DraftKind.link && o.lane == null) (o.other!, o.target)];
  Set<String> get roadmapTouched => {for (final o in orders) if (o.lane == null) o.target};
}

/// `lane-b/ID` → `b/ID`; a bare id is in [own] lane.
String _keyOf(String ref, String own) {
  final at = ref.indexOf('/');
  if (at < 0) return '$own/$ref';
  return '${ref.substring(0, at).replaceFirst('lane-', '')}/${ref.substring(at + 1)}';
}

/// A graph key as an `after:` reference: `b/ID` → `lane-b/ID`.
String refOf(String key) => 'lane-$key';
