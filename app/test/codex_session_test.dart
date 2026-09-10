// The bridge on the Codex engine: the same runner, a scripted app-server —
// and, under KIT_LIVE=1, the real one (it spends the ChatGPT pool).
import 'dart:io';

import 'package:flutter/material.dart' hide Step, StepState;
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/host/codex_cli.dart';
import 'package:kit_app/src/host/codex_engine.dart';
import 'package:kit_app/src/host/engine.dart';
import 'package:kit_app/src/screens/ask_card.dart';
import 'package:kit_app/src/screens/deck_tab.dart';
import 'package:kit_app/src/theme.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_claude.dart';
import 'helpers/fake_codex.dart';

Widget _app(Widget child, {Size size = const Size(390, 844), double scale = 1.0}) => MaterialApp(
      theme: kitTheme(KitTokens.dark),
      home: MediaQuery(data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)), child: Scaffold(body: child)),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

void main() {
  late Directory home;
  late Directory project;
  late Directory codexHome;
  setUp(() {
    home = Directory.systemTemp.createTempSync('kit_codex_home_');
    project = Directory.systemTemp.createTempSync('kit_codex_project_');
    codexHome = Directory.systemTemp.createTempSync('kit_codex_dotcodex_');
  });
  tearDown(() {
    home.deleteSync(recursive: true);
    project.deleteSync(recursive: true);
    codexHome.deleteSync(recursive: true);
  });

  test('Start on Codex: app-server, the handshake by itself, the thread as the session; the record says codex', () async {
    final fake = FakeCodex();
    final s = codexSession(fake, dir: project.path, home: home.path);
    expect(s.engineId, 'codex');
    expect(s.previous()!.engine, 'codex', reason: 'the notch is in the record before any session');
    expect(s.engineLabel, 'Codex');
    await s.start();
    expect(fake.startedWith, ['app-server', '--stdio', '--enable', 'default_mode_request_user_input']);
    expect(fake.startedIn, project.path);
    await fake.requested('thread/start');
    await pumpEventQueue();
    expect(fake.requests.map((r) => r.method), ['initialize', 'model/list', 'skills/list', 'thread/start', 'account/rateLimits/read']);
    expect(fake.written.any((l) => l.contains('"method":"initialized"')), isTrue);
    final start = fake.lastParams('thread/start');
    expect(start['cwd'], project.path);
    expect(start['approvalPolicy'], 'untrusted');
    expect(start['sandbox'], 'workspace-write');
    expect(start['developerInstructions'], contains('request_user_input'));
    expect(start['developerInstructions'], contains('K.A.T.Y.A'));
    expect(s.state, BridgeState.ready);
    expect(s.sessionId, fakeThread);
    expect(s.transcript.model, 'gpt-6-astra');
    expect(s.transcript.permissionMode, 'default');
    expect(s.cliVersion, '0.153.4');
    expect(s.sessions.single.id, fakeThread);
    expect(s.sessions.single.engine, 'codex');
    expect(s.sessions.single.model, 'gpt-6-astra');
    expect(s.previous()!.sessionId, fakeThread);
    expect(s.previous()!.sessions.single.isCodex, isTrue);
    expect(s.engine.models, ['gpt-6-astra', 'gpt-5.5']);
    expect(s.knowsCommand('step'), isTrue);
    expect(s.knowsCommand('board'), isFalse);
    final relay = s.toRelay();
    expect(relay['engine'], 'codex');
    expect(relay['provenOn'], codexProvenOn);
    expect(relay['models'], ['gpt-6-astra', 'gpt-5.5']);
    expect(relay['cliVersion'], '0.153.4');
    expect(relay['rules'], ['CLAUDE.md'], reason: 'the RULES fact — what Codex loaded for the folder');
    expect(relay['chromeStatus'], 'off', reason: 'no cua_repl listed yet');
    expect(s.transcript.pool!.sevenDay!.utilization, closeTo(0.09, 0.0001), reason: 'read at the start');
    await s.stop();
    expect(s.state, BridgeState.stopped);
  });

  test('the plugin root reaches the sandbox as its real path — Codex refuses a symlinked writable root', () async {
    // The cache Codex lists the skills from is a symlink to the checkout
    // (README); the sandbox wants the folder behind it (0.153.4, probed
    // 2026-09-10).
    final checkout = Directory(p.join(project.path, 'checkout'))..createSync();
    Directory(p.join(checkout.path, 'kit')).createSync();
    final cache = Link(p.join(project.path, 'cache'))..createSync(checkout.path);
    final fake = FakeCodex(skills: {'flutter-kit:kit-step': '${cache.path}/skills/kit-step/SKILL.md'});
    final s = codexSession(fake, dir: project.path, home: home.path);
    await s.start();
    await fake.requested('thread/start');
    await pumpEventQueue();
    s.send('hi');
    await fake.requested('turn/start');
    final roots = ((fake.lastParams('turn/start')['sandboxPolicy'] as Map)['writableRoots'] as List).cast<String>();
    expect(roots.last, Directory(p.join(checkout.path, 'kit')).resolveSymbolicLinksSync(), reason: 'the real path, not the cache symlink');
    expect(roots.last, isNot(contains('/cache/')));
    expect(roots, isNot(contains(contains('anthropic-skills'))), reason: 'the other plugin is not the kit');
    expect(roots.where((r) => r.endsWith('/kit')).length, 1);
    expect(roots.first, '/fake/flutter/bin/cache', reason: 'a root that does not exist goes as it is');
    await s.stop();
  });

  test('a turn: the message is a turn/start with the dials on it; the reply streams; the end counts', () async {
    final fake = FakeCodex();
    final s = codexSession(fake, dir: project.path, home: home.path);
    s.setOptions(model: 'gpt-5.5', effort: 'high', mode: 'acceptEdits');
    await s.start();
    await fake.requested('thread/start');
    await pumpEventQueue();
    expect(s.send('what model are you?'), isFalse);
    await fake.requested('turn/start');
    final turn = fake.lastParams('turn/start');
    expect(turn['threadId'], fakeThread);
    expect(turn['input'], [{'type': 'text', 'text': 'what model are you?'}]);
    expect(turn['model'], 'gpt-5.5');
    expect(turn['effort'], 'high');
    expect(turn['approvalPolicy'], 'on-request');
    expect(turn['sandboxPolicy'], {'type': 'workspaceWrite', 'writableRoots': ['/fake/flutter/bin/cache', '/plugin/kit']}, reason: 'the SDK cache and the plugin\'s kit folder, so the kit runs inside the sandbox');
    expect(turn['collaborationMode'], {'mode': 'default', 'settings': {'model': 'gpt-5.5'}});
    expect(s.state, BridgeState.busy);
    expect(s.transcript.turnOpen, isTrue);
    fake.scriptTurn();
    await pumpEventQueue();
    expect(s.state, BridgeState.ready);
    final rows = s.transcript.messages;
    expect(rows.map((m) => m.role), [DeckRole.user, DeckRole.assistant]);
    expect(rows.last.text, 'I am GPT-6-Astra.');
    expect(rows.last.streaming, isFalse);
    expect(s.transcript.deltasSeen, 2);
    expect(s.transcript.lastResult!.text, 'I am GPT-6-Astra.');
    expect(s.transcript.contextUsed, 19318);
    expect(s.transcript.contextWindow, 258400);
    expect(s.current!.turns, 1);
    expect(s.current!.firstMessage, 'what model are you?');
    expect(s.lastTurnInterrupted, isFalse);
  });

  test('a message before the thread exists waits for it, then goes; one sent mid-turn queues behind the turn', () async {
    final fake = FakeCodex(holdThread: true);
    final s = codexSession(fake, dir: project.path, home: home.path);
    await s.start();
    await fake.requested('thread/start');
    // The thread takes its time: the session is still starting.
    expect(s.state, BridgeState.starting);
    expect(s.send('hello'), isTrue, reason: 'queued until the thread');
    expect(s.transcript.messages.single.queued, isTrue);
    fake.releaseThread();
    await fake.requested('turn/start');
    await pumpEventQueue();
    expect(s.transcript.messages.single.queued, isFalse);
    expect(s.state, BridgeState.busy);
    expect(s.send('and then'), isTrue, reason: 'a turn runs');
    fake.scriptTurn();
    await fake.requested('turn/start', times: 2);
    expect(fake.lastParams('turn/start')['input'], [{'type': 'text', 'text': 'and then'}]);
    // A command is the skill Codex listed for it, with the words after.
    fake.scriptTurn();
    await pumpEventQueue();
    s.send('/step spin', by: 'autopilot');
    await fake.requested('turn/start', times: 3);
    expect(fake.lastParams('turn/start')['input'], [
      {'type': 'skill', 'name': 'flutter-kit:kit-step', 'path': '/plugin/skills/kit-step/SKILL.md'},
      {'type': 'text', 'text': r'Use the $kit-step skill with: spin'},
    ]);
    expect(s.knowsCommand('step'), isTrue);
    expect(s.knowsCommand('board'), isFalse);
  });

  test('a question comes as a card in Codex\'s name; the answer goes back under the question\'s id and the turn goes on', () async {
    final fake = FakeCodex();
    final s = codexSession(fake, dir: project.path, home: home.path);
    final asks = <Ask>[];
    s.onAsk = asks.add;
    await s.start();
    await fake.requested('thread/start');
    await pumpEventQueue();
    s.send('ask me tea or coffee');
    await fake.requested('turn/start');
    fake.scriptQuestion();
    await pumpEventQueue();
    expect(s.state, BridgeState.waiting);
    final ask = s.transcript.pending!;
    expect(ask.isQuestion, isTrue);
    expect(ask.engine, 'codex');
    expect(asks.single.requestId, ask.requestId);
    s.answer(AskAnswer.answers(ask, {ask.questions.single.question: 'Coffee'}), by: 'phone');
    await fake.writtenLines(fake.written.length);
    await pumpEventQueue();
    expect(fake.results[0], {'answers': {'drink': {'answers': ['Coffee']}}});
    expect(s.state, BridgeState.busy);
    expect(s.transcript.pending, isNull);
    expect(s.transcript.messages.last.role, DeckRole.note);
    expect(s.transcript.messages.last.text, 'Answered: Coffee');
    fake.scriptTurn(text: 'You chose coffee.');
    await pumpEventQueue();
    expect(s.transcript.lastResult!.text, 'You chose coffee.');
  });

  test('the browser\'s origin question reaches the phone as a card and ALLOW goes back as accept; the pill follows cua_repl', () async {
    final fake = FakeCodex();
    final s = codexSession(fake, dir: project.path, home: home.path);
    await s.start();
    await fake.requested('thread/start');
    await pumpEventQueue();
    expect(s.chromeStatus, 'off');
    fake.scriptMcpStatus('cua_repl', 'starting');
    await pumpEventQueue();
    expect(s.chromeStatus, 'starting');
    fake.scriptMcpStatus('cua_repl', 'ready');
    await pumpEventQueue();
    expect(s.chromeStatus, 'ready');
    expect(s.toRelay()['chromeStatus'], 'ready');
    s.send('open example.org in Chrome and read the title');
    await fake.requested('turn/start');
    fake.scriptElicitation(origin: 'https://example.org');
    await pumpEventQueue();
    expect(s.state, BridgeState.waiting);
    final ask = s.transcript.pending!;
    expect(ask.isElicitation, isTrue);
    expect(ask.engine, 'codex');
    expect(ask.summary, 'Allow Browser use to access https://example.org?');
    expect(ask.suggestions, isNotEmpty, reason: 'ALWAYS is offered');
    s.answer(AskAnswer.allow(ask), by: 'phone');
    await fake.writtenLines(fake.written.length);
    await pumpEventQueue();
    expect(fake.results[0], {'action': 'accept', 'content': {}});
    expect(s.state, BridgeState.busy);
    expect(s.transcript.pending, isNull);
    fake.scriptElicitation(id: 1, origin: 'https://example.net');
    await pumpEventQueue();
    final second = s.transcript.pending!;
    s.answer(AskAnswer.always(second), by: 'phone');
    await fake.writtenLines(fake.written.length);
    await pumpEventQueue();
    expect(fake.results[1], {'action': 'accept', 'content': {}, '_meta': {'persist': 'always'}}, reason: 'ALWAYS rides as persist: always');
    expect(s.alwaysApplied, isEmpty, reason: 'no rule of the host\'s own — the server keeps it');
    fake.scriptTurn(text: 'Example Domain');
    await pumpEventQueue();
    expect(s.transcript.lastResult!.text, 'Example Domain');
    await s.stop();
  });

  test('bypass mode lets an origin through without a card, and the Deck says which', () async {
    final fake = FakeCodex();
    final s = codexSession(fake, dir: project.path, home: home.path);
    s.setOptions(mode: 'bypassPermissions');
    await s.start();
    await fake.requested('thread/start');
    await pumpEventQueue();
    s.send('open example.com in Chrome');
    await fake.requested('turn/start');
    final turn = fake.lastParams('turn/start');
    expect(turn['approvalPolicy'], 'on-request', reason: 'never would decline the question before the host sees it');
    expect(turn['sandboxPolicy'], {'type': 'dangerFullAccess'});
    fake.scriptElicitation(origin: 'https://example.com');
    await fake.writtenLines(fake.written.length);
    await pumpEventQueue();
    expect(s.transcript.pending, isNull, reason: 'no card');
    expect(fake.results[0], {'action': 'accept', 'content': {}});
    expect(s.state, BridgeState.busy);
    expect(s.transcript.messages.last.role, DeckRole.note);
    expect(s.transcript.messages.last.text, 'Let through (bypass): Allow Browser use to access https://example.com?');
    await s.stop();
  });

  test('a command under default asks; Deny declines and the row says so; Always carries the execpolicy amendment and lands on the Session tab, where it can be taken back', () async {
    final fake = FakeCodex();
    final s = codexSession(fake, dir: project.path, home: home.path, codexHome: codexHome.path);
    await s.start();
    await fake.requested('thread/start');
    await pumpEventQueue();
    s.send('touch a marker');
    await fake.requested('turn/start');
    fake.scriptCommandAsk();
    await pumpEventQueue();
    final ask = s.transcript.pending!;
    expect(ask.toolName, 'Bash');
    expect(ask.summary, 'touch /tmp/kit-codex-1');
    expect(ask.suggestions.single['type'], 'execpolicy');
    expect(s.transcript.messages.where((m) => m.role == DeckRole.tool).single.running, isTrue);
    s.answer(AskAnswer.deny('The user declined from the phone.'), requestId: ask.requestId, by: 'phone');
    await pumpEventQueue();
    expect(fake.results[0], {'decision': 'decline'});
    fake.scriptCommandDone(status: 'declined');
    await pumpEventQueue();
    final row = s.transcript.messages.where((m) => m.role == DeckRole.tool).single;
    expect(row.isError, isTrue);
    expect(row.toolResult, codexDeclinedNote);
    // Always: the amendment goes back; Codex writes the rule; the record lists it.
    fake.scriptCommandAsk(id: 1);
    await pumpEventQueue();
    final again = s.transcript.pending!;
    s.answer(AskAnswer.always(again), requestId: again.requestId);
    await pumpEventQueue();
    expect(fake.results[1], {'decision': {'acceptWithExecpolicyAmendment': {'execpolicy_amendment': ['touch', '/tmp/kit-codex-1']}}});
    expect(s.alwaysApplied.single.isExecpolicy, isTrue);
    expect(s.alwaysApplied.single.ruleString, 'prefix_rule(touch /tmp/kit-codex-1)');
    expect(s.previous()!.always.single.destination, 'execpolicy');
    // As Codex wrote it (2026-09-10), then taken back from the Session tab.
    final rules = File(ExecPolicyRules.fileFor(home: codexHome.path))..createSync(recursive: true);
    rules.writeAsStringSync('prefix_rule(pattern=["touch", "/tmp/kit-codex-1"], decision="allow")\nprefix_rule(pattern=["ls"], decision="allow")\n');
    expect(ExecPolicyRules.contains(['touch', '/tmp/kit-codex-1'], home: codexHome.path), isTrue);
    expect(s.forgetAlways(s.alwaysApplied.single), isTrue);
    expect(rules.readAsStringSync(), 'prefix_rule(pattern=["ls"], decision="allow")\n');
    expect(s.alwaysApplied, isEmpty);
    expect(ExecPolicyRules.read(home: codexHome.path).single.pattern, ['ls']);
    // The same request again is not remembered: Always on Codex is the
    // rule Codex keeps, and this session's memory only holds "this session".
    fake.scriptCommandAsk(id: 2);
    await pumpEventQueue();
    expect(s.transcript.pending, isNull, reason: 'an Always is remembered for this session too');
    expect(fake.results[2], {'decision': 'accept'});
  });

  test('the dials switch on the next turn, nothing restarts; the engine notch waits for a stop; interrupt and compact are requests', () async {
    final fake = FakeCodex();
    final s = codexSession(fake, dir: project.path, home: home.path);
    await s.start();
    await fake.requested('thread/start');
    await pumpEventQueue();
    final pid = s.pid;
    expect(s.setOptions(mode: 'plan', effort: 'ultra', chrome: true, model: 'gpt-5.5'), isTrue);
    expect(s.restartPending, isFalse, reason: 'effort rides on the turn');
    expect(s.modePending, isFalse);
    expect(s.transcript.permissionMode, 'plan', reason: 'the facts line says so at once');
    expect(s.pid, pid);
    expect(s.setEngine('claude'), contains('stop the session first'));
    expect(s.engineId, 'codex');
    s.send('plan it');
    await fake.requested('turn/start');
    final turn = fake.lastParams('turn/start');
    expect(turn['collaborationMode'], {'mode': 'plan', 'settings': {'model': 'gpt-5.5'}});
    expect(turn['sandboxPolicy'], {'type': 'readOnly'});
    expect(turn['effort'], 'ultra');
    expect(s.interrupt(by: 'phone'), isTrue);
    await fake.requested('turn/interrupt');
    expect(fake.lastParams('turn/interrupt'), {'threadId': fakeThread, 'turnId': fakeTurn});
    fake.endTurn(status: 'interrupted');
    await pumpEventQueue();
    expect(s.lastTurnInterrupted, isTrue);
    expect(s.transcript.messages.last.text, 'Interrupted from the phone.');
    expect(s.state, BridgeState.ready);
    expect(s.compact(), 'compacting');
    await fake.requested('thread/compact/start');
    expect(s.transcript.compacting, isTrue);
    fake.notify('thread/compacted', {'threadId': fakeThread, 'turnId': fakeTurn});
    await pumpEventQueue();
    expect(s.transcript.compacting, isFalse);
    expect(s.transcript.messages.last.text, 'Compacted.');
    await s.stop();
    expect(s.setEngine('claude'), 'engine: Claude');
    expect(s.previous()!.engine, 'claude');
    expect(s.engineId, 'claude');
  });

  test('/clear is a fresh thread: the context reads cleared, the session id moves on, the list grows, the loop sees a turn of nothing', () async {
    final fake = FakeCodex();
    final s = codexSession(fake, dir: project.path, home: home.path);
    await s.start();
    await fake.requested('thread/start');
    await pumpEventQueue();
    s.send('first');
    await fake.requested('turn/start');
    fake.scriptTurn();
    await pumpEventQueue();
    fake.threadId = 'thread-2';
    expect(s.send('/clear', by: 'autopilot'), isFalse);
    await fake.requested('thread/start', times: 2);
    expect(fake.lastParams('thread/start')['sessionStartSource'], 'clear');
    await pumpEventQueue();
    expect(s.sessionId, 'thread-2');
    expect(s.sessions.map((e) => e.id), [fakeThread, 'thread-2']);
    expect(s.sessions.first.endedAt, isNotNull);
    expect(s.transcript.lastResult!.numTurns, 0);
    expect(s.transcript.lastTurnRowId, s.lastSent!.id, reason: 'the /clear row\'s own turn ended');
    expect(s.transcript.messages.any((m) => m.text == 'Context cleared.'), isTrue);
    expect(s.transcript.contextUsed, 0);
    expect(s.state, BridgeState.ready);
    s.send('second');
    await fake.requested('turn/start', times: 2);
    expect(fake.lastParams('turn/start')['threadId'], 'thread-2');
  });

  test('plan mode: the plan is the card at the turn\'s end; APPROVE sends the next turn in default mode; REVISE sends the words in plan mode', () async {
    final fake = FakeCodex();
    final s = codexSession(fake, dir: project.path, home: home.path);
    final asks = <Ask>[];
    s.onAsk = asks.add;
    s.setOptions(mode: 'plan');
    await s.start();
    await fake.requested('thread/start');
    await pumpEventQueue();
    s.send('plan a one-line change to README.md');
    await fake.requested('turn/start');
    fake.scriptPlan();
    await pumpEventQueue();
    expect(s.state, BridgeState.waiting);
    final plan = s.transcript.pending!;
    expect(plan.isPlan, isTrue);
    expect(plan.planTitle, 'Append one line to README.md');
    expect(asks.single.isPlan, isTrue);
    expect(s.transcript.lastResult, isNotNull, reason: 'the turn ended; the card stands');
    s.answer(AskAnswer.revisePlan('Add two lines, not one.'), requestId: plan.requestId, by: 'phone');
    await fake.requested('turn/start', times: 2);
    final revise = fake.lastParams('turn/start');
    expect((revise['input'] as List).single, {'type': 'text', 'text': 'The user asks for changes to the plan: Add two lines, not one.\nRevise the plan.'});
    expect(revise['collaborationMode'], {'mode': 'plan', 'settings': {'model': 'gpt-6-astra'}});
    expect(s.modeChoice, 'plan');
    fake.scriptPlan(plan: 'Append two lines.\n', turnId: 'turn-2');
    await pumpEventQueue();
    final again = s.transcript.pending!;
    expect(again.plan, 'Append two lines.');
    s.answer(AskAnswer.approvePlan(again), requestId: again.requestId);
    await fake.requested('turn/start', times: 3);
    final implement = fake.lastParams('turn/start');
    expect((implement['input'] as List).single, {'type': 'text', 'text': 'Implement the plan.'});
    expect(implement['collaborationMode'], {'mode': 'default', 'settings': {'model': 'gpt-6-astra'}});
    expect(implement['approvalPolicy'], 'untrusted');
    expect(s.modeChoice, 'default', reason: 'the dial follows the approval');
    expect(s.transcript.permissionMode, 'default');
    expect(s.transcript.pending, isNull);
    fake.scriptTurn(text: 'Done.', turnId: 'turn-3');
    await pumpEventQueue();
    expect(s.transcript.pending, isNull, reason: 'no card in default mode');
  });

  test('Resume runs the engine that made the session; the thread\'s turns come back as rows; a Claude entry switches the notch back', () async {
    final fake = FakeCodex(turns: [
      {
        'id': 'turn-1',
        'status': 'completed',
        'itemsView': 'full',
        'startedAt': 1789000313,
        'items': [
          {'type': 'userMessage', 'id': 'u', 'content': [{'type': 'text', 'text': 'first words'}]},
          {'type': 'agentMessage', 'id': 'a', 'text': 'Hello.', 'phase': 'final_answer'},
        ],
      },
    ]);
    final s = codexSession(fake, dir: project.path, home: home.path);
    await s.start();
    await fake.requested('thread/start');
    await pumpEventQueue();
    s.send('first words');
    await fake.requested('turn/start');
    fake.scriptTurn(text: 'Hello.');
    await pumpEventQueue();
    await s.stop();
    expect(s.previous()!.sessionId, fakeThread);
    // A host restart: a new runner from the record, resumed.
    final fake2 = FakeCodex(turns: fake.turns);
    final s2 = codexSession(fake2, dir: project.path, home: home.path);
    expect(s2.engineId, 'codex');
    expect(s2.sessions.single.isCodex, isTrue);
    await s2.start(resume: true);
    await fake2.requested('thread/resume');
    expect(fake2.lastParams('thread/resume')['threadId'], fakeThread);
    await pumpEventQueue();
    expect(s2.state, BridgeState.ready);
    expect(s2.sessionId, fakeThread);
    expect(s2.transcript.messages.map((m) => m.role), [DeckRole.user, DeckRole.assistant, DeckRole.note]);
    expect(s2.transcript.messages.first.text, 'first words');
    expect(s2.transcript.messages.last.text, contains('Resumed — the last 2 rows'));
    await s2.stop();
    // A Claude session in the same list: resuming it moves the notch.
    s2.sessions.add(SessionEntry(id: 'claude-1', startedAt: DateTime.now(), firstMessage: 'old words'));
    final claude = FakeClaude();
    final s3 = eitherSession(claude: claude, codex: FakeCodex(), dir: project.path, home: home.path);
    s3.sessions.add(SessionEntry(id: 'claude-1', startedAt: DateTime.now(), firstMessage: 'old words'));
    expect(s3.engineId, 'codex');
    expect(await s3.switchTo(id: 'claude-1'), 'resumed claude-1');
    expect(s3.engineId, 'claude', reason: 'the entry has no engine tag: Claude made it');
    expect(claude.startedWith, containsAllInOrder(['--resume', 'claude-1']));
    expect(s3.previous()!.engine, 'claude');
  });

  testWidgets('the Deck on Codex: the ENGINE notch, Codex\'s dials, the facts line, the browser pill; no overflow at three scales', (tester) async {
    for (final scale in const [1.0, 2.0, 3.12]) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = FakeCodex();
      // A record of its own per scale: the dials dragged at 1.0× must not
      // greet the next pass.
      final scaleHome = Directory.systemTemp.createTempSync('kit_codex_deck_');
      addTearDown(() => scaleHome.deleteSync(recursive: true));
      final s = codexSession(fake, dir: project.path, home: scaleHome.path);
      await tester.pumpWidget(_app(DeckTab(bridge: s), scale: scale));
      await tester.pump();
      expect(find.text('ENGINE · CODEX'), findsOneWidget, reason: '$scale×');
      expect(find.text('BROWSER · OFF'), findsOneWidget, reason: 'idle: no browser server yet');
      expect(find.text('MODEL · DEFAULT'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'idle at $scale×');
      // The MODEL dial's last notch is Codex's, not Claude's.
      await tester.drag(find.byType(Slider).at(1), const Offset(600, 0));
      await tester.pump();
      expect(find.text('MODEL · FABLE'), findsNothing);
      expect(find.text('MODEL · ${codexModelChoices.last.toUpperCase()}'), findsOneWidget);
      await tester.drag(find.byType(Slider).at(2), const Offset(600, 0));
      await tester.pump();
      expect(find.text('EFFORT · ULTRA'), findsOneWidget);
      await s.start();
      await _settle(tester);
      expect(s.state, BridgeState.ready, reason: 'the fake answers the handshake as the pumps run');
      // Running: the controls fold; the chevron brings them back.
      await tester.tap(find.byTooltip('Show session controls'));
      await _settle(tester);
      expect(tester.widget<Slider>(find.byType(Slider).first).onChanged, isNull, reason: 'the engine waits for a stop');
      // With the engine's own list, the dial reads what model/list said.
      await tester.drag(find.byType(Slider).at(1), const Offset(-600, 0));
      await tester.pump();
      await tester.drag(find.byType(Slider).at(1), const Offset(600, 0));
      await tester.pump();
      expect(find.text('MODEL · GPT-5.5'), findsOneWidget, reason: 'the last of what model/list listed');
      expect(find.textContaining('CODEX 0.153.4'), findsOneWidget, reason: 'the facts line names the engine');
      expect(find.textContaining('ride on the next turn'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'running at $scale×');
      s.send('ask me');
      await _settle(tester);
      fake.scriptQuestion();
      await _settle(tester);
      expect(find.text('CODEX ASKS'), findsOneWidget, reason: 'the card in Codex\'s name');
      expect(tester.takeException(), isNull, reason: 'the card at $scale×');
      await s.stop();
      await _settle(tester);
    }
  });

  testWidgets('an ask card from the relay keeps the engine', (tester) async {
    final ask = Ask.fromMap({'requestId': 'cx-1', 'toolName': 'AskUserQuestion', 'toolUseId': 'q', 'input': {'questions': [{'question': 'Tea or coffee?', 'header': 'Drink', 'options': [{'label': 'Tea', 'description': ''}]}]}, 'at': '2026-09-10T00:00:00Z', 'engine': 'codex'});
    await tester.pumpWidget(_app(AskCard(ask: ask, onAnswer: (_, {remember = false}) {})));
    expect(find.text('CODEX ASKS'), findsOneWidget);
    final claude = Ask.fromMap({'requestId': 'c-1', 'toolName': 'AskUserQuestion', 'toolUseId': 'q', 'input': {'questions': []}, 'at': '2026-09-10T00:00:00Z'});
    await tester.pumpWidget(_app(AskCard(ask: claude, onAnswer: (_, {remember = false}) {})));
    expect(find.text('CLAUDE ASKS'), findsOneWidget);
  });

  group('live', () {
    final live = Platform.environment['KIT_LIVE'] == '1';
    test('the real codex answers as a GPT model, asks, honours a denial, and resumes', () async {
      final dir = Directory(p.join(Directory.systemTemp.path, 'kit_codex_live_${DateTime.now().millisecondsSinceEpoch}'))..createSync();
      final s = BridgeSession(dir: dir.path, home: home.path, engines: (id) => id == 'codex' ? CodexEngine() : ClaudeEngine());
      s.setEngine('codex');
      final asks = <Ask>[];
      s.onAsk = asks.add;
      try {
        await s.start();
        expect(await s.awaitReady(timeout: const Duration(seconds: 60)), isTrue, reason: s.error ?? s.log.join('\n'));
        expect(s.cliVersion, isNotNull);
        s.send('What model are you? Answer in five words.');
        await _until(() => s.transcript.lastResult != null, const Duration(seconds: 120));
        expect(s.transcript.lastResult!.isError, isFalse, reason: s.transcript.lastResult!.text);
        expect(s.transcript.messages.last.text.toLowerCase(), contains('gpt'));
        expect(s.transcript.model, startsWith('gpt'));
        final marker = File('/tmp/kit-codex-live-${DateTime.now().millisecondsSinceEpoch}');
        s.send('Run exactly this shell command and nothing else: touch ${marker.path} . Then say in one line whether it ran.');
        await _until(() => s.transcript.pending != null, const Duration(seconds: 120));
        expect(s.transcript.pending!.summary, contains('touch'));
        s.answer(AskAnswer.deny('The user declined from the phone.'));
        await _until(() => s.transcript.lastResult != null && s.transcript.lastResult!.text.contains('touch') == false && !s.transcript.turnOpen, const Duration(seconds: 120));
        expect(marker.existsSync(), isFalse, reason: 'the denial held');
        final id = s.sessionId!;
        await s.stop();
        await s.start(resume: true);
        expect(await s.awaitReady(timeout: const Duration(seconds: 60)), isTrue);
        expect(s.sessionId, id);
        s.send('In one line: what did I ask you to touch?');
        await _until(() => s.transcript.lastResult != null && !s.transcript.turnOpen, const Duration(seconds: 120));
        expect(s.transcript.messages.last.text, contains('kit-codex-live'));
      } finally {
        await s.stop();
        dir.deleteSync(recursive: true);
      }
    }, skip: live ? false : 'KIT_LIVE=1 runs the real codex — it spends the ChatGPT pool', timeout: const Timeout(Duration(minutes: 8)));
  });
}

Future<void> _until(bool Function() ok, Duration timeout) async {
  final end = DateTime.now().add(timeout);
  while (!ok() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  expect(ok(), isTrue, reason: 'timed out after $timeout');
}
