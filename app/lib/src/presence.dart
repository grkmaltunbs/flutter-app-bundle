import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// The Mac's row in `hosts/`, keyed by its hostname made safe — the phone
/// finds it from the `machine` every project doc names.
String hostIdFor(String machine) {
  final s = machine.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'mac' : s;
}

/// The host beats every half minute; past this without one it counts as
/// gone — three missed beats, not one slow write.
const hostStaleAfter = Duration(seconds: 90);

enum HostState {
  /// No row yet — a host from before the heartbeat, or none at all.
  unknown,
  online,

  /// Beats stopped without a goodbye: a closed lid, a crash, a cable.
  unreachable,

  /// A clean quit said so.
  stopped,
}

/// What the phone says about the Mac, from its `hosts/{id}` row and the
/// phone's clock. Pure — a test hands in the row and the time.
class HostPresenceView {
  const HostPresenceView({required this.state, required this.line, this.seenAt});
  final HostState state;
  final String line;
  final DateTime? seenAt;

  /// Amber on the deck: the Mac cannot run anything right now.
  bool get warn => state == HostState.unreachable || state == HostState.stopped;

  /// A session the relay still calls live is lost until the Mac reports it.
  bool get gone => warn;

  static HostPresenceView from(Map<String, Object?>? doc, {required DateTime now}) {
    if (doc == null) return const HostPresenceView(state: HostState.unknown, line: 'Mac · no heartbeat yet');
    final raw = doc['seenAt'];
    final seen = raw is Timestamp ? raw.toDate() : (raw is DateTime ? raw : null);
    if (doc['stopping'] == true) return HostPresenceView(state: HostState.stopped, line: 'Mac stopped', seenAt: seen);
    if (seen == null) return const HostPresenceView(state: HostState.unknown, line: 'Mac · no heartbeat yet');
    final age = now.difference(seen);
    if (age <= hostStaleAfter) return HostPresenceView(state: HostState.online, line: 'Mac · ${agoShort(age)} ago', seenAt: seen);
    return HostPresenceView(state: HostState.unreachable, line: 'Mac unreachable since ${agoShort(age)}', seenAt: seen);
  }
}

/// `12 s`, `4 min`, `3 h`, `2 d` — never negative (a server clock ahead of
/// the phone's reads as now).
String agoShort(Duration d) {
  final s = max(0, d.inSeconds);
  if (s < 60) return '$s s';
  if (s < 3600) return '${s ~/ 60} min';
  if (s < 48 * 3600) return '${s ~/ 3600} h';
  return '${s ~/ 86400} d';
}
