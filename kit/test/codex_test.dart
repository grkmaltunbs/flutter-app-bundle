// The Codex engine's pure half: the mode map, the lines the host writes,
// and the events the app-server's lines become — every shape below was
// captured live on 0.153.4, 2026-09-10 (the spike table in app/DESIGN.md).
import 'dart:convert';

import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

const _thread = '01a088b7-c601-7b61-8ddd-912b346fb574';
const _turn = '01a088b7-c672-73b0-ad87-534027b687bd';

String _threadStartResponse(int id, {String threadId = _thread, List<Object?> turns = const [], String approval = 'on-request'}) => jsonEncode({
      'id': id,
      'result': {
        'thread': {'id': threadId, 'sessionId': threadId, 'model': 'gpt-6-astra', 'reasoningEffort': 'medium', 'cwd': '/Users/ren/kit-scratch', 'cliVersion': '0.153.4', 'status': {'type': 'idle'}, 'turns': turns},
        'model': 'gpt-6-astra',
        'instructionSources': ['/Users/ren/kit-scratch/CLAUDE.md'],
        'modelProvider': 'openai',
        'cwd': '/Users/ren/kit-scratch',
        'approvalPolicy': approval,
        'sandbox': {'type': 'workspaceWrite', 'writableRoots': [], 'networkAccess': false},
        'reasoningEffort': 'medium',
      },
    });

String _n(String method, Map<String, Object?> params) => jsonEncode({'method': method, 'params': params});

Map<String, Object?> _item(String type, String id, Map<String, Object?> rest) => {'type': type, 'id': id, ...rest};

/// The captured question turn: a user message, the request, the answer.
const _question = '{"method":"item/tool/requestUserInput","id":0,"params":{"threadId":"$_thread","turnId":"$_turn","itemId":"call_aCcU23mvyM7kGLObzNbW9cym","questions":[{"id":"drink","header":"Drink","question":"Would you like tea or coffee?","isOther":true,"isSecret":false,"options":[{"label":"Tea","description":"Choose tea."},{"label":"Coffee","description":"Choose coffee."}]}],"isBlocking":false,"autoResolutionMs":null}}';

const _approval = '{"method":"item/commandExecution/requestApproval","id":0,"params":{"kind":"command","threadId":"$_thread","turnId":"$_turn","itemId":"exec-db4ad502","startedAtMs":1789000221711,"environmentId":"local","command":"/bin/zsh -lc \'touch /tmp/kit-codex-1 .\'","cwd":"/Users/ren/kit-scratch","commandActions":[{"type":"unknown","command":"touch /tmp/kit-codex-1 ."}],"proposedExecpolicyAmendment":["touch","/tmp/kit-codex-1","."],"availableDecisions":["accept",{"acceptWithExecpolicyAmendment":{"execpolicy_amendment":["touch","/tmp/kit-codex-1","."]}},"cancel"]}}';

const _usage = '{"method":"thread/tokenUsage/updated","params":{"threadId":"$_thread","turnId":"$_turn","tokenUsage":{"total":{"totalTokens":38789,"inputTokens":38720,"cachedInputTokens":32128,"cacheWriteInputTokens":0,"outputTokens":69,"reasoningOutputTokens":0},"last":{"totalTokens":19410,"inputTokens":19402,"cachedInputTokens":19200,"cacheWriteInputTokens":0,"outputTokens":8,"reasoningOutputTokens":0},"modelContextWindow":258400}}}';

const _rateWeekly = '{"method":"account/rateLimits/updated","params":{"rateLimits":{"limitId":"codex","limitName":null,"primary":{"usedPercent":9,"windowDurationMins":10080,"resetsAt":1789577025},"secondary":null,"credits":{"hasCredits":false,"unlimited":false,"balance":"0"},"individualLimit":null,"spendControlReached":null,"planType":"pro","rateLimitReachedType":null}}}';

String _completed({String status = 'completed', Map<String, Object?>? error, List<Object?> items = const []}) =>
    _n('turn/completed', {'threadId': _thread, 'turn': {'id': _turn, 'items': items, 'itemsView': 'summary', 'status': status, 'error': error, 'startedAt': 1789000140, 'completedAt': 1789000146, 'durationMs': 6399}});

/// A translator past its handshake, with a thread.
CodexTranslator _ready({String mode = 'default'}) {
  final t = CodexTranslator(now: () => DateTime.utc(2026, 9, 10, 3));
  t.initializeLine();
  final start = t.threadStartLine(cwd: '/Users/ren/kit-scratch', mode: mode, developerInstructions: 'brief');
  final id = (jsonDecode(start) as Map)['id'] as int;
  t.feed(_threadStartResponse(id));
  return t;
}

void main() {
  test('the notches become an approval policy, a sandbox and a collaboration mode — and read back', () {
    expect(codexPolicyFor('default').approval, 'untrusted');
    expect(codexPolicyFor('default').sandbox, 'workspace-write');
    expect(codexPolicyFor('acceptEdits').approval, 'on-request');
    expect(codexPolicyFor('bypassPermissions').approval, 'never');
    expect(codexPolicyFor('bypassPermissions').sandboxPolicy, {'type': 'dangerFullAccess'});
    expect(codexPolicyFor('plan').collaboration, 'plan');
    expect(codexPolicyFor('plan').sandboxPolicy, {'type': 'readOnly'});
    expect(codexPolicyFor('nonsense').approval, 'untrusted');
    expect(codexModeFor(approval: 'untrusted', sandboxType: 'workspaceWrite', collaboration: 'default'), 'default');
    expect(codexModeFor(approval: 'on-request', sandboxType: 'workspaceWrite', collaboration: 'default'), 'acceptEdits');
    expect(codexModeFor(approval: 'never', sandboxType: 'dangerFullAccess'), 'bypassPermissions');
    expect(codexModeFor(approval: 'on-request', sandboxType: 'workspaceWrite', collaboration: 'plan'), 'plan');
    expect(codexArgs(), ['app-server', '--stdio', '--enable', 'default_mode_request_user_input']);
    expect(codexPlainCommand("/bin/zsh -lc 'touch /tmp/kit-codex-1'"), 'touch /tmp/kit-codex-1');
    expect(codexPlainCommand('/bin/zsh -lc "pwd && ls"'), 'pwd && ls');
    expect(codexPlainCommand('ls -la'), 'ls -la');
  });

  test('the engine words: the notch, the labels, the dials per engine, the brief in Codex\'s words', () {
    expect(engineChoices, ['claude', 'codex']);
    expect(knownEngine('codex'), 'codex');
    expect(knownEngine(null), 'claude');
    expect(knownEngine('gemini'), 'claude');
    expect(engineLabel('codex'), 'Codex');
    expect(modelChoicesFor('claude'), modelChoices);
    expect(modelChoicesFor('codex'), codexModelChoices);
    expect(modelChoicesFor('codex', reported: ['gpt-6-astra', 'gpt-5.5']), ['default', 'gpt-6-astra', 'gpt-5.5']);
    expect(effortChoicesFor('codex'), contains('ultra'));
    expect(effortChoicesFor('claude'), isNot(contains('ultra')));
    final b = deckBrief(chrome: false, mode: 'default', engine: 'codex', custom: 'Answer in Turkish.');
    expect(b, contains('request_user_input'));
    expect(b, isNot(contains('AskUserQuestion')));
    expect(b, contains(signedInOption));
    expect(b, contains(projectBriefHead));
    expect(b, endsWith('Answer in Turkish.'));
    expect(deckBrief(chrome: false, mode: 'plan', engine: 'codex'), contains('plan mode'));
    expect(deckBrief(chrome: false, mode: 'default'), contains('AskUserQuestion'), reason: 'Claude keeps its own words');
  });

  test('the handshake: initialize, then a thread with the notch as policy, the brief as developer instructions; resume and clear', () {
    final t = CodexTranslator();
    final init = jsonDecode(t.initializeLine(version: '1.2.3')) as Map;
    expect(init['method'], 'initialize');
    expect(init['id'], 1);
    expect((init['params'] as Map)['clientInfo'], {'name': 'katya', 'title': 'K.A.T.Y.A', 'version': '1.2.3'});
    expect(jsonDecode(t.initializedLine()), {'jsonrpc': '2.0', 'method': 'initialized', 'params': {}});
    final start = jsonDecode(t.threadStartLine(cwd: '/p', mode: 'default', developerInstructions: 'be brief', model: 'gpt-5.5')) as Map;
    expect(start['method'], 'thread/start');
    expect(start['params'], {'cwd': '/p', 'approvalPolicy': 'untrusted', 'sandbox': 'workspace-write', 'model': 'gpt-5.5', 'developerInstructions': 'be brief'});
    final resume = jsonDecode(t.threadStartLine(cwd: '/p', mode: 'acceptEdits', resume: 'abc')) as Map;
    expect(resume['method'], 'thread/resume');
    expect((resume['params'] as Map)['threadId'], 'abc');
    expect((resume['params'] as Map)['approvalPolicy'], 'on-request');
    final clear = jsonDecode(t.threadStartLine(cwd: '/p', mode: 'default', clear: true)) as Map;
    expect((clear['params'] as Map)['sessionStartSource'], 'clear');
    expect(t.threadId, isNull, reason: 'no response yet');
  });

  test('the thread/start response is the init: the id, the model, the notch; the turn carries text, images, a skill and the dials', () {
    final t = CodexTranslator();
    final id = (jsonDecode(t.threadStartLine(cwd: '/p', mode: 'acceptEdits')) as Map)['id'] as int;
    final events = t.feed(_threadStartResponse(id));
    expect(events, hasLength(1));
    final init = events.single as InitEvent;
    expect(init.sessionId, _thread);
    expect(init.model, 'gpt-6-astra');
    expect(init.permissionMode, 'acceptEdits');
    expect(init.cwd, '/Users/ren/kit-scratch');
    expect(init.rules, ['CLAUDE.md'], reason: 'the rules file Codex loaded — instructionSources, by name');
    expect(t.threadId, _thread);
    expect(t.cliVersion, '0.153.4');

    t.skills = {'kit-step': '/plugin/skills/kit-step/SKILL.md'};
    final turn = jsonDecode(t.turnStartLine(text: 'hello', mode: 'default', effort: 'high', model: 'gpt-5.5', imagePaths: ['/a/shot.png'], skill: 'kit-step')) as Map;
    expect(turn['method'], 'turn/start');
    final p = turn['params'] as Map;
    expect(p['threadId'], _thread);
    expect(p['input'], [
      {'type': 'skill', 'name': 'kit-step', 'path': '/plugin/skills/kit-step/SKILL.md'},
      {'type': 'localImage', 'path': '/a/shot.png'},
      {'type': 'text', 'text': 'hello'},
    ]);
    expect(p['approvalPolicy'], 'untrusted');
    expect(p['sandboxPolicy'], {'type': 'workspaceWrite'});
    expect(p['collaborationMode'], {'mode': 'default', 'settings': {'model': 'gpt-5.5'}});
    expect(p['model'], 'gpt-5.5');
    expect(p['effort'], 'high');
    final plan = jsonDecode(t.turnStartLine(text: 'plan it', mode: 'plan')) as Map;
    expect((plan['params'] as Map)['collaborationMode'], {'mode': 'plan', 'settings': {'model': 'gpt-6-astra'}}, reason: 'the thread\'s model when the dial is default');
    expect((plan['params'] as Map)['sandboxPolicy'], {'type': 'readOnly'});
    expect((plan['params'] as Map).containsKey('model'), isFalse);
    final roots = jsonDecode(t.turnStartLine(text: 'x', mode: 'acceptEdits', writableRoots: ['/sdk/bin/cache'])) as Map;
    expect((roots['params'] as Map)['sandboxPolicy'], {'type': 'workspaceWrite', 'writableRoots': ['/sdk/bin/cache']});
    final ro = jsonDecode(t.turnStartLine(text: 'x', mode: 'plan', writableRoots: ['/sdk/bin/cache'])) as Map;
    expect((ro['params'] as Map)['sandboxPolicy'], {'type': 'readOnly'}, reason: 'roots widen only a workspace-write sandbox');
    final unknownSkill = jsonDecode(t.turnStartLine(text: '/qa', mode: 'default', skill: 'kit-qa')) as Map;
    expect((unknownSkill['params'] as Map)['input'], [{'type': 'text', 'text': '/qa'}], reason: 'a skill the folder does not have goes as text');
  });

  test('a turn folds into the transcript: the streamed reply, the final text, the tokens, the end', () {
    final t = _ready();
    final tr = Transcript();
    void feed(String line) {
      for (final e in t.feed(line)) {
        tr.apply(e);
      }
    }

    final turnId = (jsonDecode(t.turnStartLine(text: 'what model are you?', mode: 'default')) as Map)['id'] as int;
    tr.addUser('what model are you?');
    feed(jsonEncode({'id': turnId, 'result': {'turn': {'id': _turn, 'items': [], 'status': 'inProgress'}}}));
    expect(t.turnId, _turn);
    feed(_n('item/started', {'item': _item('userMessage', 'u1', {'content': [{'type': 'text', 'text': 'what model are you?'}]}), 'threadId': _thread, 'turnId': _turn}));
    feed(_n('item/started', {'item': _item('agentMessage', 'msg_1', {'text': '', 'phase': 'final_answer'}), 'threadId': _thread, 'turnId': _turn}));
    feed(_n('item/agentMessage/delta', {'threadId': _thread, 'turnId': _turn, 'itemId': 'msg_1', 'delta': 'You chose'}));
    feed(_n('item/agentMessage/delta', {'threadId': _thread, 'turnId': _turn, 'itemId': 'msg_1', 'delta': ' coffee.'}));
    expect(tr.messages.last.role, DeckRole.assistant);
    expect(tr.messages.last.streaming, isTrue);
    expect(tr.messages.last.text, 'You chose coffee.');
    feed(_n('item/completed', {'item': _item('agentMessage', 'msg_1', {'text': 'You chose coffee.', 'phase': 'final_answer'}), 'threadId': _thread, 'turnId': _turn}));
    expect(tr.messages.last.streaming, isFalse);
    feed(_usage);
    expect(tr.contextUsed, 19402, reason: 'what the last call read: input, cached included');
    expect(tr.contextWindow, 258400);
    feed(_rateWeekly);
    expect(tr.pool!.fiveHour, isNull, reason: 'a Pro plan reported only the weekly window');
    expect(tr.pool!.sevenDay!.utilization, closeTo(0.09, 0.0001));
    expect(tr.pool!.resetsAt, DateTime.utc(2026, 9, 16, 16, 43, 45));
    expect(tr.pool!.exhausted, isFalse);
    feed(_completed(items: [_item('agentMessage', 'msg_1', {'text': 'You chose coffee.', 'phase': 'final_answer'})]));
    expect(tr.turnOpen, isFalse);
    expect(tr.lastResult!.text, 'You chose coffee.');
    expect(tr.lastResult!.isError, isFalse);
    expect(tr.lastResult!.numTurns, 1);
    expect(tr.lastResult!.durationMs, 6399);
    expect(tr.lastResult!.usage!.output, 8);
    expect(tr.messages.map((m) => m.role), [DeckRole.user, DeckRole.assistant]);
    expect(tr.messages.last.turn!.output, 8);
  });

  test('a question is an ask with its options, in Codex\'s name; the answer goes back under the question\'s id', () {
    final t = _ready();
    final events = t.feed(_question);
    expect(events, hasLength(1));
    final ask = (events.single as AskEvent).ask;
    expect(ask.isQuestion, isTrue);
    expect(ask.engine, 'codex');
    expect(ask.engineLabel, 'Codex');
    expect(ask.requestId, matches(RegExp(r'^cx-01a088b7-[0-9a-z]{3}-0$')), reason: 'the thread, a salt for this process, the server\'s id');
    expect(ask.questions.single.question, 'Would you like tea or coffee?');
    expect(ask.questions.single.header, 'Drink');
    expect(ask.questions.single.options.map((o) => o.label), ['Tea', 'Coffee']);
    expect(ask.requiresUserInteraction, isTrue);
    expect(noticeForAsk(ask, project: 'kit').title, 'Codex asks · kit');
    expect(noticeActions(ask).map((a) => a.label), ['Tea', 'Coffee']);
    expect(Ask.fromMap(ask.toMap()).engine, 'codex', reason: 'the engine rides the relay');
    final line = t.answerLine(ask, AskAnswer.answers(ask, {ask.questions.single.question: 'Coffee'}));
    expect(jsonDecode(line!), {'jsonrpc': '2.0', 'id': 0, 'result': {'answers': {'drink': {'answers': ['Coffee']}}}});
    expect(t.answerLine(ask, AskAnswer.allow(ask)), isNull, reason: 'answered once');
    // In one's own words: the same road.
    t.feed(_question);
    final own = t.answerLine(ask, AskAnswer.answers(ask, {ask.questions.single.question: 'Mate, please'}));
    expect((jsonDecode(own!) as Map)['result'], {'answers': {'drink': {'answers': ['Mate, please']}}});
  });

  test('a command under untrusted is an ask with the plain command; deny declines, allow accepts, always carries the execpolicy amendment', () {
    final t = _ready();
    final ask = (t.feed(_approval).single as AskEvent).ask;
    expect(ask.toolName, 'Bash');
    expect(ask.summary, 'touch /tmp/kit-codex-1 .');
    expect(ask.toolUseId, 'exec-db4ad502');
    expect(ask.suggestions, [{'type': 'execpolicy', 'pattern': ['touch', '/tmp/kit-codex-1', '.']}]);
    expect(noticeForAsk(ask, project: 'kit').title, 'Allow Run? · kit');
    expect(jsonDecode(t.answerLine(ask, AskAnswer.deny('The user declined from the phone.'))!), {'jsonrpc': '2.0', 'id': 0, 'result': {'decision': 'decline'}});
    t.feed(_approval);
    expect((jsonDecode(t.answerLine(ask, AskAnswer.allow(ask))!) as Map)['result'], {'decision': 'accept'});
    t.feed(_approval);
    final always = AskAnswer.always(ask);
    expect(always.appliesAlways, isTrue);
    expect((jsonDecode(t.answerLine(ask, always)!) as Map)['result'], {'decision': {'acceptWithExecpolicyAmendment': {'execpolicy_amendment': ['touch', '/tmp/kit-codex-1', '.']}}});
    // The rows: the command starts, is declined, the model reads why.
    final tr = Transcript();
    for (final e in t.feed(_n('item/started', {'item': _item('commandExecution', 'exec-db4ad502', {'command': "/bin/zsh -lc 'touch /tmp/kit-codex-1 .'", 'cwd': '/p', 'status': 'inProgress', 'commandActions': [{'type': 'unknown', 'command': 'touch /tmp/kit-codex-1 .'}]}), 'threadId': _thread, 'turnId': _turn}))) {
      tr.apply(e);
    }
    expect(tr.messages.single.toolName, 'Bash');
    expect(tr.messages.single.toolSummary, 'touch /tmp/kit-codex-1 .');
    expect(tr.messages.single.running, isTrue);
    for (final e in t.feed(_n('item/completed', {'item': _item('commandExecution', 'exec-db4ad502', {'command': "/bin/zsh -lc 'touch /tmp/kit-codex-1 .'", 'cwd': '/p', 'status': 'declined', 'commandActions': [{'type': 'unknown', 'command': 'touch /tmp/kit-codex-1 .'}], 'aggregatedOutput': null, 'exitCode': null}), 'threadId': _thread, 'turnId': _turn}))) {
      tr.apply(e);
    }
    expect(tr.messages.single.running, isFalse);
    expect(tr.messages.single.isError, isTrue);
    expect(tr.messages.single.toolResult, codexDeclinedNote);
    for (final e in t.feed(_n('item/completed', {'item': _item('commandExecution', 'exec-2', {'command': "/bin/zsh -lc 'ls'", 'cwd': '/p', 'status': 'completed', 'commandActions': [{'type': 'listFiles', 'command': 'ls'}], 'aggregatedOutput': 'README.md\nlib\n', 'exitCode': 0}), 'threadId': _thread, 'turnId': _turn}))) {
      tr.apply(e);
    }
    expect(tr.messages, hasLength(1), reason: 'a result for a row that never started makes no row');
  });

  test('an edit is a fileChange: the row carries Codex\'s own diff, and its approval is an apply_patch ask with the same diff', () {
    final t = _ready();
    final tr = Transcript();
    final started = _n('item/started', {
      'item': _item('fileChange', 'exec-8cd25013', {'changes': [{'path': '/Users/ren/kit-scratch/README.md', 'kind': {'type': 'update', 'move_path': null}, 'diff': '@@ -17 +17,2 @@\n samples.\n+Planned from the phone.\n'}], 'status': 'inProgress'}),
      'threadId': _thread,
      'turnId': _turn,
    });
    for (final e in t.feed(started)) {
      tr.apply(e);
    }
    final row = tr.messages.single;
    expect(row.toolName, 'apply_patch');
    expect(row.path, '/Users/ren/kit-scratch/README.md');
    expect(row.toolSummary, 'apply_patch · /Users/ren/kit-scratch/README.md');
    expect(row.diff, contains('+Planned from the phone.'));
    expect(row.diff, startsWith('--- a//Users/ren/kit-scratch/README.md\n+++ b//Users/ren/kit-scratch/README.md\n'));
    final approval = _n('item/fileChange/requestApproval', {'threadId': _thread, 'turnId': _turn, 'itemId': 'exec-8cd25013', 'startedAtMs': 1, 'reason': null});
    final ask = (t.feed(approval.replaceFirst('{"method"', '{"id":0,"method"')).single as AskEvent).ask;
    expect(ask.toolName, 'apply_patch');
    expect(ask.path, '/Users/ren/kit-scratch/README.md');
    expect(ask.diff, row.diff);
    expect(ask.suggestions, isEmpty, reason: 'no Always for a patch');
    expect(noticeForAsk(ask, project: 'kit').body, contains('Planned from the phone.'));
    expect((jsonDecode(t.answerLine(ask, AskAnswer.allow(ask))!) as Map)['result'], {'decision': 'accept'});
    for (final e in t.feed(_n('item/completed', {'item': _item('fileChange', 'exec-8cd25013', {'changes': [{'path': '/Users/ren/kit-scratch/README.md', 'kind': {'type': 'update'}, 'diff': '@@'}], 'status': 'completed'}), 'threadId': _thread, 'turnId': _turn}))) {
      tr.apply(e);
    }
    expect(row.toolResult, 'update /Users/ren/kit-scratch/README.md');
    expect(row.isError, isFalse);
  });

  test('plan mode: the settings say so, the plan streams as the reply, and the turn\'s end raises the plan card the host answers itself', () {
    final t = _ready(mode: 'plan');
    final tr = Transcript();
    void feed(String line) {
      for (final e in t.feed(line)) {
        tr.apply(e);
      }
    }

    tr.addUser('plan a one-line change');
    t.turnStartLine(text: 'plan a one-line change', mode: 'plan');
    feed(_n('thread/settings/updated', {'threadId': _thread, 'threadSettings': {'cwd': '/p', 'approvalPolicy': 'on-request', 'sandboxPolicy': {'type': 'readOnly'}, 'model': 'gpt-6-astra', 'collaborationMode': {'mode': 'plan', 'settings': {'model': 'gpt-6-astra'}}}}));
    expect(tr.permissionMode, 'plan');
    feed(_n('item/started', {'item': _item('plan', '$_turn-plan', {'text': ''}), 'threadId': _thread, 'turnId': _turn}));
    feed(_n('item/plan/delta', {'threadId': _thread, 'turnId': _turn, 'itemId': '$_turn-plan', 'delta': 'Append'}));
    feed(_n('item/plan/delta', {'threadId': _thread, 'turnId': _turn, 'itemId': '$_turn-plan', 'delta': ' one line to README.md'}));
    expect(tr.messages.last.text, 'Append one line to README.md');
    feed(_n('item/completed', {'item': _item('plan', '$_turn-plan', {'text': 'Append one line to README.md\n\n- Add the line.\n'}), 'threadId': _thread, 'turnId': _turn}));
    feed(_completed());
    expect(tr.turnOpen, isFalse);
    expect(tr.lastResult!.text, startsWith('Append one line'));
    final ask = tr.pending!;
    expect(ask.isPlan, isTrue);
    expect(ask.engine, 'codex');
    expect(ask.plan, 'Append one line to README.md\n\n- Add the line.');
    expect(ask.planTitle, 'Append one line to README.md');
    expect(noticeForAsk(ask, project: 'kit').title, 'Plan ready · kit');
    expect(t.answerLine(ask, AskAnswer.approvePlan(ask)), isNull, reason: 'nobody on the server waits: the next turn is the answer');
    expect(t.asks, isEmpty);
    // Default mode again: no card at the end.
    t.turnStartLine(text: 'Implement the plan.', mode: 'default');
    feed(_n('item/completed', {'item': _item('agentMessage', 'm2', {'text': 'Done.', 'phase': 'final_answer'}), 'threadId': _thread, 'turnId': _turn}));
    tr.pending = null;
    feed(_completed());
    expect(tr.pending, isNull);
  });

  test('/clear is a fresh thread: its response reads as a reset, a new init and a turn of nothing', () {
    final t = _ready();
    final id = (jsonDecode(t.threadStartLine(cwd: '/p', mode: 'default', clear: true)) as Map)['id'] as int;
    final events = t.feed(_threadStartResponse(id, threadId: 'thread-2'));
    expect(events.map((e) => e.runtimeType), [ResetEvent, InitEvent, ResultEvent]);
    expect((events[1] as InitEvent).sessionId, 'thread-2');
    expect((events[2] as ResultEvent).numTurns, 0);
    expect(t.threadId, 'thread-2');
  });

  test('a resume brings the thread\'s turns back as rows', () {
    final turns = [
      {
        'id': 'turn-1',
        'status': 'completed',
        'itemsView': 'full',
        'startedAt': 1789000313,
        'items': [
          _item('userMessage', 'u', {'content': [{'type': 'text', 'text': 'Plan a one-line change to README.md'}]}),
          _item('agentMessage', 'a', {'text': 'I will check the README.', 'phase': 'commentary'}),
          _item('commandExecution', 'c', {'command': "/bin/zsh -lc 'tail -n 3 README.md'", 'cwd': '/p', 'status': 'completed', 'commandActions': [{'type': 'unknown', 'command': 'tail -n 3 README.md'}], 'aggregatedOutput': 'last lines', 'exitCode': 0}),
          _item('plan', 'p', {'text': 'Append one line.'}),
        ],
      },
    ];
    final rows = CodexTranslator.rowsFromTurns(turns);
    expect(rows.map((r) => r.role), [DeckRole.user, DeckRole.assistant, DeckRole.tool, DeckRole.assistant]);
    expect(rows.first.id, startsWith('h'));
    expect(rows[2].toolSummary, 'tail -n 3 README.md');
    expect(rows[2].toolResult, 'last lines');
    expect(rows[2].at, DateTime.utc(2026, 9, 10, 0, 31, 53));
    final t = CodexTranslator();
    final id = (jsonDecode(t.threadStartLine(cwd: '/p', mode: 'default', resume: _thread)) as Map)['id'] as int;
    final events = t.feed(_threadStartResponse(id, turns: turns));
    expect(events.single, isA<InitEvent>());
    expect(t.takeRestored(), hasLength(4));
    expect(t.takeRestored(), isEmpty, reason: 'once');
  });

  test('errors: a refused turn/start closes the turn; a usage limit is the pool refusing; a failed turn ends in an error', () {
    final t = _ready();
    final id = (jsonDecode(t.turnStartLine(text: 'x', mode: 'default')) as Map)['id'] as int;
    final refused = t.feed(jsonEncode({'id': id, 'error': {'code': -32000, 'message': 'active turn cannot be steered'}}));
    expect(refused.map((e) => e.runtimeType), [ControlResponseEvent, ResultEvent]);
    expect((refused[1] as ResultEvent).isError, isTrue);
    expect((refused[1] as ResultEvent).text, 'active turn cannot be steered');

    final t2 = _ready();
    t2.turnStartLine(text: 'x', mode: 'default');
    t2.feed(_rateWeekly);
    final err = t2.feed(_n('error', {'threadId': _thread, 'turnId': _turn, 'willRetry': false, 'error': {'message': 'You have hit your usage limit.', 'codexErrorInfo': 'usageLimitExceeded'}}));
    expect(err.first, isA<RateLimitEvent>());
    expect((err.first as RateLimitEvent).exhausted, isTrue);
    expect((err.first as RateLimitEvent).resetsAt, DateTime.utc(2026, 9, 16, 16, 43, 45), reason: 'the last snapshot\'s reset');
    final done = t2.feed(_completed(status: 'failed', error: {'message': 'You have hit your usage limit.', 'codexErrorInfo': 'usageLimitExceeded'}));
    final result = done.whereType<ResultEvent>().single;
    expect(result.isError, isTrue);
    expect(result.text, 'You have hit your usage limit.');
    expect(done.first, isA<RateLimitEvent>());

    // A five-hour window, and the pool refusing by the account's own word.
    final five = t2.rateLimitEvent({'primary': {'usedPercent': 100, 'windowDurationMins': 300, 'resetsAt': 1789018132}, 'secondary': {'usedPercent': 12, 'windowDurationMins': 10080, 'resetsAt': 1789604932}, 'rateLimitReachedType': 'rate_limit_reached'});
    expect(five.exhausted, isTrue);
    expect(five.fiveHour!.utilization, 1.0);
    expect(five.sevenDay!.utilization, closeTo(0.12, 0.0001));
    expect(five.resetsAt, five.fiveHour!.resetsAt);
    final interrupted = _ready();
    interrupted.turnStartLine(text: 'count', mode: 'default');
    final cut = interrupted.feed(_completed(status: 'interrupted')).whereType<ResultEvent>().single;
    expect(cut.subtype, 'interrupted');
    expect(cut.isError, isFalse);
  });

  test('interrupt and compact are requests on the thread; a request nobody can answer is refused at once; the MCP status and the models are kept', () {
    final t = _ready();
    expect(t.interruptLine(), isNull, reason: 'no turn');
    t.turnStartLine(text: 'x', mode: 'default');
    t.feed(_n('turn/started', {'threadId': _thread, 'turn': {'id': _turn, 'items': [], 'status': 'inProgress'}}));
    final cut = jsonDecode(t.interruptLine()!) as Map;
    expect(cut['method'], 'turn/interrupt');
    expect(cut['params'], {'threadId': _thread, 'turnId': _turn});
    final ok = t.feed(jsonEncode({'id': cut['id'], 'result': {}}));
    expect((ok.single as ControlResponseEvent).ok, isTrue);
    final compact = jsonDecode(t.compactLine()!) as Map;
    expect(compact['method'], 'thread/compact/start');
    expect(t.feed(_n('thread/compacted', {'threadId': _thread, 'turnId': _turn})).single, isA<CompactEvent>());
    expect(t.feed(_n('item/started', {'item': _item('contextCompaction', 'cc', {}), 'threadId': _thread, 'turnId': _turn})).single, isA<StatusEvent>());
    final refused = t.feed(jsonEncode({'method': 'mcpServer/elicitation/request', 'id': 9, 'params': {}}));
    expect(refused.single, isA<OtherEvent>());
    expect(jsonDecode(t.outbox.single), {'jsonrpc': '2.0', 'id': 9, 'error': {'code': -32601, 'message': 'not supported by K.A.T.Y.A'}});
    t.feed(_n('mcpServer/startupStatus/updated', {'threadId': _thread, 'name': 'firebase', 'status': 'ready', 'error': null}));
    expect(t.mcp, {'firebase': 'ready'});
    final models = (jsonDecode(t.modelListLine()) as Map)['id'] as int;
    t.feed(jsonEncode({'id': models, 'result': {'data': [{'id': 'gpt-6-astra', 'hidden': false}, {'id': 'gpt-reserve', 'hidden': true}, {'id': 'gpt-5.5', 'hidden': false}]}}));
    expect(t.models, ['gpt-6-astra', 'gpt-5.5']);
    final skills = (jsonDecode(t.skillsListLine('/p')) as Map)['id'] as int;
    t.feed(jsonEncode({'id': skills, 'result': {'data': [{'cwd': '/p', 'skills': [{'name': 'kit-step', 'path': '/plug/skills/kit-step/SKILL.md', 'enabled': true, 'description': '', 'scope': 'user'}, {'name': 'off', 'path': '/x', 'enabled': false, 'description': '', 'scope': 'user'}], 'errors': []}]}}));
    expect(t.skills, {'kit-step': '/plug/skills/kit-step/SKILL.md'});
    expect(t.feed('not json'), isEmpty);
    expect(t.feed(jsonEncode({'id': 999, 'result': {}})), isEmpty, reason: 'a response to nothing we sent');
  });

  test('an MCP tool, a web search, an agent, a subagent\'s life: rows the Deck knows', () {
    final t = _ready();
    final tr = Transcript();
    void feed(String line) {
      for (final e in t.feed(line)) {
        tr.apply(e);
      }
    }

    feed(_n('item/started', {'item': _item('mcpToolCall', 'm1', {'server': 'cua_repl', 'tool': 'js', 'status': 'inProgress', 'arguments': {'code': 'x', 'title': 'Open'}}), 'threadId': _thread, 'turnId': _turn}));
    expect(tr.messages.last.toolName, 'mcp__cua_repl__js');
    expect(toolLabel(tr.messages.last.toolName!), 'cua_repl · js');
    feed(_n('item/completed', {'item': _item('mcpToolCall', 'm1', {'server': 'cua_repl', 'tool': 'js', 'status': 'failed', 'arguments': {}, 'result': {'content': [{'type': 'text', 'text': 'No browser is available'}]}}), 'threadId': _thread, 'turnId': _turn}));
    expect(tr.messages.last.toolResult, 'No browser is available');
    expect(tr.messages.last.isError, isTrue);
    feed(_n('item/started', {'item': _item('webSearch', 'w1', {'query': 'flutter 3.35'}), 'threadId': _thread, 'turnId': _turn}));
    feed(_n('item/completed', {'item': _item('webSearch', 'w1', {'query': 'flutter 3.35', 'results': [{}, {}]}), 'threadId': _thread, 'turnId': _turn}));
    expect(tr.messages.last.toolSummary, 'WebSearch · flutter 3.35');
    expect(tr.messages.last.toolResult, '2 results');
    feed(_n('item/started', {'item': _item('collabAgentToolCall', 'a1', {'tool': 'spawnAgent', 'prompt': 'write the tests', 'senderThreadId': _thread, 'receiverThreadIds': ['sub-1'], 'agentsStates': {}, 'status': 'inProgress'}), 'threadId': _thread, 'turnId': _turn}));
    final agent = tr.messages.last;
    expect(agent.isAgent, isTrue);
    expect(agent.agentDescription, 'write the tests');
    feed(_n('item/started', {'item': _item('subAgentActivity', 's1', {'agentThreadId': 'sub-1', 'agentPath': '/x', 'kind': 'completed'}), 'threadId': _thread, 'turnId': _turn}));
    expect(agent.progress!['status'], 'completed');
    feed(_n('item/completed', {'item': _item('collabAgentToolCall', 'a1', {'tool': 'spawnAgent', 'senderThreadId': _thread, 'receiverThreadIds': ['sub-1'], 'agentsStates': {'sub-1': {'status': 'completed', 'message': 'done'}}, 'status': 'completed'}), 'threadId': _thread, 'turnId': _turn}));
    expect(agent.toolResult, 'sub-1: completed — done');
    expect(crewOf(tr.messages).single.summary, 'sub-1: completed — done');
  });

  test('an execpolicy rule: what Codex writes, read back and taken out', () {
    const line = 'prefix_rule(pattern=["touch", "/tmp/kit-codex-1"], decision="allow")';
    final r = ExecPolicyRule.parse(line)!;
    expect(r.pattern, ['touch', '/tmp/kit-codex-1']);
    expect(r.decision, 'allow');
    expect(r.line, line);
    expect(ExecPolicyRule.parse('# a comment'), isNull);
    final text = '# rules\n$line\nprefix_rule(pattern=["ls"], decision="allow")\n';
    expect(ExecPolicyRule.parseAll(text).map((x) => x.pattern.join(' ')), ['touch /tmp/kit-codex-1', 'ls']);
    expect(ExecPolicyRule.without(text, ['touch', '/tmp/kit-codex-1']), '# rules\nprefix_rule(pattern=["ls"], decision="allow")\n');
    expect(ExecPolicyRule.without(text, ['rm', '-rf']), isNull);
    final entry = SessionEntry.fromMap({'id': 'x', 'startedAt': '2026-09-10T00:00:00Z', 'engine': 'codex'});
    expect(entry.isCodex, isTrue);
    expect(entry.toMap()['engine'], 'codex');
    expect(SessionEntry.fromMap({'id': 'y', 'startedAt': '2026-09-10T00:00:00Z'}).isCodex, isFalse);
  });
}
