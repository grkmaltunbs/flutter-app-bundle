import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_kit/kit.dart' show StepPlace;
import 'package:shared_preferences/shared_preferences.dart';

/// Ticks, answers and notes that have not been sent yet. Lives on the
/// device, survives a restart, and only leaves when the person presses
/// **Send to Claude** — the rule the whole app is built around.
class ItemDraft {
  ItemDraft({this.action, this.answer, this.note = ''});

  factory ItemDraft.fromJson(Map<String, Object?> m) => ItemDraft(
        action: m['action']?.toString(),
        answer: m['answer']?.toString(),
        note: (m['note'] ?? '').toString(),
      );

  String? action;
  String? answer;
  String note;

  bool get isEmpty => action == null && answer == null && note.trim().isEmpty;

  Map<String, Object?> toJson() => {'action': action, 'answer': answer, 'note': note};
}

class Draft extends ChangeNotifier {
  Draft(this.slug);

  final String slug;
  final Map<String, ItemDraft> items = {};
  final Map<String, String> steps = {};

  /// Bubbles dragged past others, in the order they were dragged; the
  /// constellation draws the order they make until Apply.
  final List<StepPlace> moves = [];

  String get _key => 'draft:$slug';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map;
      items.clear();
      steps.clear();
      moves.clear();
      for (final mv in (m['moves'] as List? ?? const [])) {
        if (mv is Map && mv['id'] != null) moves.add(StepPlace(mv['id'].toString(), mv['before']?.toString()));
      }
      for (final e in (m['items'] as Map? ?? const {}).entries) {
        items[e.key.toString()] = ItemDraft.fromJson({for (final x in (e.value as Map).entries) x.key.toString(): x.value});
      }
      for (final e in (m['steps'] as Map? ?? const {}).entries) {
        steps[e.key.toString()] = e.value.toString();
      }
    } on Object {
      // A draft we cannot read is a draft we drop; nothing was sent.
    }
    notifyListeners();
  }

  Future<void> save() async {
    _prune();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({'items': {for (final e in items.entries) e.key: e.value.toJson()}, 'steps': steps, 'moves': [for (final m in moves) m.toMap()]}));
    notifyListeners();
  }

  void _prune() {
    items.removeWhere((_, d) => d.isEmpty);
    steps.removeWhere((_, n) => n.trim().isEmpty);
  }

  ItemDraft item(String id) => items.putIfAbsent(id, ItemDraft.new);

  int get count {
    _prune();
    return items.length + steps.length + moves.length;
  }

  /// A bubble dropped past another: its last drag wins.
  Future<void> move(String id, String? before) {
    moves.removeWhere((m) => m.id == id);
    if (before != id) moves.add(StepPlace(id, before));
    return save();
  }

  /// Only moves — the host applies those by itself, so the bar reads Apply
  /// rather than Send to Claude.
  bool get hostOnly {
    _prune();
    return items.isEmpty && steps.isEmpty && moves.isNotEmpty;
  }

  Map<String, Object?> toBatch() {
    _prune();
    return {
      'sentAt': DateTime.now().toUtc().toIso8601String(),
      'entries': [
        for (final e in items.entries)
          {'kind': 'item', 'id': e.key, 'action': e.value.action, 'answer': e.value.answer, 'note': e.value.note.trim().isEmpty ? null : e.value.note.trim()},
        for (final e in steps.entries) {'kind': 'step', 'id': e.key, 'note': e.value.trim()},
        for (final m in moves) {'kind': 'reorder', 'id': m.id, 'before': m.before},
      ],
    };
  }

  Future<void> clear() async {
    items.clear();
    steps.clear();
    moves.clear();
    await save();
  }
}

/// The last transcript row the phone showed with the app in front, per
/// project — where the "since you last looked" line goes on the next
/// open. Lives on the device.
class LastSeen {
  static String _key(String slug) => 'seen:$slug';

  static Future<String?> load(String slug) async => (await SharedPreferences.getInstance()).getString(_key(slug));

  static Future<void> save(String slug, String id) async {
    await (await SharedPreferences.getInstance()).setString(_key(slug), id);
  }
}
