// The bridge protocol, on lines captured from Claude Code 2.1.251 on
// 2026-08-30 (the spike in app/DESIGN.md). A shape change in the CLI must
// fail here before it reaches a phone.
import 'dart:convert';

import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

const _init =
    '{"type":"system","subtype":"init","session_id":"cab35dc8-d8d7-4b85-9b97-f645cf25da44","model":"claude-fable-5","permissionMode":"default","cwd":"/tmp/spike","tools":["Bash","Read","AskUserQuestion"]}';
const _delta1 = '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"You chose "}},"session_id":"cab35dc8"}';
const _delta2 = '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"coffee."}},"session_id":"cab35dc8"}';
const _assistantText = '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"You chose coffee."}]},"session_id":"cab35dc8"}';
const _assistantTool =
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_01","name":"Bash","input":{"command":"echo you-chose","description":"Echo the confirmation string"}}]},"session_id":"cab35dc8"}';
const _toolResult = '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"you-chose","is_error":false,"tool_use_id":"toolu_01"}]},"session_id":"cab35dc8"}';
const _echo = '{"type":"user","message":{"role":"user","content":"/plan-status"},"session_id":"cab35dc8"}';
const _askQuestion =
    '{"type":"control_request","request_id":"req_1","request":{"subtype":"can_use_tool","tool_name":"AskUserQuestion","tool_use_id":"toolu_q","display_name":"Ask user question","requires_user_interaction":true,"input":{"questions":[{"question":"Tea or coffee?","header":"Drink","options":[{"label":"Tea","description":"You prefer tea."},{"label":"Coffee","description":"You prefer coffee."}],"multiSelect":false}]}}}';
const _askBash =
    '{"type":"control_request","request_id":"req_2","request":{"subtype":"can_use_tool","tool_name":"Bash","tool_use_id":"toolu_b","display_name":"Bash","description":"Create empty spike-permission.txt file","blocked_path":null,"permission_suggestions":[{"type":"addRules","rules":[{"toolName":"Bash","ruleContent":"touch:*"}],"behavior":"allow","destination":"localSettings"}],"input":{"command":"touch spike-permission.txt","description":"Create empty spike-permission.txt file"}}}';
const _result =
    '{"type":"result","subtype":"success","is_error":false,"duration_ms":4120,"num_turns":3,"result":"You chose coffee.","session_id":"cab35dc8-d8d7-4b85-9b97-f645cf25da44","stop_reason":"end_turn"}';
const _rate =
    '{"type":"rate_limit_event","rate_limit_info":{"status":"allowed","resetsAt":1788111600,"rateLimitType":"five_hour","overageStatus":"rejected","overageDisabledReason":"org_level_disabled"}}';

void main() {
  test('the command line names a fresh session or resumes one', () {
    final fresh = bridgeArgs(sessionId: 'abc');
    expect(fresh, containsAllInOrder(['-p', '--verbose', '--input-format', 'stream-json', '--output-format', 'stream-json']));
    expect(fresh, containsAllInOrder(['--permission-prompt-tool', 'stdio', '--permission-mode', 'default', '--session-id', 'abc']));
    expect(fresh, isNot(contains('--resume')));
    final again = bridgeArgs(sessionId: 'abc', resume: true, model: 'opus');
    expect(again, containsAllInOrder(['--resume', 'abc', '--model', 'opus']));
    expect(again, isNot(contains('--session-id')));
  });

  test('every captured line parses to its event', () {
    expect(parseBridgeLine(_init), isA<InitEvent>().having((e) => e.sessionId, 'session', 'cab35dc8-d8d7-4b85-9b97-f645cf25da44').having((e) => e.model, 'model', 'claude-fable-5'));
    expect(parseBridgeLine(_delta1), isA<TextDeltaEvent>().having((e) => e.text, 'text', 'You chose '));
    final a = parseBridgeLine(_assistantTool) as AssistantEvent;
    expect(a.blocks.single.isToolUse, isTrue);
    expect(a.blocks.single.toolName, 'Bash');
    expect(a.blocks.single.toolInput!['command'], 'echo you-chose');
    expect(parseBridgeLine(_toolResult), isA<ToolResultEvent>().having((e) => e.content, 'content', 'you-chose').having((e) => e.toolUseId, 'id', 'toolu_01'));
    expect(parseBridgeLine(_echo), isA<UserEchoEvent>().having((e) => e.text, 'text', '/plan-status'));
    expect(parseBridgeLine(_result), isA<ResultEvent>().having((e) => e.numTurns, 'turns', 3).having((e) => e.isError, 'error', isFalse));
    final r = parseBridgeLine(_rate) as RateLimitEvent;
    expect(r.rateLimitType, 'five_hour');
    expect(r.resetsAt, DateTime.fromMillisecondsSinceEpoch(1788111600 * 1000, isUtc: true));
    expect(r.overageStatus, 'rejected');
    expect(parseBridgeLine(''), isNull);
    expect(parseBridgeLine('not json'), isNull);
    expect(parseBridgeLine('{"type":"system","subtype":"status"}'), isA<OtherEvent>().having((e) => e.subtype, 'subtype', 'status'));
  });

  test('a question arrives as an ask with its options, and is answered by label', () {
    final e = parseBridgeLine(_askQuestion) as AskEvent;
    final ask = e.ask;
    expect(ask.isQuestion, isTrue);
    expect(ask.requiresUserInteraction, isTrue);
    expect(ask.questions.single.question, 'Tea or coffee?');
    expect(ask.questions.single.options.map((o) => o.label), ['Tea', 'Coffee']);
    expect(ask.summary, 'Tea or coffee?');

    final t = Transcript()..apply(e);
    expect(t.pending, same(ask));
    final line = t.answer(AskAnswer.answers(ask, {'Tea or coffee?': 'Coffee'}));
    final m = jsonDecode(line) as Map;
    expect(m['type'], 'control_response');
    expect(m['response']['request_id'], 'req_1');
    expect(m['response']['response']['behavior'], 'allow');
    expect(m['response']['response']['updatedInput']['answers'], {'Tea or coffee?': 'Coffee'});
    expect(m['response']['response']['updatedInput']['questions'], isNotEmpty, reason: 'the original input travels with the answers');
    expect(t.pending, isNull);
    expect(t.messages.last.role, DeckRole.note);
    expect(t.messages.last.text, contains('Coffee'));
  });

  test('a permission arrives with its suggestions, and a denial carries the message', () {
    final e = parseBridgeLine(_askBash) as AskEvent;
    final ask = e.ask;
    expect(ask.isQuestion, isFalse);
    expect(ask.summary, 'touch spike-permission.txt');
    expect(ask.description, 'Create empty spike-permission.txt file');
    expect(ask.suggestions.single['behavior'], 'allow');
    final t = Transcript()..apply(e);
    final line = t.answer(AskAnswer.deny('The user declined from the phone.'));
    final m = jsonDecode(line) as Map;
    expect(m['response']['response'], {'behavior': 'deny', 'message': 'The user declined from the phone.'});
    expect(t.messages.last.text, startsWith('Denied: touch'));
    expect(() => t.answer(AskAnswer.deny('again')), throwsStateError);
    // Round trip through the relay shape.
    final back = Ask.fromMap(ask.toMap());
    expect(back.requestId, ask.requestId);
    expect(back.input, ask.input);
    expect(back.suggestions, ask.suggestions);
  });

  test('a turn folds into the transcript: streamed text, a tool row with its result, the end', () {
    final t = Transcript();
    var tick = 0;
    t.now = () => DateTime.utc(2026, 8, 30, 12, 0, tick++);
    t.addUser('/plan-status');
    expect(t.turnOpen, isTrue);
    for (final l in [_init, _rate, _echo, _delta1, _delta2]) {
      t.apply(parseBridgeLine(l)!);
    }
    expect(t.sessionId, startsWith('cab35dc8'));
    expect(t.pool!.rateLimitType, 'five_hour');
    expect(t.messages.last.role, DeckRole.assistant);
    expect(t.messages.last.streaming, isTrue);
    expect(t.messages.last.text, 'You chose coffee.');
    expect(t.deltasSeen, 2);

    t.apply(parseBridgeLine(_assistantText)!);
    expect(t.messages.last.streaming, isFalse);
    expect(t.messages.where((m) => m.role == DeckRole.assistant).length, 1, reason: 'the final block replaces its draft, never duplicates it');

    t.apply(parseBridgeLine(_assistantTool)!);
    final tool = t.messages.last;
    expect(tool.role, DeckRole.tool);
    expect(tool.toolSummary, 'echo you-chose');
    expect(tool.toolResult, isNull);
    t.apply(parseBridgeLine(_toolResult)!);
    expect(tool.toolResult, 'you-chose');
    expect(tool.isError, isFalse);

    t.apply(parseBridgeLine(_result)!);
    expect(t.turnOpen, isFalse);
    expect(t.lastResult!.numTurns, 3);
    expect(t.messages.map((m) => m.role), [DeckRole.user, DeckRole.assistant, DeckRole.tool]);

    // The relay shape round-trips every row.
    for (final m in t.messages) {
      final back = DeckMessage.fromMap(m.toMap());
      expect(back.role, m.role);
      expect(back.text, m.text);
      expect(back.toolSummary, m.toolSummary);
      expect(back.toolResult, m.toolResult);
    }
  });

  test('an empty streamed draft that a tool call interrupts leaves no blank row', () {
    final t = Transcript()..addUser('go');
    t.apply(parseBridgeLine(_assistantTool)!);
    expect(t.messages.map((m) => m.role), [DeckRole.user, DeckRole.tool]);
    // A failed result lands as a note the user can read.
    t.apply(const ResultEvent(subtype: 'error_max_turns', sessionId: 's', isError: true, text: 'Reached the turn limit.'));
    expect(t.messages.last.role, DeckRole.note);
    expect(t.messages.last.text, 'Reached the turn limit.');
  });

  test('the user message line is what the CLI expects', () {
    expect(jsonDecode(encodeUserMessage('/step')), {
      'type': 'user',
      'message': {'role': 'user', 'content': '/step'},
    });
  });
}
