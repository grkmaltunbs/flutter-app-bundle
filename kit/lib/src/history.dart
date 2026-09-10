/// Session history — the pure half: one session as the record and the relay
/// keep it (`~/.flutter_kit/bridge/<slug>.json` → `sessions[]`,
/// `projects/{slug}/sessions/{id}`), and the CLI's own transcript file read
/// back into Deck rows when a session is resumed after the host forgot it.
///
/// The file is `~/.claude/projects/<cwd-key>/<id>.jsonl` — one JSON object
/// per line. On 2.1.261 (read 2026-09-09) the lines that matter are `user`
/// and `assistant`; the rest (`ai-title`, `mode`, `permission-mode`,
/// `queue-operation`, `last-prompt`, `atis-latch`, `attachment`, `system`,
/// `bridge-session`, `file-history-snapshot`) is bookkeeping. A `user` line
/// holds either the person's prompt (`message.content` a string, or a list
/// with `text` blocks) or a tool's result (`tool_result` blocks); a line
/// with `isMeta: true` is text the CLI injected, and `isSidechain: true`
/// is a subagent's own thread. An `assistant` line holds one content block
/// — `text`, `tool_use` or `thinking` — with `message.model`.
library;

import 'dart:convert';

import 'bridge.dart' show DeckMessage, DeckRole;

/// How many rows a resumed session brings back from its file.
const historyRows = 80;

/// One conversation of a project, as the record lists it. Mutable where
/// the bridge fills it in as the session goes: the first message, the
/// turn count, the model init reported, the end.
class SessionEntry {
  SessionEntry({required this.id, required this.startedAt, this.endedAt, this.firstMessage, this.turns = 0, this.model, this.mode, this.engine});

  factory SessionEntry.fromMap(Map<String, Object?> m) => SessionEntry(
        id: (m['id'] ?? '').toString(),
        startedAt: DateTime.tryParse(m['startedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        endedAt: DateTime.tryParse(m['endedAt']?.toString() ?? ''),
        firstMessage: _text(m['firstMessage']),
        turns: (m['turns'] as num?)?.toInt() ?? 0,
        model: _text(m['model']),
        mode: _text(m['mode']),
        engine: _text(m['engine']),
      );

  final String id;
  final DateTime startedAt;
  DateTime? endedAt;

  /// What the person first said — the line the list shows.
  String? firstMessage;

  /// Turns the person sent.
  int turns;
  String? model;
  String? mode;

  /// `codex` for a Codex thread; null (Claude) for every session from
  /// before the ENGINE notch. Resume runs the engine that made it.
  String? engine;
  bool get isCodex => engine == 'codex';

  Map<String, Object?> toMap() => {
        'id': id,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
        if (firstMessage != null) 'firstMessage': firstMessage,
        'turns': turns,
        if (model != null) 'model': model,
        if (mode != null) 'mode': mode,
        if (engine != null) 'engine': engine,
      };

  /// The line the list shows when nothing was said yet.
  String get title => firstMessage ?? '(nothing said yet)';
}

/// What the CLI's file says about a session, read once — to fill in an
/// entry the record knows nothing about (a session from before the list).
class TranscriptSummary {
  const TranscriptSummary({this.firstMessage, this.turns = 0, this.model, this.firstAt, this.lastAt});
  final String? firstMessage;
  final int turns;
  final String? model;
  final DateTime? firstAt;
  final DateTime? lastAt;
}

TranscriptSummary summarizeTranscript(Iterable<String> lines) {
  String? first;
  var turns = 0;
  String? model;
  DateTime? firstAt;
  DateTime? lastAt;
  for (final line in lines) {
    final m = _decode(line);
    if (m == null) continue;
    final at = DateTime.tryParse((m['timestamp'] ?? '').toString());
    if (at != null) {
      firstAt ??= at;
      lastAt = at;
    }
    if (m['isSidechain'] == true || m['isMeta'] == true) continue;
    switch (m['type']) {
      case 'user':
        final text = _promptText(m);
        if (text == null) break;
        turns++;
        first ??= clipLine(text, 120);
      case 'assistant':
        final msg = m['message'];
        if (msg is Map && msg['model'] != null) model = msg['model'].toString();
    }
  }
  return TranscriptSummary(firstMessage: first, turns: turns, model: model, firstAt: firstAt, lastAt: lastAt);
}

/// The last [last] Deck rows of a session's file: what the person said,
/// what the model answered, the tools it ran with their results. Row ids
/// start with `h` so they sort before the live `m…` rows that follow.
List<DeckMessage> restoreRows(Iterable<String> lines, {int last = historyRows}) {
  final rows = <DeckMessage>[];
  var seq = 0;
  DateTime at = DateTime.fromMillisecondsSinceEpoch(0);
  String nextId() => 'h${(seq++).toString().padLeft(5, '0')}';
  for (final line in lines) {
    final m = _decode(line);
    if (m == null || m['isSidechain'] == true || m['isMeta'] == true) continue;
    at = DateTime.tryParse((m['timestamp'] ?? '').toString()) ?? at;
    final msg = m['message'];
    if (msg is! Map) continue;
    final content = msg['content'];
    switch (m['type']) {
      case 'user':
        if (content is List) {
          for (final b in content) {
            if (b is! Map || b['type'] != 'tool_result') continue;
            final id = b['tool_use_id']?.toString();
            for (final r in rows.reversed) {
              if (r.role != DeckRole.tool || r.toolUseId != id) continue;
              r.toolResult = _clip(_resultText(b['content']), 600);
              r.isError = b['is_error'] == true;
              r.doneAt = at;
              break;
            }
          }
        }
        final text = _promptText(m);
        if (text != null) rows.add(DeckMessage(id: nextId(), role: DeckRole.user, text: text, at: at));
      case 'assistant':
        if (content is! List) break;
        for (final b in content) {
          if (b is! Map) continue;
          switch (b['type']) {
            case 'text':
              final text = (b['text'] ?? '').toString().trim();
              if (text.isNotEmpty) rows.add(DeckMessage(id: nextId(), role: DeckRole.assistant, text: text, at: at));
            case 'tool_use':
              final input = b['input'];
              rows.add(DeckMessage(
                id: nextId(),
                role: DeckRole.tool,
                text: '',
                at: at,
                toolName: (b['name'] ?? '').toString(),
                toolInput: input is Map ? {for (final e in input.entries) e.key.toString(): e.value} : const {},
                toolUseId: b['id']?.toString(),
              ));
          }
        }
    }
  }
  return rows.length <= last ? rows : rows.sublist(rows.length - last);
}

/// The person's words on a `user` line — null for a tool result, an empty
/// line, or text the CLI wrote itself. A slash command the file keeps as
/// `<command-name>/step</command-name><command-args>x</command-args>`
/// reads as `/step x`; the attachments trailer the bridge appends is cut.
String? _promptText(Map<Object?, Object?> m) {
  final msg = m['message'];
  if (msg is! Map) return null;
  final content = msg['content'];
  String raw;
  if (content is String) {
    raw = content;
  } else if (content is List) {
    final parts = <String>[];
    var images = 0;
    for (final b in content) {
      if (b is! Map) continue;
      if (b['type'] == 'text') parts.add((b['text'] ?? '').toString());
      if (b['type'] == 'image') images++;
    }
    if (parts.isEmpty && images == 0) return null;
    raw = [if (images > 0) '(${images == 1 ? 'an image' : '$images images'})', ...parts].join('\n');
  } else {
    return null;
  }
  var text = raw;
  final name = _tag(text, 'command-name');
  if (name != null) {
    final args = _tag(text, 'command-args') ?? '';
    text = args.trim().isEmpty ? name.trim() : '${name.trim()} ${args.trim()}';
  }
  text = text.replaceAll(RegExp(r'<system-reminder>[\s\S]*?</system-reminder>'), '');
  if (text.startsWith('<local-command-stdout>')) return null;
  final trailer = text.indexOf('\n\n--- attached');
  if (trailer > 0) text = text.substring(0, trailer);
  text = text.trim();
  return text.isEmpty ? null : text;
}

String? _tag(String s, String tag) {
  final m = RegExp('<$tag>([\\s\\S]*?)</$tag>').firstMatch(s);
  return m?.group(1);
}

String _resultText(Object? content) {
  if (content is String) return content;
  if (content is List) {
    return [for (final b in content) if (b is Map && b['type'] == 'text') (b['text'] ?? '').toString()].join('\n');
  }
  return '';
}

Map<Object?, Object?>? _decode(String line) {
  final l = line.trim();
  if (l.isEmpty) return null;
  try {
    final v = jsonDecode(l);
    return v is Map ? v : null;
  } on Object {
    return null;
  }
}

String? _text(Object? v) {
  final s = v?.toString() ?? '';
  return s.trim().isEmpty ? null : s;
}

String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1)}…';

/// The first line of [s], at most [n] characters.
String clipLine(String s, int n) {
  final first = s.trim().split('\n').first.trim();
  return first.length <= n ? first : '${first.substring(0, n - 1)}…';
}
