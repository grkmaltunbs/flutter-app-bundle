/// The plan as plain JSON — what the host mirrors to Firestore and the phone
/// rebuilds a [Plan] from. Every document is exactly the `toMap()` of one
/// file, so the phone runs the same [Graph] over the same data and derives
/// the same states; nothing about state travels.
library;

import 'dart:convert';

import 'model.dart';

/// Stable JSON for change detection: keys sorted at every level, so two
/// snapshots of the same file encode identically.
String stableJson(Object? v) => jsonEncode(_sorted(v));

Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return [for (final x in v) _sorted(x)];
  return v;
}

/// Firestore refuses a few things YAML allows: `null` map values are fine,
/// but a list directly inside a list is not, and field names must not be
/// empty. [planDoc], [stepDoc] and [itemDoc] are already safe for the model
/// as it stands; this guard is for `meta:` passthrough.
Object? firestoreSafe(Object? v) {
  if (v is Map) {
    return {for (final e in v.entries) if (e.key.toString().isNotEmpty) e.key.toString(): firestoreSafe(e.value)};
  }
  if (v is List) {
    return [for (final x in v) x is List ? {'list': firestoreSafe(x)} : firestoreSafe(x)];
  }
  return v;
}

Map<String, Object?> manifestDoc(Manifest m) => firestoreSafe(m.toMap()) as Map<String, Object?>;
Map<String, Object?> stepDoc(Step s) => firestoreSafe(s.toMap()) as Map<String, Object?>;
Map<String, Object?> itemDoc(Item i) => firestoreSafe(i.toMap()) as Map<String, Object?>;

/// Rebuilds a [Plan] from documents read back — the inverse of the three
/// `*Doc` functions. Documents that fail to parse are skipped, so one bad
/// write cannot blank the phone.
Plan planFromDocs({required Map<String, Object?> manifest, required Iterable<Map<String, Object?>> steps, required Iterable<Map<String, Object?>> items}) {
  final st = <Step>[];
  for (final m in steps) {
    if (m['id'] is! String || (m['id'] as String).isEmpty) continue;
    try {
      st.add(Step.fromMap(m));
    } on Object {
      // skipped
    }
  }
  final it = <Item>[];
  for (final m in items) {
    if (m['id'] is! String || (m['id'] as String).isEmpty) continue;
    try {
      it.add(Item.fromMap(m));
    } on Object {
      // skipped
    }
  }
  return Plan(manifest: Manifest.fromMap(manifest), steps: st, items: it);
}
