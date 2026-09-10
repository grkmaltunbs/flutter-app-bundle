// A scripted `codex app-server`: answers the handshake by itself, keeps
// every line the session wrote, and lets a test emit the server's side.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/host/codex_engine.dart';
import 'package:kit_app/src/host/engine.dart';

import 'fake_claude.dart';

const fakeThread = '01a088b7-c601-7b61-8ddd-912b346fb574';
const fakeTurn = '01a088b7-c672-73b0-ad87-534027b687bd';

class FakeCodex implements Process {
  FakeCodex({this.threadId = fakeThread, this.turns = const [], this.autoTurn = true, this.holdThread = false, this.skills = const {'flutter-kit:kit-step': '/plugin/skills/kit-step/SKILL.md'}}) {
    _stdinCtrl.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(_wrote);
  }

  /// The thread the next thread/start or thread/resume answers with, and
  /// the turns a resume brings back.
  String threadId;
  final List<Object?> turns;

  /// Answer every turn/start with its turn id at once.
  final bool autoTurn;

  /// Hold the thread/start answer until [releaseThread] — a thread that
  /// takes its time.
  final bool holdThread;
  ({Object? id, Map<String, Object?> params, String method})? _heldThread;

  void releaseThread() {
    final h = _heldThread;
    if (h == null) return;
    _heldThread = null;
    _answerThread(h.id, h.method, h.params);
  }
  final Map<String, String> skills;

  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _stdinCtrl = StreamController<List<int>>();
  final _exit = Completer<int>();
  late final IOSink _stdin = IOSink(_stdinCtrl.sink);

  /// Every line the session wrote, decoded.
  final List<String> written = [];
  List<String> startedWith = const [];
  String? startedIn;

  /// Requests the session made, by method — the last id of each.
  final Map<String, int> requestIds = {};

  /// Every request as it came, method → params, in order.
  final List<({String method, Map<String, Object?> params, int id})> requests = [];

  /// The results the session sent to server requests, by request id.
  final Map<Object, Map<String, Object?>> results = {};

  int turnsStarted = 0;

  @override
  int get pid => 5151;
  @override
  Stream<List<int>> get stdout => _stdout.stream;
  @override
  Stream<List<int>> get stderr => _stderr.stream;
  @override
  IOSink get stdin => _stdin;
  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exit.isCompleted) _exit.complete(143);
    return true;
  }

  void exit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  void emit(String line) => _stdout.add(utf8.encode('$line\n'));
  void emitJson(Map<String, Object?> m) => emit(jsonEncode(m));
  void emitErr(String line) => _stderr.add(utf8.encode('$line\n'));

  /// A notification from the server.
  void notify(String method, Map<String, Object?> params) => emitJson({'method': method, 'params': params});

  /// A request from the server, with [id].
  void request(String method, Map<String, Object?> params, {Object id = 0}) => emitJson({'method': method, 'id': id, 'params': params});

  void _wrote(String line) {
    written.add(line);
    final m = jsonDecode(line) as Map;
    final method = m['method']?.toString();
    final id = m['id'];
    if (method == null) {
      if (id != null && m['result'] != null) results[id] = {for (final e in (m['result'] as Map).entries) e.key.toString(): e.value};
      return;
    }
    final params = {for (final e in ((m['params'] as Map?) ?? const {}).entries) e.key.toString(): e.value as Object?};
    if (id is int) {
      requestIds[method] = id;
      requests.add((method: method, params: params, id: id));
    }
    switch (method) {
      case 'initialize':
        emitJson({'id': id, 'result': {'userAgent': 'katya/0.153.4', 'codexHome': '/fake/.codex', 'platformFamily': 'unix', 'platformOs': 'macos'}});
      case 'model/list':
        emitJson({'id': id, 'result': {'data': [{'id': 'gpt-6-astra', 'hidden': false}, {'id': 'gpt-5.5', 'hidden': false}, {'id': 'gpt-reserve', 'hidden': true}]}});
      case 'skills/list':
        emitJson({'id': id, 'result': {'data': [{'cwd': params['cwds'], 'skills': [for (final e in skills.entries) {'name': e.key, 'path': e.value, 'enabled': true, 'description': '', 'scope': 'user'}], 'errors': []}]}});
      case 'account/rateLimits/read':
        emitJson({'id': id, 'result': {'rateLimits': {'limitId': 'codex', 'primary': {'usedPercent': 9, 'windowDurationMins': 10080, 'resetsAt': 1789577025}, 'secondary': null, 'planType': 'pro', 'rateLimitReachedType': null}}});
      case 'thread/start':
      case 'thread/resume':
        if (holdThread) {
          _heldThread = (id: id, params: params, method: method);
        } else {
          _answerThread(id, method, params);
        }
      case 'turn/start':
        turnsStarted++;
        if (autoTurn) emitJson({'id': id, 'result': {'turn': {'id': fakeTurn, 'items': [], 'itemsView': 'notLoaded', 'status': 'inProgress', 'error': null}}});
      case 'turn/interrupt':
        emitJson({'id': id, 'result': {}});
      case 'thread/compact/start':
        emitJson({'id': id, 'result': {}});
    }
  }

  void _answerThread(Object? id, String method, Map<String, Object?> params) => emitJson({
        'id': id,
        'result': {
          'thread': {'id': threadId, 'sessionId': threadId, 'model': 'gpt-6-astra', 'cwd': params['cwd'], 'cliVersion': '0.153.4', 'status': {'type': 'idle'}, 'turns': method == 'thread/resume' ? turns : []},
          'model': 'gpt-6-astra',
          'modelProvider': 'openai',
          'cwd': params['cwd'],
          'approvalPolicy': params['approvalPolicy'],
          'sandbox': {'type': 'workspaceWrite', 'writableRoots': [], 'networkAccess': false},
        },
      });

  /// Waits until the session has written [n] lines.
  Future<void> writtenLines(int n) async {
    for (var i = 0; i < 400 && written.length < n; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// Waits until [method] has been requested [times] times.
  Future<void> requested(String method, {int times = 1}) async {
    for (var i = 0; i < 400 && requests.where((r) => r.method == method).length < times; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// The last request of [method], decoded.
  Map<String, Object?> lastParams(String method) => requests.lastWhere((r) => r.method == method).params;

  /// A [ProcessStarter] that hands out this fake.
  ProcessStarter get starter => (bin, args, {workingDirectory, environment}) async {
        startedWith = args;
        startedIn = workingDirectory;
        return this;
      };

  // ---------------------------------------------------------- scripting

  /// A whole turn: the user echo, a streamed reply, its tokens, the end.
  void scriptTurn({String text = 'I am GPT-6-Astra.', String turnId = fakeTurn}) {
    notify('turn/started', {'threadId': threadId, 'turn': {'id': turnId, 'items': [], 'status': 'inProgress'}});
    notify('item/started', {'item': {'type': 'agentMessage', 'id': 'msg_1', 'text': '', 'phase': 'final_answer'}, 'threadId': threadId, 'turnId': turnId});
    notify('item/agentMessage/delta', {'threadId': threadId, 'turnId': turnId, 'itemId': 'msg_1', 'delta': text.substring(0, 4)});
    notify('item/agentMessage/delta', {'threadId': threadId, 'turnId': turnId, 'itemId': 'msg_1', 'delta': text.substring(4)});
    notify('item/completed', {'item': {'type': 'agentMessage', 'id': 'msg_1', 'text': text, 'phase': 'final_answer'}, 'threadId': threadId, 'turnId': turnId});
    notify('thread/tokenUsage/updated', {'threadId': threadId, 'turnId': turnId, 'tokenUsage': {'total': {'totalTokens': 19379, 'inputTokens': 19318, 'cachedInputTokens': 12928, 'outputTokens': 61}, 'last': {'totalTokens': 19379, 'inputTokens': 19318, 'cachedInputTokens': 12928, 'outputTokens': 61}, 'modelContextWindow': 258400}});
    notify('account/rateLimits/updated', {'rateLimits': {'limitId': 'codex', 'primary': {'usedPercent': 9, 'windowDurationMins': 10080, 'resetsAt': 1789577025}, 'secondary': null, 'planType': 'pro', 'rateLimitReachedType': null}});
    endTurn(turnId: turnId, text: text);
  }

  void endTurn({String turnId = fakeTurn, String status = 'completed', String? text, Map<String, Object?>? error}) => notify('turn/completed', {
        'threadId': threadId,
        'turn': {'id': turnId, 'items': text == null ? [] : [{'type': 'agentMessage', 'id': 'msg_1', 'text': text, 'phase': 'final_answer'}], 'itemsView': 'summary', 'status': status, 'error': error, 'startedAt': 1789000140, 'completedAt': 1789000146, 'durationMs': 6399},
      });

  void scriptQuestion({Object id = 0, String turnId = fakeTurn}) => request('item/tool/requestUserInput', {
        'threadId': threadId,
        'turnId': turnId,
        'itemId': 'call_q',
        'questions': [
          {'id': 'drink', 'header': 'Drink', 'question': 'Would you like tea or coffee?', 'isOther': true, 'isSecret': false, 'options': [{'label': 'Tea', 'description': 'Choose tea.'}, {'label': 'Coffee', 'description': 'Choose coffee.'}]},
        ],
        'isBlocking': false,
        'autoResolutionMs': null,
      }, id: id);

  void scriptCommandAsk({Object id = 0, String command = 'touch /tmp/kit-codex-1', String turnId = fakeTurn}) {
    notify('item/started', {'item': {'type': 'commandExecution', 'id': 'exec-1', 'command': "/bin/zsh -lc '$command'", 'cwd': startedIn, 'status': 'inProgress', 'commandActions': [{'type': 'unknown', 'command': command}]}, 'threadId': threadId, 'turnId': turnId});
    request('item/commandExecution/requestApproval', {
      'kind': 'command',
      'threadId': threadId,
      'turnId': turnId,
      'itemId': 'exec-1',
      'startedAtMs': 1789000221711,
      'command': "/bin/zsh -lc '$command'",
      'cwd': startedIn,
      'commandActions': [{'type': 'unknown', 'command': command}],
      'proposedExecpolicyAmendment': command.split(' '),
      'availableDecisions': ['accept', 'cancel'],
    }, id: id);
  }

  void scriptCommandDone({String status = 'completed', String turnId = fakeTurn, String? output}) => notify('item/completed', {
        'item': {'type': 'commandExecution', 'id': 'exec-1', 'command': "/bin/zsh -lc 'x'", 'cwd': startedIn, 'status': status, 'commandActions': [{'type': 'unknown', 'command': 'x'}], 'aggregatedOutput': output, 'exitCode': status == 'completed' ? 0 : null},
        'threadId': threadId,
        'turnId': turnId,
      });

  void scriptPlan({String plan = 'Append one line to README.md\n\n- Add the line.\n', String turnId = fakeTurn}) {
    notify('thread/settings/updated', {'threadId': threadId, 'threadSettings': {'cwd': startedIn, 'approvalPolicy': 'on-request', 'sandboxPolicy': {'type': 'readOnly'}, 'model': 'gpt-6-astra', 'collaborationMode': {'mode': 'plan', 'settings': {'model': 'gpt-6-astra'}}}});
    notify('item/started', {'item': {'type': 'plan', 'id': '$turnId-plan', 'text': ''}, 'threadId': threadId, 'turnId': turnId});
    notify('item/plan/delta', {'threadId': threadId, 'turnId': turnId, 'itemId': '$turnId-plan', 'delta': plan});
    notify('item/completed', {'item': {'type': 'plan', 'id': '$turnId-plan', 'text': plan}, 'threadId': threadId, 'turnId': turnId});
    endTurn(turnId: turnId);
  }
}

/// A session on a fake Codex, its record in [home]: the engine is set to
/// codex before the first start, so the record says so from the outset.
BridgeSession codexSession(FakeCodex fake, {required String dir, required String home, String? codexHome, List<FakeCodex>? spawned}) {
  final s = BridgeSession(
    dir: dir,
    starter: (bin, args, {workingDirectory, environment}) async {
      final f = spawned == null ? fake : (spawned.isEmpty ? fake : spawned.last);
      f.startedWith = args;
      f.startedIn = workingDirectory;
      return f;
    },
    shellPath: () async => '/fake/bin',
    home: home,
    codexHome: codexHome,
    readyGrace: Duration.zero,
    engines: (id) => id == 'codex'
        ? CodexEngine(findBinary: () async => '/fake/codex', versionOf: (_) async => '0.153.4', sandboxRoots: () async => ['/fake/flutter/bin/cache'], clientVersion: '0.0.0')
        : ClaudeEngine(findBinary: () async => '/fake/claude', versionOf: (_) async => '2.1.251', transcriptExists: (_) => true, readTranscript: (_) => null),
  );
  s.setEngine('codex');
  return s;
}

/// The Claude fake's session, wired through the same factory — for the
/// tests that switch engines.
BridgeSession eitherSession({required FakeClaude claude, required FakeCodex codex, required String dir, required String home}) => BridgeSession(
      dir: dir,
      starter: (bin, args, {workingDirectory, environment}) async {
        if (bin == '/fake/codex') {
          codex.startedWith = args;
          codex.startedIn = workingDirectory;
          return codex;
        }
        claude.startedWith = args;
        claude.startedIn = workingDirectory;
        return claude;
      },
      shellPath: () async => '/fake/bin',
      home: home,
      readyGrace: Duration.zero,
      engines: (id) => id == 'codex'
          ? CodexEngine(findBinary: () async => '/fake/codex', versionOf: (_) async => '0.153.4', sandboxRoots: () async => const [])
          : ClaudeEngine(findBinary: () async => '/fake/claude', versionOf: (_) async => '2.1.251', transcriptExists: (_) => true, readTranscript: (_) => null),
    );
