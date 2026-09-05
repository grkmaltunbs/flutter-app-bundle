// The crew: a subagent's rows carry parent_tool_use_id, the CLI narrates
// its life as task_* system lines, and the Agent row gathers it all — on
// lines captured from Claude Code 2.1.261 on 2026-09-06.
import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

const _agentUse =
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_agent","name":"Agent","input":{"subagent_type":"Explore","model":"haiku","description":"Count .dart files in kit/lib","prompt":"Count the number of .dart files under kit/lib."}}]},"parent_tool_use_id":null,"session_id":"s1"}';
const _started =
    '{"type":"system","subtype":"task_started","task_id":"t1","tool_use_id":"toolu_agent","description":"Count .dart files in kit/lib","subagent_type":"Explore","is_backgrounded":false,"prompt":"Count …","session_id":"s1"}';
const _subPrompt = '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Count the number of .dart files under kit/lib."}]},"parent_tool_use_id":"toolu_agent","session_id":"s1"}';
const _subDelta = '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Counting"}},"parent_tool_use_id":"toolu_agent","session_id":"s1"}';
const _progress =
    '{"type":"system","subtype":"task_progress","task_id":"t1","tool_use_id":"toolu_agent","description":"Running Count","subagent_type":"Explore","usage":{"total_tokens":10257,"tool_uses":1,"duration_ms":2432},"last_tool_name":"Bash","session_id":"s1"}';
const _subBash =
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_sub_bash","name":"Bash","input":{"command":"find kit/lib -name *.dart | wc -l"}}]},"parent_tool_use_id":"toolu_agent","session_id":"s1"}';
const _subBashResult = '{"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_sub_bash","type":"tool_result","content":"      18","is_error":false}]},"parent_tool_use_id":"toolu_agent","session_id":"s1"}';
const _subText = '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"18"}]},"parent_tool_use_id":"toolu_agent","session_id":"s1"}';
const _done =
    '{"type":"system","subtype":"task_notification","task_id":"t1","tool_use_id":"toolu_agent","status":"completed","output_file":"/tmp/t1.output","summary":"18","usage":{"total_tokens":10766,"tool_uses":1,"duration_ms":4789},"session_id":"s1"}';
const _agentResult = '{"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_agent","type":"tool_result","content":[{"type":"text","text":"18"}]}]},"parent_tool_use_id":null,"session_id":"s1"}';
const _answer = '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"The Explore agent counted 18."}]},"parent_tool_use_id":null,"session_id":"s1"}';

void main() {
  test('the lines parse with their parent, and the task lines by kind', () {
    expect(parseBridgeLine(_agentUse), isA<AssistantEvent>().having((e) => e.parentToolUseId, 'parent', isNull));
    expect(parseBridgeLine(_subDelta), isA<TextDeltaEvent>().having((e) => e.parentToolUseId, 'parent', 'toolu_agent'));
    expect(parseBridgeLine(_subPrompt), isA<UserEchoEvent>().having((e) => e.parentToolUseId, 'parent', 'toolu_agent'));
    expect(parseBridgeLine(_subBash), isA<AssistantEvent>().having((e) => e.parentToolUseId, 'parent', 'toolu_agent'));
    expect(parseBridgeLine(_subBashResult), isA<ToolResultEvent>().having((e) => e.parentToolUseId, 'parent', 'toolu_agent'));
    final s = parseBridgeLine(_started) as TaskEvent;
    expect(s.kind, 'started');
    expect(s.toolUseId, 'toolu_agent');
    expect(s.subagentType, 'Explore');
    final p = parseBridgeLine(_progress) as TaskEvent;
    expect(p.kind, 'progress');
    expect(p.toolUses, 1);
    expect(p.lastTool, 'Bash');
    final d = parseBridgeLine(_done) as TaskEvent;
    expect(d.kind, 'done');
    expect(d.status, 'completed');
    expect(d.summary, '18');
  });

  test('the transcript folds the subagent under its Agent row and keeps the conversation clean', () {
    var t0 = DateTime.utc(2026, 9, 6, 2);
    final t = Transcript()..now = (() => t0);
    t.addUser('count the dart files');
    for (final line in [_agentUse, _started, _subPrompt, _subDelta, _progress, _subBash, _subBashResult, _subText]) {
      t.apply(parseBridgeLine(line)!);
    }
    // The main conversation: the user, the Agent row; the subagent's
    // prompt and draft made no rows, its tool use and text hang under it.
    final main = t.messages.where((m) => m.parentToolUseId == null).toList();
    expect(main.map((m) => m.role), [DeckRole.user, DeckRole.tool]);
    final agent = main.last;
    expect(agent.isAgent, isTrue);
    expect(agent.toolSummary, 'Explore · Count .dart files in kit/lib');
    expect(agent.running, isTrue);
    expect(agent.progress, containsPair('toolUses', 1));
    expect(agent.progress, containsPair('lastTool', 'Bash'));
    final under = t.messages.where((m) => m.parentToolUseId == 'toolu_agent').toList();
    expect(under.map((m) => m.role), [DeckRole.tool, DeckRole.assistant]);
    expect(under.first.toolResult, '      18');
    expect(under.first.doneAt, isNotNull);
    expect(under.last.text, '18');
    expect(t.deltasSeen, 1);

    var crew = crewOf(t.messages);
    expect(crew.length, 1);
    expect(crew.single.running, isTrue);
    expect(crew.single.kind, 'Explore');
    expect(crew.single.description, 'Count .dart files in kit/lib');
    expect(crew.single.rows.length, 2);
    expect(crew.single.toolUses, 1);
    t0 = t0.add(const Duration(seconds: 5));
    expect(crew.single.elapsed(t0), const Duration(seconds: 5));

    for (final line in [_done, _agentResult, _answer]) {
      t.apply(parseBridgeLine(line)!);
    }
    crew = crewOf(t.messages);
    expect(crew.single.running, isFalse);
    expect(crew.single.failed, isFalse);
    expect(crew.single.summary, '18');
    expect(agent.doneAt, t0);
    expect(agent.progress, containsPair('status', 'completed'));
    // A new turn: the strip is for the turn at hand.
    t.addUser('thanks');
    expect(crewOf(t.messages), isEmpty);
    // Over the relay and back, the fold survives.
    final back = DeckMessage.fromMap(under.first.toMap());
    expect(back.parentToolUseId, 'toolu_agent');
    expect(back.doneAt, isNotNull);
  });

  test('a long result keeps 24 KB for the sheet and says the Mac has the rest', () {
    final t = Transcript()..addUser('run it');
    t.apply(parseBridgeLine('{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_b","name":"Bash","input":{"command":"cat big"}}]},"session_id":"s1"}')!);
    final big = List.filled(100 * 1024, 'x').join();
    t.apply(ToolResultEvent(toolUseId: 'toolu_b', content: big));
    final row = t.messages.last;
    expect(row.toolResult!.length, 600);
    expect(row.toolOutput!.length, toolOutputLimit);
    expect(row.toolOutputCut, isTrue);
    expect(row.fullResult, row.toolOutput);
    final back = DeckMessage.fromMap(row.toMap());
    expect(back.toolOutput!.length, toolOutputLimit);
    expect(back.toolOutputCut, isTrue);
    // A short one keeps only the row's copy.
    t.apply(parseBridgeLine('{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_c","name":"Bash","input":{"command":"true"}}]},"session_id":"s1"}')!);
    t.apply(const ToolResultEvent(toolUseId: 'toolu_c', content: 'ok'));
    expect(t.messages.last.toolOutput, isNull);
    expect(t.messages.last.fullResult, 'ok');
  });

  test('the clock', () {
    expect(clockLabel(const Duration(seconds: 42)), '0:42');
    expect(clockLabel(const Duration(minutes: 12, seconds: 5)), '12:05');
    expect(clockLabel(const Duration(hours: 1, minutes: 2, seconds: 9)), '1:02:09');
  });
}
