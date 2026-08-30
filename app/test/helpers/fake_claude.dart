// A scripted `claude`: the test emits stdout lines and reads what the
// session wrote to stdin.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kit_app/src/host/bridge_session.dart';

class FakeClaude implements Process {
  FakeClaude() {
    _stdinCtrl.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(written.add);
  }

  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _stdinCtrl = StreamController<List<int>>();
  final _exit = Completer<int>();
  late final IOSink _stdin = IOSink(_stdinCtrl.sink);

  /// Every line the session wrote, decoded.
  final List<String> written = [];
  List<String> startedWith = const [];
  String? startedIn;

  @override
  int get pid => 4242;
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

  /// The process dies with [code] — a crash, from the session's side.
  void exit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  void emit(String line) => _stdout.add(utf8.encode('$line\n'));
  void emitJson(Map<String, Object?> m) => emit(jsonEncode(m));
  void emitErr(String line) => _stderr.add(utf8.encode('$line\n'));

  /// Waits until the session has written [n] lines.
  Future<void> writtenLines(int n) async {
    for (var i = 0; i < 200 && written.length < n; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// A [ProcessStarter] that hands out this fake.
  ProcessStarter get starter => (bin, args, {workingDirectory, environment}) async {
        startedWith = args;
        startedIn = workingDirectory;
        return this;
      };
}

/// A session wired to a [FakeClaude]: no real binary, shell or home folder,
/// so it also runs inside a widget test's fake clock.
BridgeSession fakeSession(FakeClaude fake, {required String dir, required String home}) => BridgeSession(
      dir: dir,
      starter: fake.starter,
      findBinary: () async => '/fake/claude',
      versionOf: (_) async => '2.1.251',
      shellPath: () async => '/fake/bin',
      home: home,
    );

/// A session that gets a fresh [FakeClaude] on every start — a single fake's
/// streams can be listened to once, so Stop → Start needs a new one. Each
/// spawned fake is appended to [spawned].
BridgeSession fakeSessionEach(List<FakeClaude> spawned, {required String dir, required String home}) => BridgeSession(
      dir: dir,
      starter: (bin, args, {workingDirectory, environment}) async {
        final f = FakeClaude()..startedWith = args;
        f.startedIn = workingDirectory;
        spawned.add(f);
        return f;
      },
      findBinary: () async => '/fake/claude',
      versionOf: (_) async => '2.1.251',
      shellPath: () async => '/fake/bin',
      home: home,
    );

/// A short scripted turn: init, a streamed sentence, its final block, a
/// tool call and its result, the end.
void scriptTurn(FakeClaude fake, {String sessionId = 'aaaaaaaa-0000-4000-8000-000000000001', String text = 'Step 31 is ready.'}) {
  fake.emitJson({'type': 'system', 'subtype': 'init', 'session_id': sessionId, 'model': 'claude-fable-5', 'permissionMode': 'default'});
  fake.emitJson({'type': 'rate_limit_event', 'rate_limit_info': {'status': 'allowed', 'resetsAt': 1788111600, 'rateLimitType': 'five_hour'}});
  for (final piece in [text.substring(0, 5), text.substring(5)]) {
    fake.emitJson({'type': 'stream_event', 'event': {'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'text_delta', 'text': piece}}});
  }
  fake.emitJson({'type': 'assistant', 'message': {'role': 'assistant', 'content': [{'type': 'text', 'text': text}]}});
  fake.emitJson({'type': 'assistant', 'message': {'role': 'assistant', 'content': [{'type': 'tool_use', 'id': 'toolu_1', 'name': 'Bash', 'input': {'command': 'bash kit/kit.sh next --step', 'description': 'The next step'}}]}});
  fake.emitJson({'type': 'user', 'message': {'role': 'user', 'content': [{'type': 'tool_result', 'content': 'bridge-core', 'is_error': false, 'tool_use_id': 'toolu_1'}]}});
  fake.emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 900, 'num_turns': 2, 'result': text, 'session_id': sessionId, 'stop_reason': 'end_turn'});
}

void scriptBashAsk(FakeClaude fake, {String requestId = 'req_bash', String command = 'touch /tmp/kit-ask'}) => fake.emitJson({
      'type': 'control_request',
      'request_id': requestId,
      'request': {
        'subtype': 'can_use_tool',
        'tool_name': 'Bash',
        'tool_use_id': 'toolu_b',
        'display_name': 'Bash',
        'description': 'Create a marker file',
        'permission_suggestions': [
          {'type': 'addRules', 'rules': [{'toolName': 'Bash', 'ruleContent': 'touch:*'}], 'behavior': 'allow', 'destination': 'localSettings'}
        ],
        'input': {'command': command, 'description': 'Create a marker file'},
      },
    });

void scriptQuestionAsk(FakeClaude fake, {String requestId = 'req_q'}) => fake.emitJson({
      'type': 'control_request',
      'request_id': requestId,
      'request': {
        'subtype': 'can_use_tool',
        'tool_name': 'AskUserQuestion',
        'tool_use_id': 'toolu_q',
        'display_name': 'Ask user question',
        'requires_user_interaction': true,
        'input': {
          'questions': [
            {
              'question': 'Friends-only presence, or public and documented?',
              'header': 'Presence',
              'multiSelect': false,
              'options': [
                {'label': 'Public, documented', 'description': 'One read per home screen; say so in the privacy copy.'},
                {'label': 'Friends-only', 'description': 'About fifty reads per home screen; matches what was approved.'},
              ],
            }
          ],
        },
      },
    });
