/// The Codex engine — how the host talks to `codex app-server --stdio`,
/// and how what comes back becomes the same [Transcript] the Claude bridge
/// fills.
///
/// The app-server speaks JSON-RPC 2.0, one object per line, both ways: the
/// host sends requests (`initialize`, `thread/start`, `turn/start`, …) and
/// answers the server's own requests (an approval, a question); the server
/// streams notifications (`item/started`, `item/agentMessage/delta`,
/// `turn/completed`, …). It is the protocol the Codex desktop app and the
/// VS Code extension speak; the binary prints its own schema
/// (`codex app-server generate-json-schema`) and marks the command
/// experimental. Captured on Codex [codexProvenOn], 2026-09-10 — the
/// spike table in app/DESIGN.md.
///
/// Pure Dart: no dart:io. [CodexTranslator] turns lines into
/// [BridgeEvent]s and builds the lines to write; the host owns the process.
library;

import 'dart:convert';

import 'bridge.dart';
import 'history.dart' show historyRows;

/// The Codex CLI version the shapes below were captured on.
const codexProvenOn = '0.153.4';

/// The question tool sits behind this feature flag on 0.153.4 (under
/// development, off by default); the host turns it on for every session.
const codexQuestionFeature = 'default_mode_request_user_input';

/// The command line the host starts.
List<String> codexArgs({List<String> enable = const [codexQuestionFeature]}) => ['app-server', '--stdio', for (final f in enable) ...['--enable', f]];

/// Where the ChatGPT app keeps its Codex when `codex` is not on PATH.
const codexInChatGptApp = '/Applications/ChatGPT.app/Contents/Resources/codex';

/// How a MODE notch reads on Codex: an approval policy, a sandbox, and the
/// collaboration mode. `default` is `untrusted` — only read-only commands
/// run without asking, so a `touch` raises a card as it does on Claude
/// (proven 2026-09-10); `acceptEdits` is Codex's own `on-request`, where
/// edits inside the workspace and sandboxed commands run and only an
/// escape asks; `bypassPermissions` is `never` with the sandbox off; `plan`
/// is the plan collaboration mode over a read-only sandbox.
class CodexPolicy {
  const CodexPolicy({required this.approval, required this.sandbox, required this.collaboration});
  final String approval;
  final String sandbox;
  final String collaboration;

  /// The `sandboxPolicy` of a `turn/start` — the same choice, spelled as
  /// the turn takes it.
  Map<String, Object?> get sandboxPolicy => switch (sandbox) {
        'danger-full-access' => {'type': 'dangerFullAccess'},
        'read-only' => {'type': 'readOnly'},
        _ => {'type': 'workspaceWrite'},
      };
}

CodexPolicy codexPolicyFor(String mode) => switch (knownMode(mode)) {
      'plan' => const CodexPolicy(approval: 'on-request', sandbox: 'read-only', collaboration: 'plan'),
      'acceptEdits' => const CodexPolicy(approval: 'on-request', sandbox: 'workspace-write', collaboration: 'default'),
      'bypassPermissions' => const CodexPolicy(approval: 'never', sandbox: 'danger-full-access', collaboration: 'default'),
      _ => const CodexPolicy(approval: 'untrusted', sandbox: 'workspace-write', collaboration: 'default'),
    };

/// The notch a thread's settings read as (`thread/settings/updated`).
String codexModeFor({String? approval, String? sandboxType, String? collaboration}) {
  if (collaboration == 'plan') return 'plan';
  if (approval == 'never' || sandboxType == 'dangerFullAccess') return 'bypassPermissions';
  if (approval == 'untrusted') return 'default';
  return 'acceptEdits';
}

/// The command as the row shows it: Codex wraps every command in a login
/// shell (`/bin/zsh -lc '…'`); the words inside are what the user asked
/// to allow.
String codexPlainCommand(String command) {
  final m = RegExp(r'''^/bin/(?:zsh|bash|sh) -lc (['"])([\s\S]*)\1$''').firstMatch(command.trim());
  if (m == null) return command;
  return m.group(2)!;
}

/// The message the model reads as a declined command's result.
const codexDeclinedNote = 'declined — the user did not allow it';

/// One server request the host still owes an answer to: which kind, the
/// JSON-RPC id to answer on, and what the answer needs (the amendment an
/// Always carries, the question ids).
class CodexAsk {
  const CodexAsk({required this.kind, required this.rpcId, this.amendment, this.questionIds = const {}, this.proposed});

  /// `command`, `fileChange`, `question`, `permissions`.
  final String kind;
  final Object rpcId;
  final List<String>? amendment;

  /// Question text → the id the answer goes back under.
  final Map<String, String> questionIds;
  final Map<String, Object?>? proposed;
}

/// One rule of `~/.codex/rules/default.rules`, as Codex writes an Always:
/// `prefix_rule(pattern=["touch", "/tmp/x"], decision="allow")`.
class ExecPolicyRule {
  const ExecPolicyRule(this.pattern, {this.decision = 'allow'});
  final List<String> pattern;
  final String decision;

  /// The line Codex wrote (proven 2026-09-10, 0.153.4).
  String get line => 'prefix_rule(pattern=${jsonEncode(pattern).replaceAll(',', ', ')}, decision="$decision")';

  /// Null for a line that is not a prefix rule.
  static ExecPolicyRule? parse(String line) {
    final m = RegExp(r'^\s*prefix_rule\(\s*pattern\s*=\s*(\[.*?\])\s*,\s*decision\s*=\s*"([a-z_]+)"\s*\)\s*$').firstMatch(line);
    if (m == null) return null;
    try {
      final list = jsonDecode(m.group(1)!);
      if (list is! List) return null;
      return ExecPolicyRule([for (final e in list) e.toString()], decision: m.group(2)!);
    } on FormatException {
      return null;
    }
  }

  /// The rules of a file's text, in order.
  static List<ExecPolicyRule> parseAll(String text) => [for (final l in text.split('\n')) if (parse(l) case final r?) r];

  /// The file without every rule whose pattern is [pattern]; null when
  /// none was there.
  static String? without(String text, List<String> pattern) {
    final lines = text.split('\n');
    final kept = <String>[];
    var removed = false;
    for (final l in lines) {
      final r = parse(l);
      if (r != null && _same(r.pattern, pattern)) {
        removed = true;
        continue;
      }
      kept.add(l);
    }
    return removed ? kept.join('\n') : null;
  }

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The two halves of the app-server protocol, stateful: the requests the
/// host sent (to read their responses), the thread and turn at hand, the
/// items as they stream, the asks the server is waiting on. [feed] turns
/// one line into the events the transcript takes; the `…Line` methods
/// build what the host writes.
class CodexTranslator {
  CodexTranslator({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _salt = (_now().millisecondsSinceEpoch % 46656).toRadixString(36).padLeft(3, '0');
  }

  final DateTime Function() _now;

  /// Three letters of this process's start: the server's request ids
  /// count from 0 in every process, and a resumed thread keeps its id, so
  /// an answer to an ask of the last process must not land on this one's.
  late final String _salt;
  int _seq = 0;
  final Map<int, ({String method, Map<String, Object?> params})> _sent = {};

  String? threadId;
  String? turnId;
  String? model;
  String? cwd;
  String? cliVersion;

  /// The notch the last `turn/start` ran under — what the transcript
  /// reports as its permission mode.
  String mode = 'default';

  /// MCP server → status, as `mcpServer/startupStatus/updated` reports.
  final Map<String, String> mcp = {};

  /// What `model/list` reported: the ids the dial offers.
  List<String> models = const [];

  /// What `skills/list` reported for the folder: name → SKILL.md path, so
  /// `/step` can go as the skill it names.
  Map<String, String> skills = {};

  /// The rules files the last `thread/start` said it loaded, by name.
  List<String> rules = const [];

  /// Requests the server made that the host has not answered.
  final Map<String, CodexAsk> asks = {};

  /// Lines the translator itself wants written — an answer to a server
  /// request nobody can act on (an elicitation form, a token refresh).
  final List<String> outbox = [];

  final Map<String, Map<String, Object?>> _items = {};
  final Map<String, StringBuffer> _output = {};
  String _finalText = '';
  String _planText = '';
  String? _turnError;
  Usage? _last;
  int _turnOutput = 0;
  int? contextWindow;
  bool _clearing = false;
  int _turnsInThread = 0;
  List<DeckMessage> _restored = [];

  /// The plan the last plan-mode turn wrote — the plan card's text.
  String get planText => _planText;

  /// The rows a resume brought back, once.
  List<DeckMessage> takeRestored() {
    final r = _restored;
    _restored = [];
    return r;
  }

  // ------------------------------------------------------------ writing

  String request(String method, Map<String, Object?> params) {
    final id = ++_seq;
    _sent[id] = (method: method, params: params);
    return jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
  }

  String notify(String method, [Map<String, Object?> params = const {}]) => jsonEncode({'jsonrpc': '2.0', 'method': method, 'params': params});

  String reply(Object id, Map<String, Object?> result) => jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result});

  String replyError(Object id, String message, {int code = -32000}) => jsonEncode({'jsonrpc': '2.0', 'id': id, 'error': {'code': code, 'message': message}});

  String initializeLine({String name = 'katya', String version = ''}) =>
      request('initialize', {'clientInfo': {'name': name, 'title': 'K.A.T.Y.A', 'version': version}, 'capabilities': {'experimentalApi': true}});

  String initializedLine() => notify('initialized');

  String modelListLine() => request('model/list', {});

  String skillsListLine(String cwd) => request('skills/list', {'cwds': [cwd]});

  String rateLimitsLine() => request('account/rateLimits/read', {});

  /// A fresh thread, or [resume] by id. [clear] is `/clear`: a fresh
  /// thread whose response the transcript reads as a reset with a turn
  /// of nothing — the loop's clean context per step.
  String threadStartLine({required String cwd, required String mode, String? model, String? developerInstructions, String? resume, bool clear = false}) {
    final p = codexPolicyFor(mode);
    this.cwd = cwd;
    this.mode = knownMode(mode);
    _clearing = clear;
    final params = <String, Object?>{
      'cwd': cwd,
      'approvalPolicy': p.approval,
      'sandbox': p.sandbox,
      if (model != null) 'model': model,
      if (developerInstructions != null) 'developerInstructions': developerInstructions,
      if (clear) 'sessionStartSource': 'clear',
    };
    return resume != null ? request('thread/resume', {...params, 'threadId': resume}) : request('thread/start', params);
  }

  /// One turn: the text (with a skill mention first when [skill] names one
  /// the folder has, and every image by path), and the notch, model and
  /// effort it runs under — all per turn on Codex, nothing restarted.
  /// `collaborationMode` is not in the 0.153.4 schema but the server takes
  /// it (proven 2026-09-10: the plan streamed as `plan` deltas and no
  /// file changed).
  /// [writableRoots] widen a workspace-write sandbox: the Flutter SDK's
  /// cache and the pub cache (the SDK's `dart` writes an engine stamp on
  /// every run — sandboxed, `kit` died on it, 2026-09-10) and the plugin's
  /// own `kit/` folder (its compiled binary).
  String turnStartLine({required String text, List<String> imagePaths = const [], String? skill, required String mode, String? model, String? effort, List<String> writableRoots = const []}) {
    final p = codexPolicyFor(mode);
    this.mode = knownMode(mode);
    final skillPath = skill == null ? null : skills[skill];
    final input = <Map<String, Object?>>[
      if (skill != null && skillPath != null) {'type': 'skill', 'name': skill, 'path': skillPath},
      for (final path in imagePaths) {'type': 'localImage', 'path': path},
      {'type': 'text', 'text': text},
    ];
    _finalText = '';
    _planText = '';
    _turnError = null;
    _turnOutput = 0;
    return request('turn/start', {
      'threadId': threadId,
      'input': input,
      'approvalPolicy': p.approval,
      'sandboxPolicy': {...p.sandboxPolicy, if (p.sandbox == 'workspace-write' && writableRoots.isNotEmpty) 'writableRoots': writableRoots},
      'collaborationMode': {
        'mode': p.collaboration,
        'settings': {'model': model ?? this.model ?? ''},
      },
      if (model != null) 'model': model,
      if (effort != null) 'effort': effort,
    });
  }

  String? interruptLine() => threadId == null || turnId == null ? null : request('turn/interrupt', {'threadId': threadId, 'turnId': turnId});

  String? compactLine() => threadId == null ? null : request('thread/compact/start', {'threadId': threadId});

  /// The answer to a pending ask, as the JSON-RPC result the server waits
  /// on. Null for an ask that is not the server's — the plan card the
  /// host raised itself — or one already answered.
  String? answerLine(Ask ask, AskAnswer a) {
    final c = asks.remove(ask.requestId);
    if (c == null) return null;
    switch (c.kind) {
      case 'command':
        if (!a.allowed) return reply(c.rpcId, {'decision': 'decline'});
        if (a.appliesAlways && c.amendment != null) {
          return reply(c.rpcId, {
            'decision': {
              'acceptWithExecpolicyAmendment': {'execpolicy_amendment': c.amendment},
            },
          });
        }
        return reply(c.rpcId, {'decision': 'accept'});
      case 'fileChange':
        return reply(c.rpcId, {'decision': a.allowed ? 'accept' : 'decline'});
      case 'question':
        final updated = a.response['updatedInput'];
        final given = updated is Map ? updated['answers'] : null;
        final answers = <String, Object?>{};
        for (final e in c.questionIds.entries) {
          final v = given is Map ? given[e.key]?.toString() : null;
          answers[e.value] = {'answers': v == null || v.isEmpty ? <String>[] : [v]};
        }
        return reply(c.rpcId, {'answers': answers});
      case 'permissions':
        if (!a.allowed) return replyError(c.rpcId, 'The user declined.');
        return reply(c.rpcId, {'permissions': c.proposed ?? const {}, 'scope': 'turn'});
    }
    return replyError(c.rpcId, 'not handled');
  }

  // ------------------------------------------------------------ reading

  /// One stdout line → the events it means. Empty for a line that is not
  /// protocol, or one nothing on the Deck reads.
  List<BridgeEvent> feed(String line) {
    final s = line.trim();
    if (s.isEmpty || !s.startsWith('{')) return const [];
    final Object? raw;
    try {
      raw = jsonDecode(s);
    } on FormatException {
      return const [];
    }
    if (raw is! Map) return const [];
    final m = _map(raw);
    final method = m['method']?.toString();
    if (method != null) {
      final params = _map(m['params']);
      return m.containsKey('id') ? _serverRequest(m['id']!, method, params) : _notification(method, params);
    }
    if (m.containsKey('id')) return _response(m['id'], m['result'], m['error']);
    return const [];
  }

  List<BridgeEvent> _response(Object? id, Object? result, Object? error) {
    final sent = id is num ? _sent.remove(id.toInt()) : null;
    if (sent == null) return const [];
    final method = sent.method;
    if (error != null) {
      final e = _map(error);
      final message = (e['message'] ?? 'error').toString();
      final events = <BridgeEvent>[ControlResponseEvent(requestId: method, ok: false, error: message)];
      if (method == 'turn/start') {
        // The turn never opened on the server: close it on the Deck.
        events.add(ResultEvent(subtype: 'error', sessionId: threadId ?? '', isError: true, text: message));
      }
      return events;
    }
    final r = _map(result);
    switch (method) {
      case 'thread/start':
      case 'thread/resume':
        final thread = _map(r['thread']);
        threadId = (thread['id'] ?? '').toString();
        model = _text(r['model']) ?? _text(thread['model']);
        cliVersion = _text(thread['cliVersion']) ?? cliVersion;
        turnId = null;
        _turnsInThread = (thread['turns'] as List? ?? const []).length;
        if (method == 'thread/resume') _restored = rowsFromTurns(thread['turns'] as List? ?? const []);
        rules = [for (final s in (r['instructionSources'] as List? ?? const [])) s.toString().split('/').last];
        final init = InitEvent(sessionId: threadId!, model: model, permissionMode: mode, cwd: _text(thread['cwd']) ?? cwd, mcpServers: Map.of(mcp), rules: rules);
        if (_clearing) {
          _clearing = false;
          return [const ResetEvent(), init, ResultEvent(subtype: 'success', sessionId: threadId!, numTurns: 0)];
        }
        return [init];
      case 'turn/start':
        turnId = _text(_map(r['turn'])['id']) ?? turnId;
        return const [];
      case 'turn/interrupt':
        return [ControlResponseEvent(requestId: method, ok: true, response: r)];
      case 'model/list':
        models = [
          for (final m in (r['data'] as List? ?? const []))
            if (m is Map && m['hidden'] != true && m['id'] != null) m['id'].toString(),
        ];
        return const [];
      case 'skills/list':
        final found = <String, String>{};
        for (final entry in (r['data'] as List? ?? const [])) {
          if (entry is! Map) continue;
          for (final sk in (entry['skills'] as List? ?? const [])) {
            if (sk is Map && sk['name'] != null && sk['path'] != null && sk['enabled'] != false) found[sk['name'].toString()] = sk['path'].toString();
          }
        }
        skills = found;
        return const [];
      case 'account/rateLimits/read':
        return [rateLimitEvent(_map(r['rateLimits']))];
      default:
        return const [];
    }
  }

  List<BridgeEvent> _serverRequest(Object id, String method, Map<String, Object?> p) {
    final rid = 'cx-${(threadId ?? 'thread').substring(0, 8)}-$_salt-$id';
    switch (method) {
      case 'item/commandExecution/requestApproval':
        final actions = p['commandActions'] as List? ?? const [];
        final first = actions.isNotEmpty && actions.first is Map ? _map(actions.first) : const <String, Object?>{};
        final command = _text(first['command']) ?? codexPlainCommand((p['command'] ?? '').toString());
        final amendment = p['proposedExecpolicyAmendment'] is List ? [for (final t in p['proposedExecpolicyAmendment'] as List) t.toString()] : null;
        final reason = _text(p['reason']);
        asks[rid] = CodexAsk(kind: 'command', rpcId: id, amendment: amendment);
        return [
          AskEvent(Ask(
            requestId: rid,
            toolName: 'Bash',
            toolUseId: (p['itemId'] ?? '').toString(),
            input: {'command': command, if (reason != null) 'description': reason},
            at: _now(),
            description: reason,
            displayName: 'Command',
            suggestions: amendment == null ? const [] : [{'type': 'execpolicy', 'pattern': amendment}],
            engine: 'codex',
          )),
        ];
      case 'item/fileChange/requestApproval':
        final itemId = (p['itemId'] ?? '').toString();
        final item = _items[itemId] ?? const <String, Object?>{};
        final changes = _changes(item);
        final reason = _text(p['reason']);
        asks[rid] = CodexAsk(kind: 'fileChange', rpcId: id);
        return [
          AskEvent(Ask(
            requestId: rid,
            toolName: 'apply_patch',
            toolUseId: itemId,
            input: {if (changes.paths.isNotEmpty) 'file_path': changes.paths.first, 'paths': changes.paths},
            at: _now(),
            description: reason,
            displayName: 'Edit',
            engine: 'codex',
          )..diff = changes.diff),
        ];
      case 'item/tool/requestUserInput':
        final ids = <String, String>{};
        final questions = <Map<String, Object?>>[];
        for (final q in (p['questions'] as List? ?? const [])) {
          if (q is! Map) continue;
          final qm = _map(q);
          final text = (qm['question'] ?? '').toString();
          ids[text] = (qm['id'] ?? text).toString();
          questions.add({
            'question': text,
            'header': (qm['header'] ?? '').toString(),
            'multiSelect': false,
            'options': [
              for (final o in (qm['options'] as List? ?? const []))
                if (o is Map) {'label': (o['label'] ?? '').toString(), 'description': (o['description'] ?? '').toString()},
            ],
          });
        }
        asks[rid] = CodexAsk(kind: 'question', rpcId: id, questionIds: ids);
        return [
          AskEvent(Ask(
            requestId: rid,
            toolName: 'AskUserQuestion',
            toolUseId: (p['itemId'] ?? '').toString(),
            input: {'questions': questions},
            at: _now(),
            displayName: 'Question',
            requiresUserInteraction: true,
            engine: 'codex',
          )),
        ];
      case 'item/permissions/requestApproval':
        final proposed = _map(p['permissions']);
        asks[rid] = CodexAsk(kind: 'permissions', rpcId: id, proposed: proposed);
        return [
          AskEvent(Ask(
            requestId: rid,
            toolName: 'permissions',
            toolUseId: (p['itemId'] ?? '').toString(),
            input: {'permissions': proposed},
            at: _now(),
            description: _text(p['reason']) ?? 'The session asks for more than its sandbox allows.',
            displayName: 'Permissions',
            engine: 'codex',
          )),
        ];
      default:
        // An elicitation form, a token refresh, an attestation, a dynamic
        // tool: nothing on a phone can answer these — say so at once so
        // the turn goes on.
        outbox.add(replyError(id, 'not supported by K.A.T.Y.A', code: -32601));
        return [OtherEvent('request', method)];
    }
  }

  List<BridgeEvent> _notification(String method, Map<String, Object?> p) {
    switch (method) {
      case 'turn/started':
        turnId = _text(_map(p['turn'])['id']) ?? turnId;
        return const [];
      case 'item/started':
        final item = _map(p['item']);
        final id = (item['id'] ?? '').toString();
        _items[id] = item;
        return _itemStarted(item, id);
      case 'item/completed':
        final item = _map(p['item']);
        final id = (item['id'] ?? '').toString();
        _items[id] = item;
        return _itemCompleted(item, id);
      case 'item/agentMessage/delta':
      case 'item/plan/delta':
        final delta = (p['delta'] ?? '').toString();
        if (method == 'item/plan/delta') _planText += delta;
        return [TextDeltaEvent(delta)];
      case 'item/commandExecution/outputDelta':
        _output.putIfAbsent((p['itemId'] ?? '').toString(), StringBuffer.new).write(p['delta'] ?? '');
        return const [];
      case 'turn/completed':
        final turn = _map(p['turn']);
        final status = (turn['status'] ?? '').toString();
        final err = _map(turn['error']);
        final failed = status == 'failed';
        final message = _text(err['message']) ?? _turnError;
        final events = <BridgeEvent>[];
        if (failed && message != null && _isPool(err)) events.add(RateLimitEvent(status: 'rejected', resetsAt: _lastReset));
        events.add(ResultEvent(
          subtype: status,
          sessionId: threadId ?? '',
          stopReason: status,
          numTurns: 1,
          durationMs: (turn['durationMs'] as num?)?.toInt() ?? 0,
          isError: failed,
          text: failed ? (message ?? 'The turn failed.') : _finalText,
          usage: _last == null ? null : Usage(input: _last!.input, cacheCreation: _last!.cacheCreation, cacheRead: _last!.cacheRead, output: _turnOutput),
          contextWindows: {if (contextWindow != null && model != null) model!: contextWindow!},
        ));
        _turnsInThread++;
        if (mode == 'plan' && _planText.trim().isNotEmpty && !failed && status != 'interrupted') {
          // The plan is the turn's plan item: on the Deck it is the card
          // Claude's ExitPlanMode makes — the host raised it, nobody on
          // the server waits for the answer.
          events.add(AskEvent(Ask(
            requestId: 'plan-${turnId ?? _turnsInThread}',
            toolName: 'ExitPlanMode',
            toolUseId: '${turnId ?? _turnsInThread}-plan',
            input: {'plan': _planText.trim()},
            at: _now(),
            displayName: 'Plan',
            requiresUserInteraction: true,
            engine: 'codex',
          )));
        }
        turnId = null;
        return events;
      case 'thread/tokenUsage/updated':
        final u = _map(p['tokenUsage']);
        final last = _map(u['last']);
        final cached = (last['cachedInputTokens'] as num?)?.toInt() ?? 0;
        final input = (last['inputTokens'] as num?)?.toInt() ?? 0;
        final output = (last['outputTokens'] as num?)?.toInt() ?? 0;
        _last = Usage(input: input - cached, cacheCreation: (last['cacheWriteInputTokens'] as num?)?.toInt() ?? 0, cacheRead: cached, output: output);
        _turnOutput += output;
        contextWindow = (u['modelContextWindow'] as num?)?.toInt() ?? contextWindow;
        return [UsageEvent(_last!, contextWindow: contextWindow)];
      case 'account/rateLimits/updated':
        return [rateLimitEvent(_map(p['rateLimits']))];
      case 'thread/settings/updated':
        final s = _map(p['threadSettings']);
        model = _text(s['model']) ?? model;
        final approval = s['approvalPolicy'];
        mode = codexModeFor(
          approval: approval is String ? approval : 'on-request',
          sandboxType: _text(_map(s['sandboxPolicy'])['type']),
          collaboration: _text(_map(s['collaborationMode'])['mode']),
        );
        return threadId == null ? const [] : [InitEvent(sessionId: threadId!, model: model, permissionMode: mode, cwd: cwd, mcpServers: Map.of(mcp), rules: rules)];
      case 'mcpServer/startupStatus/updated':
        final name = _text(p['name']);
        if (name != null) mcp[name] = (p['status'] ?? '').toString();
        return const [];
      case 'thread/compacted':
        return [const CompactEvent(trigger: 'manual')];
      case 'error':
        final e = _map(p['error']);
        final message = (e['message'] ?? 'error').toString();
        if (p['willRetry'] != true) _turnError = message;
        if (_isPool(e)) return [RateLimitEvent(status: 'rejected', resetsAt: _lastReset), OtherEvent('error', message)];
        return [OtherEvent('error', message)];
      case 'warning':
      case 'deprecationNotice':
      case 'configWarning':
        return [OtherEvent(method, _text(p['message']))];
      default:
        return const [];
    }
  }

  DateTime? _lastReset;

  /// A refused pool: the account's usage limit, a rate limit.
  bool _isPool(Map<String, Object?> err) {
    final info = err['codexErrorInfo'];
    return info == 'usageLimitExceeded' || info == 'rateLimitExceeded';
  }

  /// `account/rateLimits/updated` → the pool as the arcs read it: the
  /// five-hour window is the one lasting 300 minutes, the weekly the one
  /// lasting a week — a Pro plan reported only a weekly window on
  /// 2026-09-10, so either may be missing.
  RateLimitEvent rateLimitEvent(Map<String, Object?> r) {
    PoolWindow? five;
    PoolWindow? week;
    for (final key in const ['primary', 'secondary']) {
      final w = r[key];
      if (w is! Map) continue;
      final wm = _map(w);
      final mins = (wm['windowDurationMins'] as num?)?.toInt();
      final resets = wm['resetsAt'];
      final window = PoolWindow(
        utilization: ((wm['usedPercent'] as num?)?.toDouble() ?? 0) / 100,
        resetsAt: resets is num ? DateTime.fromMillisecondsSinceEpoch(resets.toInt() * 1000, isUtc: true) : null,
      );
      if (mins != null && mins <= 300) {
        five ??= window;
      } else {
        week ??= window;
      }
    }
    final reached = r['rateLimitReachedType'] != null || r['spendControlReached'] == true;
    final resets = five?.resetsAt ?? week?.resetsAt;
    _lastReset = resets;
    return RateLimitEvent(status: reached ? 'rejected' : 'allowed', rateLimitType: five != null ? 'five_hour' : 'seven_day', resetsAt: resets, fiveHour: five, sevenDay: week);
  }

  List<BridgeEvent> _itemStarted(Map<String, Object?> item, String id) {
    switch (item['type']) {
      case 'commandExecution':
        final actions = item['commandActions'] as List? ?? const [];
        final first = actions.isNotEmpty && actions.first is Map ? _map(actions.first) : const <String, Object?>{};
        final command = _text(first['command']) ?? codexPlainCommand((item['command'] ?? '').toString());
        return [AssistantEvent([ContentBlock.toolUse(toolUseId: id, toolName: 'Bash', toolInput: {'command': command})])];
      case 'fileChange':
        final c = _changes(item);
        return [AssistantEvent([ContentBlock.toolUse(toolUseId: id, toolName: 'apply_patch', toolInput: {if (c.paths.isNotEmpty) 'file_path': c.paths.first, 'paths': c.paths}, diff: c.diff)])];
      case 'mcpToolCall':
        final server = (item['server'] ?? '').toString();
        final tool = (item['tool'] ?? '').toString();
        return [AssistantEvent([ContentBlock.toolUse(toolUseId: id, toolName: 'mcp__${server}__$tool', toolInput: _map(item['arguments']))])];
      case 'dynamicToolCall':
        return [AssistantEvent([ContentBlock.toolUse(toolUseId: id, toolName: (item['tool'] ?? 'tool').toString(), toolInput: _map(item['arguments']))])];
      case 'webSearch':
        return [AssistantEvent([ContentBlock.toolUse(toolUseId: id, toolName: 'WebSearch', toolInput: {'query': (item['query'] ?? '').toString()})])];
      case 'imageView':
        return [AssistantEvent([ContentBlock.toolUse(toolUseId: id, toolName: 'Read', toolInput: {'file_path': (item['path'] ?? '').toString()})])];
      case 'imageGeneration':
        return [AssistantEvent([ContentBlock.toolUse(toolUseId: id, toolName: 'imageGeneration', toolInput: {if (item['revisedPrompt'] != null) 'prompt': item['revisedPrompt']})])];
      case 'collabAgentToolCall':
        final tool = (item['tool'] ?? 'agent').toString();
        final prompt = _text(item['prompt']);
        final receivers = [for (final r in (item['receiverThreadIds'] as List? ?? const [])) r.toString()];
        for (final r in receivers) {
          _agents[r] = id;
        }
        return [AssistantEvent([ContentBlock.toolUse(toolUseId: id, toolName: 'Agent', toolInput: {'subagent_type': tool, 'description': prompt ?? tool, if (prompt != null) 'prompt': prompt, if (item['model'] != null) 'model': item['model']})])];
      case 'subAgentActivity':
        final agent = _agents[(item['agentThreadId'] ?? '').toString()];
        if (agent == null) return const [];
        final kind = (item['kind'] ?? '').toString();
        return [TaskEvent(kind: kind == 'completed' ? 'done' : kind == 'started' ? 'started' : 'progress', toolUseId: agent, status: kind == 'completed' ? 'completed' : kind)];
      case 'contextCompaction':
        return [const StatusEvent(status: 'compacting')];
      default:
        return const [];
    }
  }

  /// A subagent's thread → the `Agent` row it runs under.
  final Map<String, String> _agents = {};

  List<BridgeEvent> _itemCompleted(Map<String, Object?> item, String id) {
    final status = (item['status'] ?? '').toString();
    switch (item['type']) {
      case 'agentMessage':
        final text = (item['text'] ?? '').toString();
        if (item['phase'] == 'final_answer' || _finalText.isEmpty) _finalText = text;
        return [AssistantEvent([ContentBlock.text(text)])];
      case 'plan':
        final text = (item['text'] ?? '').toString();
        _planText = text;
        if (_finalText.isEmpty) _finalText = text;
        return [AssistantEvent([ContentBlock.text(text)])];
      case 'commandExecution':
        final out = _text(item['aggregatedOutput']) ?? _output.remove(id)?.toString() ?? '';
        final code = (item['exitCode'] as num?)?.toInt();
        final content = status == 'declined' ? codexDeclinedNote : (out.isEmpty ? (code == null ? status : 'exit $code') : out);
        return [ToolResultEvent(toolUseId: id, content: content, isError: status == 'failed' || status == 'declined' || (code != null && code != 0))];
      case 'fileChange':
        final c = _changes(item);
        final content = status == 'declined' ? codexDeclinedNote : [for (final p in c.paths) '${c.kinds[p] ?? 'update'} $p'].join('\n');
        return [ToolResultEvent(toolUseId: id, content: content.isEmpty ? status : content, isError: status == 'failed' || status == 'declined')];
      case 'mcpToolCall':
        final err = _map(item['error']);
        final result = _map(item['result']);
        final content = err.isNotEmpty ? (err['message'] ?? 'failed').toString() : _mcpText(result);
        return [ToolResultEvent(toolUseId: id, content: content, isError: status == 'failed' || err.isNotEmpty)];
      case 'dynamicToolCall':
        final items = item['contentItems'] as List? ?? const [];
        return [ToolResultEvent(toolUseId: id, content: items.isEmpty ? status : items.map((e) => e is Map ? (e['text'] ?? jsonEncode(e)).toString() : e.toString()).join('\n'), isError: status == 'failed' || item['success'] == false)];
      case 'webSearch':
        final results = item['results'] as List? ?? const [];
        return [ToolResultEvent(toolUseId: id, content: results.isEmpty ? 'searched' : '${results.length} result${results.length == 1 ? '' : 's'}')];
      case 'imageView':
        return [ToolResultEvent(toolUseId: id, content: 'viewed')];
      case 'imageGeneration':
        return [ToolResultEvent(toolUseId: id, content: _text(item['savedPath']) ?? status, isError: item['failure'] != null)];
      case 'collabAgentToolCall':
        final states = _map(item['agentsStates']);
        final lines = [for (final e in states.entries) '${e.key}: ${_map(e.value)['status'] ?? ''}${_text(_map(e.value)['message']) == null ? '' : ' — ${_map(e.value)['message']}'}'];
        return [ToolResultEvent(toolUseId: id, content: lines.isEmpty ? status : lines.join('\n'), isError: status == 'failed')];
      case 'contextCompaction':
        return [const CompactEvent(trigger: 'auto')];
      default:
        return const [];
    }
  }

  static String _mcpText(Map<String, Object?> result) {
    final content = result['content'];
    if (content is List) {
      final texts = [for (final c in content) if (c is Map && c['text'] != null) c['text'].toString()];
      if (texts.isNotEmpty) return texts.join('\n');
    }
    final structured = result['structuredContent'];
    if (structured != null) return jsonEncode(structured);
    return result.isEmpty ? 'done' : jsonEncode(result);
  }

  static ({List<String> paths, Map<String, String> kinds, String? diff}) _changes(Map<String, Object?> item) {
    final paths = <String>[];
    final kinds = <String, String>{};
    final diffs = <String>[];
    for (final c in (item['changes'] as List? ?? const [])) {
      if (c is! Map) continue;
      final cm = _map(c);
      final path = (cm['path'] ?? '').toString();
      if (path.isEmpty) continue;
      paths.add(path);
      kinds[path] = (_map(cm['kind'])['type'] ?? 'update').toString();
      final d = _text(cm['diff']);
      if (d != null) diffs.add(paths.length > 1 || !d.startsWith('---') ? '--- a/$path\n+++ b/$path\n$d' : d);
    }
    return (paths: paths, kinds: kinds, diff: diffs.isEmpty ? null : diffs.join('\n'));
  }

  /// The tail of a resumed thread as Deck rows — what the person said,
  /// what the model answered, the commands and edits with their results.
  /// Row ids start with `h`, ahead of the live `m…` rows.
  static List<DeckMessage> rowsFromTurns(List<Object?> turns, {int last = historyRows}) {
    final rows = <DeckMessage>[];
    var seq = 0;
    String nextId() => 'h${(seq++).toString().padLeft(5, '0')}';
    for (final t in turns) {
      if (t is! Map) continue;
      final turn = _map(t);
      final started = (turn['startedAt'] as num?)?.toInt();
      final at = started == null ? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(started * 1000, isUtc: true);
      for (final i in (turn['items'] as List? ?? const [])) {
        if (i is! Map) continue;
        final item = _map(i);
        final id = (item['id'] ?? '').toString();
        switch (item['type']) {
          case 'userMessage':
            final text = [for (final c in (item['content'] as List? ?? const [])) if (c is Map && c['type'] == 'text') (c['text'] ?? '').toString()].join('\n');
            if (text.trim().isNotEmpty) rows.add(DeckMessage(id: nextId(), role: DeckRole.user, text: text, at: at));
          case 'agentMessage':
          case 'plan':
            final text = (item['text'] ?? '').toString();
            if (text.trim().isNotEmpty) rows.add(DeckMessage(id: nextId(), role: DeckRole.assistant, text: text, at: at));
          case 'commandExecution':
            final actions = item['commandActions'] as List? ?? const [];
            final first = actions.isNotEmpty && actions.first is Map ? _map(actions.first) : const <String, Object?>{};
            final command = _text(first['command']) ?? codexPlainCommand((item['command'] ?? '').toString());
            final status = (item['status'] ?? '').toString();
            final out = _text(item['aggregatedOutput']) ?? status;
            rows.add(DeckMessage(id: nextId(), role: DeckRole.tool, text: '', at: at, toolName: 'Bash', toolInput: {'command': command}, toolUseId: id, toolResult: _clip(out, 600), isError: status == 'failed' || status == 'declined', doneAt: at));
          case 'fileChange':
            final c = _changes(item);
            final status = (item['status'] ?? '').toString();
            rows.add(DeckMessage(id: nextId(), role: DeckRole.tool, text: '', at: at, toolName: 'apply_patch', toolInput: {if (c.paths.isNotEmpty) 'file_path': c.paths.first, 'paths': c.paths}, toolUseId: id, toolResult: c.paths.join('\n'), isError: status == 'failed' || status == 'declined', diff: c.diff, doneAt: at));
          case 'mcpToolCall':
            final status = (item['status'] ?? '').toString();
            rows.add(DeckMessage(id: nextId(), role: DeckRole.tool, text: '', at: at, toolName: 'mcp__${item['server']}__${item['tool']}', toolInput: _map(item['arguments']), toolUseId: id, toolResult: _clip(_mcpText(_map(item['result'])), 600), isError: status == 'failed', doneAt: at));
        }
      }
    }
    return rows.length > last ? rows.sublist(rows.length - last) : rows;
  }
}

Map<String, Object?> _map(Object? v) => v is Map ? {for (final e in v.entries) e.key.toString(): e.value} : <String, Object?>{};

String? _text(Object? v) {
  final s = v?.toString() ?? '';
  return s.trim().isEmpty ? null : s;
}

String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1)}…';
