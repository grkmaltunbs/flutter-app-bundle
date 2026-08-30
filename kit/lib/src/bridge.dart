/// The bridge protocol — how the host talks to `claude -p` over stdio, and
/// the transcript both the host window and the phone render.
///
/// `claude -p --input-format stream-json --output-format stream-json
/// --permission-prompt-tool stdio` reads one JSON object per line on stdin
/// and writes one per line on stdout. A permission prompt or an
/// `AskUserQuestion` arrives as a `control_request`, and the session waits
/// on it until a `control_response` goes back — so an ask that nobody
/// answers is a session that hangs. This is the protocol Anthropic's Agent
/// SDK speaks to the CLI; it is not a documented CLI contract. Captured on
/// Claude Code [bridgeProvenOn], 2026-08-30 — the table in app/DESIGN.md.
///
/// Pure Dart: no dart:io. The host feeds process lines in; the phone
/// rebuilds the same [Transcript] from the relay.
library;

import 'dart:convert';

import 'snapshot.dart' show stableJson;

/// The Claude Code version the shapes below were captured on. The host
/// shows the version it actually started beside this one.
const bridgeProvenOn = '2.1.251';

/// The command line the host starts. `--session-id` names a fresh session;
/// `resume: true` reattaches to [sessionId] instead. `--verbose` is not a
/// choice: without it the CLI refuses `--output-format stream-json`.
List<String> bridgeArgs({required String sessionId, bool resume = false, String? model, String permissionMode = 'default'}) => [
      '-p',
      '--verbose',
      '--input-format', 'stream-json',
      '--output-format', 'stream-json',
      '--include-partial-messages',
      '--replay-user-messages',
      '--permission-prompt-tool', 'stdio',
      '--permission-mode', permissionMode,
      resume ? '--resume' : '--session-id', sessionId,
      if (model != null) ...['--model', model],
    ];

String encodeUserMessage(String text) => jsonEncode({
      'type': 'user',
      'message': {'role': 'user', 'content': text},
    });

String encodeControlResponse(String requestId, Map<String, Object?> response) => jsonEncode({
      'type': 'control_response',
      'response': {'subtype': 'success', 'request_id': requestId, 'response': response},
    });

// ---------------------------------------------------------------- asks

/// One option of one question in an `AskUserQuestion`.
class AskOption {
  const AskOption({required this.label, this.description = ''});
  final String label;
  final String description;
  Map<String, Object?> toMap() => {'label': label, 'description': description};
}

class AskQuestion {
  const AskQuestion({required this.question, required this.header, required this.options, this.multiSelect = false});

  factory AskQuestion.fromMap(Map<String, Object?> m) => AskQuestion(
        question: (m['question'] ?? '').toString(),
        header: (m['header'] ?? '').toString(),
        multiSelect: m['multiSelect'] == true,
        options: [
          for (final o in (m['options'] as List? ?? const []))
            if (o is Map) AskOption(label: (o['label'] ?? '').toString(), description: (o['description'] ?? '').toString()),
        ],
      );

  final String question;
  final String header;
  final List<AskOption> options;
  final bool multiSelect;
}

/// A `control_request` of subtype `can_use_tool`: a permission prompt, or
/// an `AskUserQuestion` (which Claude Code routes through the same channel).
class Ask {
  Ask({
    required this.requestId,
    required this.toolName,
    required this.toolUseId,
    required this.input,
    required this.at,
    this.description,
    this.displayName,
    this.blockedPath,
    this.suggestions = const [],
    this.requiresUserInteraction = false,
  });

  factory Ask.fromMap(Map<String, Object?> m) => Ask(
        requestId: (m['requestId'] ?? '').toString(),
        toolName: (m['toolName'] ?? '').toString(),
        toolUseId: (m['toolUseId'] ?? '').toString(),
        input: _map(m['input']),
        at: DateTime.tryParse((m['at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
        description: m['description']?.toString(),
        displayName: m['displayName']?.toString(),
        blockedPath: m['blockedPath']?.toString(),
        suggestions: [for (final s in (m['suggestions'] as List? ?? const [])) if (s is Map) _map(s)],
        requiresUserInteraction: m['requiresUserInteraction'] == true,
      );

  final String requestId;
  final String toolName;
  final String toolUseId;
  final Map<String, Object?> input;
  final DateTime at;
  final String? description;
  final String? displayName;
  final String? blockedPath;

  /// The CLI's `permission_suggestions`: rules that, written to
  /// `.claude/settings.json`, would stop this request from asking again.
  final List<Map<String, Object?>> suggestions;
  final bool requiresUserInteraction;

  bool get isQuestion => toolName == 'AskUserQuestion';

  /// What "this session" remembers: the tool and its exact input. A second
  /// request with the same key is the same request.
  String get key => '$toolName ${stableJson(input)}';

  List<AskQuestion> get questions => [
        for (final q in (input['questions'] as List? ?? const []))
          if (q is Map) AskQuestion.fromMap(_map(q)),
      ];

  /// What the card shows in one line: the command for Bash, the question
  /// for a question, the tool and its input otherwise.
  String get summary {
    if (isQuestion) return questions.map((q) => q.question).join(' · ');
    if (toolName == 'Bash') return (input['command'] ?? '').toString();
    final path = input['file_path'] ?? input['path'] ?? input['pattern'];
    return path != null ? '$toolName $path' : '$toolName ${_clip(jsonEncode(input), 120)}';
  }

  Map<String, Object?> toMap() => {
        'requestId': requestId,
        'toolName': toolName,
        'toolUseId': toolUseId,
        'input': input,
        'at': at.toUtc().toIso8601String(),
        if (description != null) 'description': description,
        if (displayName != null) 'displayName': displayName,
        if (blockedPath != null) 'blockedPath': blockedPath,
        'suggestions': suggestions,
        'requiresUserInteraction': requiresUserInteraction,
      };
}

/// The user's answer to an [Ask], as the `response` of a control_response.
class AskAnswer {
  const AskAnswer._(this.response, this.summary, this.allowed);

  /// Let the tool run with its input as proposed.
  factory AskAnswer.allow(Ask ask) => AskAnswer._({'behavior': 'allow', 'updatedInput': ask.input}, 'Allowed', true);

  /// Allow, and hand the CLI its own `permission_suggestions` back as
  /// `updatedPermissions` — it writes the rule to the settings file it
  /// named, exactly as "Yes, and don't ask again" does in the terminal.
  factory AskAnswer.always(Ask ask) =>
      AskAnswer._({'behavior': 'allow', 'updatedInput': ask.input, 'updatedPermissions': ask.suggestions}, 'Allowed, always', true);

  /// Refuse; [message] is what the model reads as the tool result.
  factory AskAnswer.deny(String message) => AskAnswer._({'behavior': 'deny', 'message': message}, 'Denied', false);

  /// Answer an `AskUserQuestion`: question text → chosen label(s). Several
  /// labels for a multi-select question are joined with ", ".
  factory AskAnswer.answers(Ask ask, Map<String, String> answers) =>
      AskAnswer._({'behavior': 'allow', 'updatedInput': {...ask.input, 'answers': answers}}, answers.values.join(' · '), true);

  /// An answer that travelled through the relay.
  factory AskAnswer.fromMap(Map<String, Object?> m) => AskAnswer._(_map(m['response']), (m['summary'] ?? '').toString(), m['allowed'] == true);

  final Map<String, Object?> response;
  final String summary;
  final bool allowed;

  bool get appliesAlways => response['updatedPermissions'] != null;

  Map<String, Object?> toMap() => {'response': response, 'summary': summary, 'allowed': allowed};
}

// -------------------------------------------------------------- events

sealed class BridgeEvent {
  const BridgeEvent();
}

/// `system` / `init` — the session exists.
class InitEvent extends BridgeEvent {
  const InitEvent({required this.sessionId, this.model, this.permissionMode, this.cwd, this.tools = const []});
  final String sessionId;
  final String? model;
  final String? permissionMode;
  final String? cwd;
  final List<String> tools;
}

/// A piece of the assistant's text, as it is written.
class TextDeltaEvent extends BridgeEvent {
  const TextDeltaEvent(this.text);
  final String text;
}

/// A finished content block of the assistant's message.
class ContentBlock {
  const ContentBlock.text(this.text)
      : toolUseId = null,
        toolName = null,
        toolInput = null;
  const ContentBlock.toolUse({required this.toolUseId, required this.toolName, required this.toolInput}) : text = null;
  final String? text;
  final String? toolUseId;
  final String? toolName;
  final Map<String, Object?>? toolInput;
  bool get isToolUse => toolUseId != null;
}

class AssistantEvent extends BridgeEvent {
  const AssistantEvent(this.blocks);
  final List<ContentBlock> blocks;
}

/// The result of a tool call, as the model sees it.
class ToolResultEvent extends BridgeEvent {
  const ToolResultEvent({required this.toolUseId, required this.content, this.isError = false});
  final String toolUseId;
  final String content;
  final bool isError;
}

/// `--replay-user-messages`: our own message, acknowledged.
class UserEchoEvent extends BridgeEvent {
  const UserEchoEvent(this.text);
  final String text;
}

class AskEvent extends BridgeEvent {
  const AskEvent(this.ask);
  final Ask ask;
}

/// The turn ended.
class ResultEvent extends BridgeEvent {
  const ResultEvent({required this.subtype, required this.sessionId, this.stopReason, this.numTurns = 0, this.durationMs = 0, this.isError = false, this.text = ''});
  final String subtype;
  final String sessionId;
  final String? stopReason;
  final int numTurns;
  final int durationMs;
  final bool isError;
  final String text;
}

/// The subscription's pool, as the CLI reports it.
class RateLimitEvent extends BridgeEvent {
  const RateLimitEvent({required this.status, this.rateLimitType, this.resetsAt, this.overageStatus});
  final String status;
  final String? rateLimitType;
  final DateTime? resetsAt;
  final String? overageStatus;
}

/// Anything else — kept by type so a new shape shows up in the log.
class OtherEvent extends BridgeEvent {
  const OtherEvent(this.type, this.subtype);
  final String type;
  final String? subtype;
}

/// One stdout line → one event, or null for a blank or non-JSON line.
BridgeEvent? parseBridgeLine(String line) {
  final s = line.trim();
  if (s.isEmpty || !s.startsWith('{')) return null;
  final Object? raw;
  try {
    raw = jsonDecode(s);
  } on FormatException {
    return null;
  }
  if (raw is! Map) return null;
  final m = _map(raw);
  final type = (m['type'] ?? '').toString();
  switch (type) {
    case 'system':
      final sub = (m['subtype'] ?? '').toString();
      if (sub == 'init') {
        return InitEvent(
          sessionId: (m['session_id'] ?? '').toString(),
          model: m['model']?.toString(),
          permissionMode: m['permissionMode']?.toString(),
          cwd: m['cwd']?.toString(),
          tools: [for (final t in (m['tools'] as List? ?? const [])) t.toString()],
        );
      }
      return OtherEvent(type, sub);
    case 'stream_event':
      final ev = _map(m['event']);
      if (ev['type'] == 'content_block_delta') {
        final d = _map(ev['delta']);
        if (d['type'] == 'text_delta') return TextDeltaEvent((d['text'] ?? '').toString());
      }
      return OtherEvent(type, ev['type']?.toString());
    case 'assistant':
      final msg = _map(m['message']);
      final blocks = <ContentBlock>[];
      for (final c in (msg['content'] as List? ?? const [])) {
        if (c is! Map) continue;
        final cm = _map(c);
        if (cm['type'] == 'text') {
          blocks.add(ContentBlock.text((cm['text'] ?? '').toString()));
        } else if (cm['type'] == 'tool_use') {
          blocks.add(ContentBlock.toolUse(toolUseId: (cm['id'] ?? '').toString(), toolName: (cm['name'] ?? '').toString(), toolInput: _map(cm['input'])));
        }
      }
      return AssistantEvent(blocks);
    case 'user':
      final msg = _map(m['message']);
      final content = msg['content'];
      if (content is String) return UserEchoEvent(content);
      if (content is List) {
        for (final c in content) {
          if (c is Map && c['type'] == 'tool_result') {
            return ToolResultEvent(toolUseId: (c['tool_use_id'] ?? '').toString(), content: _contentText(c['content']), isError: c['is_error'] == true);
          }
        }
        return UserEchoEvent(content.whereType<Map>().map((c) => (c['text'] ?? '').toString()).join());
      }
      return OtherEvent(type, null);
    case 'control_request':
      final req = _map(m['request']);
      if (req['subtype'] != 'can_use_tool') return OtherEvent(type, req['subtype']?.toString());
      return AskEvent(Ask(
        requestId: (m['request_id'] ?? '').toString(),
        toolName: (req['tool_name'] ?? '').toString(),
        toolUseId: (req['tool_use_id'] ?? '').toString(),
        input: _map(req['input']),
        at: DateTime.now(),
        description: req['description']?.toString(),
        displayName: req['display_name']?.toString(),
        blockedPath: req['blocked_path']?.toString(),
        suggestions: [for (final s in (req['permission_suggestions'] as List? ?? const [])) if (s is Map) _map(s)],
        requiresUserInteraction: req['requires_user_interaction'] == true,
      ));
    case 'result':
      return ResultEvent(
        subtype: (m['subtype'] ?? '').toString(),
        sessionId: (m['session_id'] ?? '').toString(),
        stopReason: m['stop_reason']?.toString(),
        numTurns: (m['num_turns'] as num?)?.toInt() ?? 0,
        durationMs: (m['duration_ms'] as num?)?.toInt() ?? 0,
        isError: m['is_error'] == true,
        text: (m['result'] ?? '').toString(),
      );
    case 'rate_limit_event':
      final info = _map(m['rate_limit_info']);
      final resets = (info['resetsAt'] as num?)?.toInt();
      return RateLimitEvent(
        status: (info['status'] ?? '').toString(),
        rateLimitType: info['rateLimitType']?.toString(),
        resetsAt: resets == null ? null : DateTime.fromMillisecondsSinceEpoch(resets * 1000, isUtc: true),
        overageStatus: info['overageStatus']?.toString(),
      );
    default:
      return OtherEvent(type, m['subtype']?.toString());
  }
}

String _contentText(Object? content) {
  if (content is String) return content;
  if (content is List) return content.whereType<Map>().map((c) => (c['text'] ?? '').toString()).join('\n');
  return content?.toString() ?? '';
}

/// The thread a scoped message belongs to: `item:<id>` or `step:<id>`.
/// Null when [about] names neither.
String? threadKey(Map<String, Object?>? about) {
  if (about == null) return null;
  final item = about['item']?.toString();
  if (item != null && item.isNotEmpty) return 'item:$item';
  final step = about['step']?.toString();
  if (step != null && step.isNotEmpty) return 'step:$step';
  return null;
}

// ---------------------------------------------------------- transcript

enum DeckRole { user, assistant, tool, note }

/// One row of the deck. Mutable while it streams or its tool runs.
class DeckMessage {
  DeckMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.at,
    this.toolName,
    this.toolInput,
    this.toolUseId,
    this.toolResult,
    this.isError = false,
    this.streaming = false,
    this.about,
  });

  factory DeckMessage.fromMap(Map<String, Object?> m) => DeckMessage(
        id: (m['id'] ?? '').toString(),
        role: DeckRole.values.firstWhere((r) => r.name == m['role'], orElse: () => DeckRole.note),
        text: (m['text'] ?? '').toString(),
        at: DateTime.tryParse((m['at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
        toolName: m['toolName']?.toString(),
        toolInput: m['toolInput'] is Map ? _map(m['toolInput']) : null,
        toolUseId: m['toolUseId']?.toString(),
        toolResult: m['toolResult']?.toString(),
        isError: m['isError'] == true,
        streaming: m['streaming'] == true,
        about: m['about'] is Map ? _map(m['about']) : null,
      );

  final String id;
  final DeckRole role;
  String text;
  final DateTime at;
  final String? toolName;
  final Map<String, Object?>? toolInput;
  final String? toolUseId;
  String? toolResult;
  bool isError;
  bool streaming;

  /// `{item: id}` or `{step: id}` when the message is about one thing.
  final Map<String, Object?>? about;

  /// One line for a tool row: the command for Bash, the path for a file
  /// tool, the tool and its input otherwise.
  String get toolSummary {
    final input = toolInput ?? const {};
    final name = toolName ?? '';
    if (name == 'Bash') return (input['command'] ?? '').toString();
    final path = input['file_path'] ?? input['path'] ?? input['pattern'] ?? input['query'];
    if (path != null) return '$name · $path';
    if (name == 'AskUserQuestion') return 'asked you a question';
    return input.isEmpty ? name : '$name · ${_clip(jsonEncode(input), 100)}';
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'role': role.name,
        'text': text,
        'at': at.toUtc().toIso8601String(),
        if (toolName != null) 'toolName': toolName,
        if (toolInput != null) 'toolInput': toolInput,
        if (toolUseId != null) 'toolUseId': toolUseId,
        if (toolResult != null) 'toolResult': toolResult,
        'isError': isError,
        'streaming': streaming,
        if (about != null) 'about': about,
      };
}

/// The conversation with one session: what was said, what ran, what is
/// being asked. [apply] folds stdout events in; [answer] produces the
/// stdin line for a pending ask. No I/O here.
class Transcript {
  final List<DeckMessage> messages = [];
  Ask? pending;
  String? sessionId;
  String? model;
  String? permissionMode;
  RateLimitEvent? pool;
  ResultEvent? lastResult;

  /// True between a user message and the `result` that ends the turn.
  bool turnOpen = false;

  /// How many text deltas streamed in — the live test's proof that
  /// `--include-partial-messages` was honoured.
  int deltasSeen = 0;

  DeckMessage? _streaming;
  int _seq = 0;
  DateTime Function() now = DateTime.now;

  /// The scope of the turn now open: everything the session says or runs
  /// until the `result` belongs to the same item or step the user asked
  /// about. Cleared when the turn ends.
  Map<String, Object?>? _about;

  /// The last scope a user message carried — it outlives the turn, so a
  /// plan edit that lands just after the result still finds its thread.
  Map<String, Object?>? lastAbout;

  String _nextId() => 'm${(_seq++).toString().padLeft(5, '0')}';

  DeckMessage addUser(String text, {Map<String, Object?>? about}) {
    final m = DeckMessage(id: _nextId(), role: DeckRole.user, text: text, at: now(), about: about);
    messages.add(m);
    turnOpen = true;
    _about = about;
    lastAbout = about;
    return m;
  }

  DeckMessage addNote(String text) {
    final m = DeckMessage(id: _nextId(), role: DeckRole.note, text: text, at: now());
    messages.add(m);
    return m;
  }

  void apply(BridgeEvent e) {
    switch (e) {
      case InitEvent():
        sessionId = e.sessionId;
        model = e.model;
        permissionMode = e.permissionMode;
      case TextDeltaEvent():
        deltasSeen++;
        final s = _streaming ??= _open();
        s.text += e.text;
      case AssistantEvent():
        for (final b in e.blocks) {
          if (b.isToolUse) {
            _closeStreaming();
            messages.add(DeckMessage(id: _nextId(), role: DeckRole.tool, text: '', at: now(), toolName: b.toolName, toolInput: b.toolInput, toolUseId: b.toolUseId, about: _about));
          } else {
            final text = b.text ?? '';
            final s = _streaming;
            if (s != null) {
              // The final block is authoritative; the deltas were its draft.
              s.text = text;
              s.streaming = false;
              _streaming = null;
            } else if (text.isNotEmpty) {
              messages.add(DeckMessage(id: _nextId(), role: DeckRole.assistant, text: text, at: now(), about: _about));
            }
          }
        }
      case ToolResultEvent():
        for (final m in messages.reversed) {
          if (m.role == DeckRole.tool && m.toolUseId == e.toolUseId) {
            m.toolResult = _clip(e.content, 600);
            m.isError = e.isError;
            break;
          }
        }
      case AskEvent():
        _closeStreaming();
        pending = e.ask;
      case ResultEvent():
        _closeStreaming();
        turnOpen = false;
        _about = null;
        lastResult = e;
        if (e.isError && e.text.isNotEmpty) addNote(e.text);
      case RateLimitEvent():
        pool = e;
      case UserEchoEvent():
      case OtherEvent():
        break;
    }
  }

  /// Answers [pending]: records what was decided as a note ([note] replaces
  /// the default wording) and returns the stdin line. Throws [StateError]
  /// when nothing is pending.
  String answer(AskAnswer a, {String? note}) {
    final ask = pending;
    if (ask == null) throw StateError('nothing is pending');
    pending = null;
    addNote(note ?? (ask.isQuestion ? 'Answered: ${a.summary}' : '${a.summary}: ${_clip(ask.summary, 160)}'));
    return encodeControlResponse(ask.requestId, a.response);
  }

  DeckMessage _open() {
    final m = DeckMessage(id: _nextId(), role: DeckRole.assistant, text: '', at: now(), streaming: true, about: _about);
    messages.add(m);
    return m;
  }

  void _closeStreaming() {
    final s = _streaming;
    if (s == null) return;
    s.streaming = false;
    _streaming = null;
    if (s.text.isEmpty) messages.remove(s);
  }
}

Map<String, Object?> _map(Object? v) => v is Map ? {for (final e in v.entries) e.key.toString(): e.value} : <String, Object?>{};

String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1)}…';
