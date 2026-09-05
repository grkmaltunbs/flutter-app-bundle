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
    expect(fresh, isNot(contains('--chrome')));
    final options = bridgeArgs(sessionId: 'abc', permissionMode: 'bypassPermissions', chrome: true, appendSystemPrompt: 'be brief');
    expect(options, containsAllInOrder(['--permission-mode', 'bypassPermissions', '--chrome', '--append-system-prompt', 'be brief', '--session-id', 'abc']));
    expect(fresh, isNot(contains('--append-system-prompt')));
  });

  test('the brief every session gets fits its options', () {
    final withChrome = deckBrief(chrome: true, mode: 'default');
    expect(withChrome, contains('K.A.T.Y.A'));
    expect(withChrome, contains('phone screen'));
    expect(withChrome, contains('Claude in Chrome tools'));
    expect(withChrome, contains('~/.flutter_kit/attachments/'));
    expect(withChrome, contains('AskUserQuestion'));
    expect(withChrome, contains('"Signed in — continue"'));
    expect(withChrome, contains('remote desktop'));
    expect(withChrome, contains('Never type or guess a password'));
    expect(withChrome, contains('cannot undo'));
    expect(withChrome, contains('may wait for the user to allow'));
    expect(withChrome, contains('subagent'));
    final without = deckBrief(chrome: false, mode: 'bypassPermissions');
    expect(without, contains('no browser tools'));
    expect(without, contains('Drive Chrome'));
    expect(without, contains('runs without asking'));
    expect(without, isNot(contains('Claude in Chrome tools')));
    expect(without, contains('"Signed in — continue"'), reason: 'a sign-in is asked for either way');
  });

  test('init names the MCP servers; a browser tool reads as one', () {
    final e = parseBridgeLine('{"type":"system","subtype":"init","session_id":"s1","model":"m","permissionMode":"bypassPermissions","tools":["Bash","mcp__claude-in-chrome__find"],"mcp_servers":[{"name":"claude-in-chrome","status":"connected"},{"name":"plugin:firebase:firebase","status":"pending"}]}') as InitEvent;
    expect(e.mcpServers, {'claude-in-chrome': 'connected', 'plugin:firebase:firebase': 'pending'});
    expect(e.permissionMode, 'bypassPermissions');
    final t = Transcript()..apply(e);
    expect(t.mcpServers['claude-in-chrome'], 'connected');

    expect(toolLabel('Bash'), 'Bash');
    expect(toolLabel('mcp__claude-in-chrome__find'), 'chrome · find');
    expect(toolLabel('mcp__plugin_firebase_firebase__firestore_get_document'), 'firebase_firebase · firestore_get_document');
    final row = DeckMessage(id: 'x', role: DeckRole.tool, text: '', at: DateTime(2026), toolName: 'mcp__claude-in-chrome__navigate', toolInput: const {'url': 'https://appstoreconnect.apple.com'});
    expect(row.toolSummary, 'chrome · navigate · https://appstoreconnect.apple.com');
    final ask = Ask(requestId: 'r', toolName: 'mcp__claude-in-chrome__form_input', toolUseId: 't', input: const {'ref': 'ref_3', 'text': 'K.A.T.Y.A'}, at: DateTime(2026));
    expect(ask.summary, startsWith('chrome · form_input {'));
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
    expect(parseBridgeLine('{"type":"system","subtype":"status"}'), isA<StatusEvent>().having((e) => e.permissionMode, 'permissionMode', isNull));
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

  test('always hands the suggestions back as updatedPermissions; the key names the exact request', () {
    final ask = (parseBridgeLine(_askBash) as AskEvent).ask;
    final a = AskAnswer.always(ask);
    expect(a.appliesAlways, isTrue);
    expect(a.allowed, isTrue);
    expect(a.response['updatedPermissions'], ask.suggestions);
    expect(a.response['updatedInput'], ask.input);
    expect(AskAnswer.allow(ask).appliesAlways, isFalse);
    // Through the relay and back.
    final back = AskAnswer.fromMap(a.toMap());
    expect(back.response, a.response);
    expect(back.summary, 'Allowed, always');
    expect(back.allowed, isTrue);
    // The same command is the same key; a different one is not.
    final same = Ask.fromMap(ask.toMap());
    expect(same.key, ask.key);
    final other = Ask.fromMap({...ask.toMap(), 'input': {'command': 'touch other.txt'}});
    expect(other.key, isNot(ask.key));
    // A note of the caller's choosing.
    final t = Transcript()..apply(AskEvent(ask));
    t.answer(AskAnswer.allow(ask), note: 'Allowed (this session): touch spike-permission.txt');
    expect(t.messages.single.text, startsWith('Allowed (this session)'));
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

  test('a scoped turn belongs to its item from the question to the result', () {
    final t = Transcript();
    t.addUser('What does friends-only cost in reads?', about: {'item': 'presence'});
    expect(threadKey(t.lastAbout), 'item:presence');
    t.apply(const TextDeltaEvent('About '));
    t.apply(const AssistantEvent([ContentBlock.text('About 50 reads per open.')]));
    t.apply(const AssistantEvent([ContentBlock.toolUse(toolUseId: 't1', toolName: 'Bash', toolInput: {'command': 'kit show presence'})]));
    t.apply(const ToolResultEvent(toolUseId: 't1', content: 'ok'));
    t.apply(const ResultEvent(subtype: 'success', sessionId: 's'));
    expect(t.messages.map((m) => threadKey(m.about)).toList(), ['item:presence', 'item:presence', 'item:presence'],
        reason: 'the user row, the reply and the tool row all carry the scope');

    // The next, unscoped turn is not dragged into the thread.
    t.addUser('and now something else');
    t.apply(const AssistantEvent([ContentBlock.text('Something else.')]));
    expect(t.messages.last.about, isNull);
    expect(t.lastAbout, isNull, reason: 'an unscoped send closes the scope');
    expect(threadKey({'step': 'instrument-skin'}), 'step:instrument-skin');
    expect(threadKey(null), isNull);
    expect(threadKey({'item': ''}), isNull);
  });

  test('the user message line is what the CLI expects — text alone, or images then text', () {
    expect(jsonDecode(encodeUserMessage('/step')), {
      'type': 'user',
      'message': {'role': 'user', 'content': '/step'},
    });
    expect(jsonDecode(encodeUserMessage('What colour?', images: const [InlineImage(mediaType: 'image/png', data: 'AAAA')])), {
      'type': 'user',
      'message': {
        'role': 'user',
        'content': [
          {'type': 'image', 'source': {'type': 'base64', 'media_type': 'image/png', 'data': 'AAAA'}},
          {'type': 'text', 'text': 'What colour?'},
        ],
      },
    });
  });

  test('files travel on the row and in the prompt', () {
    const shot = DeckAttachment(name: 'shot.png', mime: 'image/png', size: 412 * 1024, path: '/Users/x/.flutter_kit/attachments/p/shot.png');
    const pdf = DeckAttachment(name: 'spec.pdf', mime: 'application/pdf', size: 3 * 1024 * 1024);
    final prompt = attachmentsPrompt('Look at this.', [shot, pdf], inline: {0});
    expect(prompt, startsWith('Look at this.\n\n--- attached'));
    expect(prompt, contains('- shot.png — image/png, 412 KB — /Users/x/.flutter_kit/attachments/p/shot.png (shown above)'));
    expect(prompt, contains('- spec.pdf — application/pdf, 3.0 MB\n'));
    expect(prompt, endsWith('--- end ---'));
    expect(attachmentsPrompt('', [shot]), startsWith('See the attached file.'));
    expect(attachmentsPrompt('', [shot, pdf]), startsWith('See the attached files.'));
    expect(attachmentsPrompt('plain', const []), 'plain');
    expect(shot.isImage, isTrue);
    expect(pdf.isImage, isFalse);

    final t = Transcript();
    final m = t.addUser('', attachments: const [shot]);
    final back = DeckMessage.fromMap(jsonDecode(jsonEncode(m.toMap())) as Map<String, Object?>);
    expect(back.attachments.single.name, 'shot.png');
    expect(back.attachments.single.path, shot.path);
    expect(back.attachments.single.size, 412 * 1024);
    expect(m.toMap().containsKey('attachments'), isTrue);
    expect(t.addUser('no files').toMap().containsKey('attachments'), isFalse);
    expect(DeckMessage.fromMap({'id': 'x', 'role': 'user', 'text': 'old row', 'at': '2026-08-30T12:00:00Z'}).attachments, isEmpty, reason: 'rows from before carry none');
  });

  test('a notification says what the session wants: allow, a question, a sign-in, a problem', () {
    final ask = (parseBridgeLine(_askBash)! as AskEvent).ask;
    final n = noticeForAsk(ask, project: 'kit');
    expect(n.kind, NoticeKind.permission);
    expect(n.title, 'Allow Run? · kit');
    expect(n.body, ask.summary);
    expect(n.requestId, ask.requestId);
    expect(n.data('kit'), {'slug': 'kit', 'kind': 'permission', 'requestId': ask.requestId});

    final q = (parseBridgeLine(_askQuestion)! as AskEvent).ask;
    expect(q.isSignIn, isFalse);
    final qn = noticeForAsk(q, project: 'kit');
    expect(qn.kind, NoticeKind.question);
    expect(qn.title, 'Claude asks · kit');
    expect(qn.body, 'Tea or coffee?');

    // The sign-in question the brief shapes: one option, the exact label.
    final signIn = Ask.fromMap({
      'requestId': 'req_s',
      'toolName': 'AskUserQuestion',
      'toolUseId': 'toolu_s',
      'at': '2026-09-03T10:00:00Z',
      'input': {
        'questions': [
          {'question': 'App Store Connect wants a sign-in (tab 2). Sign in on the Mac, then continue.', 'header': 'Sign in', 'options': [{'label': 'Signed in — continue', 'description': ''}]}
        ]
      },
    });
    expect(signIn.isSignIn, isTrue);
    final sn = noticeForAsk(signIn, project: 'kit');
    expect(sn.kind, NoticeKind.signIn);
    expect(sn.title, 'Sign in needed · kit');
    expect(sn.body, startsWith('App Store Connect wants a sign-in'));
    expect(sn.isAsk, isTrue);

    final chrome = Ask.fromMap({'requestId': 'r', 'toolName': 'mcp__claude-in-chrome__navigate', 'toolUseId': 't', 'at': '2026-09-03T10:00:00Z', 'input': {'url': 'https://example.com'}});
    expect(noticeForAsk(chrome, project: 'kit').title, 'Allow chrome · navigate? · kit');

    final p = noticeForProblem('claude exited with code 1 — boom', project: 'kit');
    expect(p.kind, NoticeKind.problem);
    expect(p.title, 'Problem · kit');
    expect(p.body, 'claude exited with code 1 — boom');
    expect(p.requestId, isNull);
    expect(p.isAsk, isFalse);
    expect(p.data('kit'), {'slug': 'kit', 'kind': 'problem'});
    expect(noticeForProblem('x' * 500, project: 'kit').body.length, 240, reason: 'clipped for a lock screen');

    expect(deckBrief(chrome: true, mode: 'default'), contains('"$signedInOption"'), reason: 'the brief and the detector agree on the label');
    expect(deckBrief(chrome: false, mode: 'default'), contains('PushNotification tool has no route'), reason: 'a session is told the app notifies, so it stops trying the built-in tool');

    final done = noticeForDone(const ResultEvent(subtype: 'success', sessionId: 's', durationMs: 85_000, text: 'All 3383 tests passed.'), project: 'Nahmatik');
    expect(done.kind, NoticeKind.done);
    expect(done.title, 'Done in 1m 25s · Nahmatik');
    expect(done.body, 'All 3383 tests passed.');
    expect(done.channel, 'done');
    expect(done.isAsk, isFalse);
    expect(noticeForDone(const ResultEvent(subtype: 'success', sessionId: 's', durationMs: 4_000), project: 'kit').title, 'Done · kit', reason: 'under a minute, the time is not worth a word');
    expect(noticeForDone(const ResultEvent(subtype: 'success', sessionId: 's'), project: 'kit').body, 'The turn ended.');
    expect(n.channel, 'asks');
    expect(p.channel, 'problems');

    final note = noticeForNote('  Build uploaded to TestFlight. ', project: 'Nahmatik');
    expect(note.kind, NoticeKind.note);
    expect(note.title, 'Claude · Nahmatik');
    expect(note.body, 'Build uploaded to TestFlight.');
    expect(note.channel, 'done');
    expect(deckBrief(chrome: false, mode: 'default'), contains('kit notify'), reason: 'a session is told how to say something mid-task');
  });

  test('a notification offers one-tap answers: Allow / Deny, a short single question, a sign-in — and no button for the rest', () {
    final bash = (parseBridgeLine(_askBash)! as AskEvent).ask;
    expect(noticeActions(bash).map((a) => '${a.id}=${a.label}'), ['allow=Allow', 'deny=Deny']);
    expect(noticeForAsk(bash, project: 'kit').actions, hasLength(2));
    final allow = answerForAction(bash, 'allow')!;
    expect(allow.response, {'behavior': 'allow', 'updatedInput': bash.input});
    expect(allow.allowed, isTrue);
    final deny = answerForAction(bash, 'deny')!;
    expect(deny.response, {'behavior': 'deny', 'message': 'The user declined from the notification.'});
    expect(deny.allowed, isFalse);
    expect(answerForAction(bash, 'deny', here: 'lock screen')!.response['message'], 'The user declined from the lock screen.');
    expect(answerForAction(bash, 'option:0'), isNull, reason: 'a button this ask never offered');
    expect(answerForAction(bash, ''), isNull);

    final q = (parseBridgeLine(_askQuestion)! as AskEvent).ask;
    expect(noticeActions(q).map((a) => '${a.id}=${a.label}'), ['option:0=Tea', 'option:1=Coffee']);
    final tea = answerForAction(q, 'option:0')!;
    expect(tea.response['updatedInput'], {...q.input, 'answers': {'Tea or coffee?': 'Tea'}});
    expect(tea.summary, 'Tea');
    expect(answerForAction(q, 'option:2'), isNull);
    expect(answerForAction(q, 'allow'), isNull, reason: 'a question is not allowed, it is answered');

    Ask question(List<Map<String, Object?>> questions) => Ask.fromMap({'requestId': 'r', 'toolName': 'AskUserQuestion', 'toolUseId': 't', 'at': '2026-09-04T10:00:00Z', 'input': {'questions': questions}});
    Map<String, Object?> one(String text, List<String> labels, {bool multi = false}) => {'question': text, 'header': 'H', 'multiSelect': multi, 'options': [for (final l in labels) {'label': l, 'description': ''}]};
    final signIn = question([one('Sign in to the App Store, then continue.', [signedInOption])]);
    expect(signIn.isSignIn, isTrue);
    expect(noticeActions(signIn).map((a) => a.label), [signedInOption]);
    expect(answerForAction(signIn, 'option:0')!.summary, signedInOption);
    expect(noticeActions(question([one('A?', ['x', 'y'], multi: true)])), isEmpty, reason: 'a multi-select is not one tap');
    expect(noticeActions(question([one('A?', ['x']), one('B?', ['y'])])), isEmpty, reason: 'two questions need the card');
    expect(noticeActions(question([one('A?', ['a', 'b', 'c', 'd'])])), isEmpty, reason: 'Android shows three buttons');
    expect(noticeActions(question([one('A?', ['a', 'a label far too long for a lock screen button'])])), isEmpty);
    expect(noticeActions(question([one('A?', ['a', 'b', 'c'])])), hasLength(3));

    final flip = noticeForStep(number: '6b', title: '  Notification actions — Allow and Deny from the lock screen ', project: 'Kit');
    expect(flip.kind, NoticeKind.step);
    expect(flip.title, 'Step 6b done · Kit');
    expect(flip.body, 'Notification actions — Allow and Deny from the lock screen');
    expect(flip.channel, 'steps');
    expect(flip.actions, isEmpty);
    expect(flip.data('kit'), {'slug': 'kit', 'kind': 'step'});
  });

  test('the dials become flags; default leaves the CLI to itself', () {
    expect(bridgeArgs(sessionId: 'abc', model: 'opus', effort: 'high'), containsAllInOrder(['--model', 'opus', '--effort', 'high']));
    final plain = bridgeArgs(sessionId: 'abc');
    expect(plain, isNot(contains('--model')));
    expect(plain, isNot(contains('--effort')));
    expect(modelChoices.first, 'default');
    expect(effortChoices, ['default', 'low', 'medium', 'high', 'xhigh', 'max']);
  });

  test('the mode dial: the CLI\'s modes, their words, and the stdin line that switches one in place', () {
    expect(modeChoices, ['default', 'plan', 'acceptEdits', 'bypassPermissions']);
    expect(modeChoices.map(modeLabel), ['default', 'plan', 'accept edits', 'bypass']);
    expect(knownMode('plan'), 'plan');
    expect(knownMode('skip'), 'default', reason: 'a word this build does not have');
    expect(knownMode(null), 'default');
    final line = jsonDecode(encodeSetPermissionMode('mode-1', 'plan')) as Map;
    expect(line['type'], 'control_request');
    expect(line['request_id'], 'mode-1');
    expect(line['request'], {'subtype': 'set_permission_mode', 'mode': 'plan'});
    expect(bridgeArgs(sessionId: 'abc', permissionMode: 'plan'), containsAllInOrder(['--permission-mode', 'plan']));
    expect(deckBrief(chrome: false, mode: 'plan'), contains('ExitPlanMode'));
    expect(deckBrief(chrome: false, mode: 'acceptEdits'), contains('may wait for the user to allow'));
    // What the CLI says back: the response, then a status the transcript takes.
    final ok = parseBridgeLine('{"type":"control_response","response":{"subtype":"success","request_id":"mode-1","response":{"mode":"plan"}}}') as ControlResponseEvent;
    expect(ok.ok, isTrue);
    expect(ok.requestId, 'mode-1');
    expect(ok.response['mode'], 'plan');
    final bad = parseBridgeLine('{"type":"control_response","response":{"subtype":"error","request_id":"mode-2","error":"nope"}}') as ControlResponseEvent;
    expect(bad.ok, isFalse);
    expect(bad.error, 'nope');
    final t = Transcript();
    t.apply(parseBridgeLine('{"type":"system","subtype":"init","session_id":"s1","model":"m","permissionMode":"default"}')!);
    expect(t.permissionMode, 'default');
    t.apply(parseBridgeLine('{"type":"system","subtype":"status","status":null,"permissionMode":"plan"}')!);
    expect(t.permissionMode, 'plan');
    t.apply(parseBridgeLine('{"type":"system","subtype":"status","status":"compacting"}')!);
    expect(t.permissionMode, 'plan', reason: 'a status without a mode changes nothing');
  });

  test('ExitPlanMode is a plan: the card\'s words, the one lock-screen button, approve with a mode, revise with words', () {
    final e = parseBridgeLine('{"type":"control_request","request_id":"r9","request":{"subtype":"can_use_tool","tool_name":"ExitPlanMode","display_name":"ExitPlanMode","input":{"plan":"# Plan: a settings screen\\n\\n## Steps\\n- one\\n- two\\n","planFilePath":"/Users/me/.claude/plans/x.md"},"tool_use_id":"t9","requires_user_interaction":true}}') as AskEvent;
    final ask = e.ask;
    expect(ask.isPlan, isTrue);
    expect(ask.isQuestion, isFalse);
    expect(ask.plan, startsWith('# Plan: a settings screen'));
    expect(ask.planTitle, 'Plan: a settings screen');
    expect(ask.summary, 'Plan: a settings screen');
    expect(Ask.fromMap(ask.toMap()).plan, ask.plan, reason: 'the plan rides the relay in the input');
    final n = noticeForAsk(ask, project: 'Nahmatik');
    expect(n.kind, NoticeKind.plan);
    expect(n.title, 'Plan ready · Nahmatik');
    expect(n.body, 'Plan: a settings screen');
    expect(n.channel, 'asks');
    expect(n.isAsk, isTrue);
    expect(n.actions.map((a) => '${a.id}=${a.label}'), ['allow=Approve']);
    final approve = answerForAction(ask, 'allow')!;
    expect(approve.allowed, isTrue);
    expect(approve.modeAfter, 'default');
    expect(approve.appliesAlways, isFalse, reason: 'a setMode is not a rule for a settings file');
    expect(approve.response['updatedPermissions'], [
      {'type': 'setMode', 'mode': 'default', 'destination': 'session'}
    ]);
    expect(answerForAction(ask, 'deny'), isNull, reason: 'revise needs words');
    final auto = AskAnswer.approvePlan(ask, mode: 'acceptEdits');
    expect(auto.modeAfter, 'acceptEdits');
    expect(auto.summary, contains('edits'));
    expect(AskAnswer.fromMap(auto.toMap()).modeAfter, 'acceptEdits');
    final revise = AskAnswer.revisePlan('  keep it to one file ');
    expect(revise.allowed, isFalse);
    expect(revise.response['behavior'], 'deny');
    expect(revise.response['message'], 'The user asks for changes to the plan: keep it to one file\nRevise the plan and call ExitPlanMode again.');
    expect(revise.summary, 'Revise: keep it to one file');
    // An edit's "allow all edits" suggestion is a session mode too — not a rule.
    final edit = Ask(requestId: 'r1', toolName: 'Edit', toolUseId: 't1', input: {'file_path': 'a.dart'}, at: DateTime(2026), suggestions: [
      {'type': 'setMode', 'mode': 'acceptEdits', 'destination': 'session'}
    ]);
    expect(AskAnswer.always(edit).modeAfter, 'acceptEdits');
    expect(AskAnswer.always(edit).appliesAlways, isFalse);
    expect(AskAnswer.allow(edit).modeAfter, isNull);
    final m = DeckMessage(id: 'm', role: DeckRole.tool, text: '', at: DateTime(2026), toolName: 'ExitPlanMode', toolInput: ask.input);
    expect(m.toolSummary, 'proposed a plan');
    final blank = Ask(requestId: 'r2', toolName: 'ExitPlanMode', toolUseId: 't2', input: {'plan': '   '}, at: DateTime(2026));
    expect(blank.summary, 'A plan is ready');
  });

  test('an option\'s preview rides along', () {
    final q = AskQuestion.fromMap({
      'question': 'Which layout?',
      'header': 'Layout',
      'options': [
        {'label': 'Stacked', 'description': 'one column', 'preview': '| a |\n| b |'},
        {'label': 'Side by side', 'preview': '   '},
      ],
    });
    expect(q.options[0].preview, '| a |\n| b |');
    expect(q.options[1].preview, isNull, reason: 'blank is none');
    expect(q.options[0].toMap()['preview'], '| a |\n| b |');
    expect(q.options[1].toMap().containsKey('preview'), isFalse);
  });

  test('interrupt and set_model lines; a queued row rides the relay; the transcript holds, releases and drops it', () {
    final i = jsonDecode(encodeInterrupt('int-1')) as Map;
    expect(i['type'], 'control_request');
    expect(i['request_id'], 'int-1');
    expect(i['request'], {'subtype': 'interrupt'});
    final m = jsonDecode(encodeSetModel('model-1', 'haiku')) as Map;
    expect(m['request'], {'subtype': 'set_model', 'model': 'haiku'});
    final t = Transcript();
    final first = t.addUser('count');
    expect(t.turnOpen, isTrue);
    final q = t.addUser('and then say done', about: {'step': 's1'}, queued: true);
    expect(q.queued, isTrue);
    expect(t.messages.length, 2);
    expect(DeckMessage.fromMap(q.toMap()).queued, isTrue);
    expect(first.toMap().containsKey('queued'), isFalse);
    expect(t.lastAbout, isNull, reason: 'a queued row does not take the scope yet');
    t.release(q);
    expect(q.queued, isFalse);
    expect(t.turnOpen, isTrue);
    expect(t.lastAbout, {'step': 's1'});
    final gone = t.addUser('never mind', queued: true);
    expect(t.dropQueued(gone.id), isTrue);
    expect(t.messages.map((r) => r.id), isNot(contains(gone.id)));
    expect(t.dropQueued(first.id), isFalse, reason: 'not queued');
    // What the CLI echoes on an interrupt and a set_model are user lines the transcript ignores.
    t.apply(parseBridgeLine('{"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}')!);
    t.apply(parseBridgeLine('{"type":"user","message":{"role":"user","content":"<local-command-stdout>Set model to `haiku`</local-command-stdout>"},"isReplay":true}')!);
    expect(t.messages.length, 2);
    final r = parseBridgeLine('{"type":"control_response","response":{"subtype":"success","request_id":"int-1","response":{"still_queued":[]}}}') as ControlResponseEvent;
    expect(r.ok, isTrue);
    expect(r.response['still_queued'], isEmpty);
  });
}
