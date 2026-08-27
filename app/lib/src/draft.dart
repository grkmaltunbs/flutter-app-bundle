import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  String get _key => 'draft:$slug';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map;
      items.clear();
      steps.clear();
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
    await prefs.setString(_key, jsonEncode({'items': {for (final e in items.entries) e.key: e.value.toJson()}, 'steps': steps}));
    notifyListeners();
  }

  void _prune() {
    items.removeWhere((_, d) => d.isEmpty);
    steps.removeWhere((_, n) => n.trim().isEmpty);
  }

  ItemDraft item(String id) => items.putIfAbsent(id, ItemDraft.new);

  int get count {
    _prune();
    return items.length + steps.length;
  }

  Map<String, Object?> toBatch() {
    _prune();
    return {
      'sentAt': DateTime.now().toUtc().toIso8601String(),
      'entries': [
        for (final e in items.entries)
          {'kind': 'item', 'id': e.key, 'action': e.value.action, 'answer': e.value.answer, 'note': e.value.note.trim().isEmpty ? null : e.value.note.trim()},
        for (final e in steps.entries) {'kind': 'step', 'id': e.key, 'note': e.value.trim()},
      ],
    };
  }

  Future<void> clear() async {
    items.clear();
    steps.clear();
    await save();
  }
}
