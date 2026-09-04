// The bridge runner against a scripted claude, and — under KIT_LIVE=1 —
// against the real one. The live test spends subscription quota; it is the
// step's runtime gate, not a habit.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/attachments.dart';
import 'package:kit_app/src/host/bridge_session.dart';
import 'package:kit_app/src/host/permission_rules.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_claude.dart';

void main() {
  late Directory home;
  late Directory project;
  setUp(() {
    home = Directory.systemTemp.createTempSync('kit_bridge_home_');
    project = Directory.systemTemp.createTempSync('kit_bridge_project_');
  });
  tearDown(() {
    home.deleteSync(recursive: true);
    project.deleteSync(recursive: true);
  });

  test('a turn: start, send, stream, tool row, end — and the record for Resume', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path, readyGrace: const Duration(seconds: 5));
    final states = <BridgeState>[];
    s.addListener(() => states.add(s.state));

    await s.start();
    expect(s.state, BridgeState.starting);
    expect(fake.startedIn, project.path);
    expect(fake.startedWith, containsAllInOrder(['-p', '--permission-prompt-tool', 'stdio', '--session-id', s.sessionId]));
    expect(fake.startedWith[fake.startedWith.indexOf('--append-system-prompt') + 1], contains('no browser tools'), reason: 'the brief, for the default options');
    expect(s.cliVersion, '2.1.251');

    s.send('/plan-status');
    await fake.writtenLines(1);
    expect(jsonDecode(fake.written.single), {'type': 'user', 'message': {'role': 'user', 'content': '/plan-status'}});
    expect(s.state, BridgeState.busy);

    scriptTurn(fake, sessionId: s.sessionId!);
    await pumpEventQueue();
    expect(s.state, BridgeState.ready);
    final t = s.transcript;
    expect(t.messages.map((m) => m.role), [DeckRole.user, DeckRole.assistant, DeckRole.tool]);
    expect(t.messages[1].text, 'Step 31 is ready.');
    expect(t.messages[1].streaming, isFalse);
    expect(t.messages[2].toolResult, 'bridge-core');
    expect(t.deltasSeen, 2);
    expect(t.pool!.rateLimitType, 'five_hour');
    expect(states, contains(BridgeState.busy));

    final rec = s.previous()!;
    expect(rec.sessionId, s.sessionId);
    expect(rec.pid, 4242);
    expect(File(p.join(home.path, 'bridge', '${claudeProjectSlug(project.path)}.json')).existsSync(), isTrue);

    await s.stop();
    expect(s.state, BridgeState.stopped);
    expect(s.running, isFalse);
    expect(s.previous()!.sessionId, rec.sessionId, reason: 'the record outlives the process so Resume can find it');
  });

  test('files ride with a message: saved on the Mac, named by path, an image shown inline', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    await s.start();
    final png = base64Decode(onePixelPng);
    final shot = PendingAttachment(name: 'Screenshot 2026-09-02.png', mime: 'image/png', bytes: png);
    final pdf = PendingAttachment(name: 'spec.pdf', mime: 'application/pdf', bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 fake')));
    s.send('What is wrong on this screen?', files: [shot, pdf]);
    await fake.writtenLines(1);
    final content = (((jsonDecode(fake.written.single) as Map)['message'] as Map)['content']) as List;
    expect(content.length, 2, reason: 'the image block, then the text; the pdf rides by path');
    expect(content[0]['type'], 'image');
    expect(content[0]['source'], {'type': 'base64', 'media_type': 'image/png', 'data': onePixelPng});
    final text = content[1]['text'] as String;
    expect(text, startsWith('What is wrong on this screen?'));
    expect(text, contains('Read tool'));
    final row = s.transcript.messages.single;
    expect(row.attachments.map((a) => a.name), ['Screenshot 2026-09-02.png', 'spec.pdf']);
    for (final a in row.attachments) {
      expect(a.path, startsWith(p.join(home.path, 'attachments', claudeProjectSlug(project.path))), reason: 'outside the project, never in git');
      expect(File(a.path!).existsSync(), isTrue);
      expect(text, contains(a.path!));
    }
    expect(File(row.attachments[0].path!).readAsBytesSync(), png);
    expect(row.attachments[0].path, endsWith('-Screenshot_2026-09-02.png'), reason: 'spaces do not travel into a path');
    expect('(shown above)'.allMatches(text).length, 1, reason: 'only the image is inline');
    expect(s.state, BridgeState.busy);

    // No words at all: the file is the message.
    s.send('', files: [shot]);
    await fake.writtenLines(2);
    final again = (((jsonDecode(fake.written.last) as Map)['message'] as Map)['content']) as List;
    expect(again[1]['text'], startsWith('See the attached file.'));
    expect(s.transcript.messages.last.text, isEmpty);
    expect(s.transcript.messages.last.attachments.single.path, isNot(row.attachments[0].path), reason: 'a second copy gets its own name');

    // Nothing at all is nothing.
    s.send('   ');
    await pumpEventQueue();
    expect(fake.written.length, 2);
  });

  test('session options live in the record and shape the command line; fixed while running', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    expect(s.skipPermissions, isFalse);
    expect(s.chrome, isFalse);
    expect(s.previous(), isNull, reason: 'nothing recorded yet');

    expect(s.setOptions(skipPermissions: true, chrome: true, model: 'opus', effort: 'high'), isTrue);
    expect(s.previous()!.sessionId, isNull, reason: 'options alone make a record; nothing to resume yet');
    expect(s.previous()!.skipPermissions, isTrue);
    expect(s.previous()!.model, 'opus');
    expect(s.previous()!.effort, 'high');
    expect(s.toRelay()['modelChoice'], 'opus');
    expect(s.toRelay()['effort'], 'high');
    expect(s.toRelay()['canResume'], isFalse);
    expect(s.toRelay()['skipPermissions'], isTrue);
    expect(s.toRelay()['chrome'], isTrue);

    // A fresh session on the same folder reads them back.
    final again = fakeSession(FakeClaude(), dir: project.path, home: home.path);
    expect(again.skipPermissions, isTrue);
    expect(again.chrome, isTrue);
    expect(again.modelChoice, 'opus');
    expect(again.effort, 'high');

    await s.start();
    expect(fake.startedWith, containsAllInOrder(['--permission-mode', 'bypassPermissions', '--chrome', '--session-id', s.sessionId, '--model', 'opus', '--effort', 'high']));
    final brief = fake.startedWith[fake.startedWith.indexOf('--append-system-prompt') + 1];
    expect(brief, contains('Claude in Chrome tools'));
    expect(brief, contains('runs without asking'));
    expect(brief, s.brief);
    expect(s.setOptions(), isFalse, reason: 'nothing given, nothing changed');
    expect(s.chrome, isTrue);
    fake.emitJson({'type': 'system', 'subtype': 'init', 'session_id': s.sessionId, 'model': 'm', 'permissionMode': 'bypassPermissions', 'mcp_servers': [{'name': 'claude-in-chrome', 'status': 'connected'}]});
    await pumpEventQueue();
    expect(s.chromeStatus, 'connected');
    expect(s.toRelay()['chromeStatus'], 'connected');
    expect(s.transcript.permissionMode, 'bypassPermissions');

    await s.stop();
    final rec = s.previous()!;
    expect(rec.sessionId, s.sessionId, reason: 'the session is recorded beside the options');
    expect(rec.chrome, isTrue);
    expect(s.setOptions(skipPermissions: false, model: 'default', effort: 'default'), isTrue);
    expect(s.previous()!.sessionId, s.sessionId, reason: 'changing an option keeps the session to resume');
    expect(s.modelChoice, isNull, reason: 'default hands the choice back to the CLI');
    expect(s.previous()!.model, isNull);
    expect(s.toRelay()['effort'], 'default');
    expect(s.previous()!.skipPermissions, isFalse);
  });

  test('a change while live restarts the process on the same conversation; mid-turn it waits for the turn to end', () async {
    final spawned = <FakeClaude>[];
    final s = fakeSessionEach(spawned, dir: project.path, home: home.path);
    await s.start();
    final id = s.sessionId!;
    spawned.single.emitJson({'type': 'system', 'subtype': 'init', 'session_id': id, 'model': 'm', 'permissionMode': 'default'});
    await pumpEventQueue();
    expect(s.state, BridgeState.ready);

    // Between turns: at once.
    expect(s.setOptions(model: 'opus'), isTrue);
    await pumpEventQueue(times: 200);
    expect(spawned.length, 2, reason: 'stopped and started again');
    expect(spawned[1].startedWith, containsAllInOrder(['--resume', id, '--model', 'opus']));
    expect(s.sessionId, id, reason: 'the same conversation');
    expect(s.running, isTrue);
    expect(s.restartPending, isFalse);
    spawned[1].emitJson({'type': 'system', 'subtype': 'init', 'session_id': id, 'model': 'claude-opus-5', 'permissionMode': 'default'});
    await pumpEventQueue();
    expect(s.transcript.model, 'claude-opus-5');

    // Mid-turn: the change waits for the end of the turn.
    s.send('do a thing');
    expect(s.state, BridgeState.busy);
    expect(s.setOptions(effort: 'high', chrome: true), isTrue);
    expect(s.restartPending, isTrue);
    expect(s.toRelay()['restartPending'], isTrue);
    await pumpEventQueue(times: 50);
    expect(spawned.length, 2, reason: 'nothing in flight is cut');
    spawned[1].emitJson({'type': 'result', 'subtype': 'success', 'is_error': false, 'duration_ms': 10, 'num_turns': 1, 'result': 'done', 'session_id': id});
    await pumpEventQueue(times: 200);
    expect(spawned.length, 3);
    expect(spawned[2].startedWith, containsAllInOrder(['--chrome', '--resume', id, '--model', 'opus', '--effort', 'high']));
    expect(s.restartPending, isFalse);
    expect(s.transcript.messages.map((m) => m.text), contains('do a thing'), reason: 'the transcript carries on');
    expect(s.previous()!.effort, 'high');
  });

  test('a scoped send wraps the prompt; the deck shows what was typed; the reply inherits the scope', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    s.describeAbout = (about) => '# Presence\n\n- id: presence\n- needs: decision';
    await s.start();

    s.send('What does friends-only cost?', about: {'item': 'presence'});
    await fake.writtenLines(1);
    final content = ((jsonDecode(fake.written.single) as Map)['message'] as Map)['content'].toString();
    expect(content, contains('The user asks about one item of the plan — `presence`'));
    expect(content, contains('What does friends-only cost?'));
    expect(content, contains('kit show presence'));
    expect(content, contains('- needs: decision'));
    expect(content, contains('phone screen'));
    expect(content, contains('say in one line what you changed'));
    expect(s.transcript.messages.last.text, 'What does friends-only cost?', reason: 'the deck shows the question, not the wrapper');
    expect(threadKey(s.transcript.messages.last.about), 'item:presence');

    scriptTurn(fake, sessionId: s.sessionId!, text: 'About 50 reads per open.');
    await pumpEventQueue();
    final reply = s.transcript.messages.firstWhere((m) => m.role == DeckRole.assistant);
    expect(threadKey(reply.about), 'item:presence', reason: 'the whole turn belongs to the thread');

    // Unscoped stays unwrapped.
    s.send('and generally?');
    await fake.writtenLines(2);
    expect(((jsonDecode(fake.written.last) as Map)['message'] as Map)['content'], 'and generally?');
  });

  test('a permission waits on the user; a denial goes back as the control response', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    await s.start();
    s.send('touch a file');
    fake.emitJson({'type': 'system', 'subtype': 'init', 'session_id': s.sessionId, 'model': 'claude-fable-5'});
    scriptBashAsk(fake);
    await pumpEventQueue();
    expect(s.state, BridgeState.waiting);
    expect(s.transcript.pending!.summary, 'touch /tmp/kit-ask');

    s.answer(AskAnswer.deny('The user declined from the Mac.'));
    await fake.writtenLines(2);
    final m = jsonDecode(fake.written[1]) as Map;
    expect(m['type'], 'control_response');
    expect(m['response']['request_id'], 'req_bash');
    expect(m['response']['response']['behavior'], 'deny');
    expect(s.transcript.pending, isNull);
    expect(s.state, BridgeState.busy);
    expect(s.transcript.messages.last.text, startsWith('Denied: touch'));

    // Answering again is a no-op, never a second line.
    s.answer(AskAnswer.deny('again'));
    await pumpEventQueue();
    expect(fake.written.length, 2);
  });

  test('the process ends with an ask open: it is withdrawn, so no phone keeps offering it', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    final gone = <String>[];
    s.onWithdrawn = (a) => gone.add(a.requestId);
    await s.start();
    s.send('touch a file');
    fake.emitJson({'type': 'system', 'subtype': 'init', 'session_id': s.sessionId, 'model': 'claude-fable-5'});
    scriptBashAsk(fake);
    await pumpEventQueue();
    expect(s.state, BridgeState.waiting);
    await s.stop();
    expect(gone, ['req_bash']);
    expect(s.transcript.pending, isNull);
    expect(s.transcript.messages.last.text, startsWith('Withdrawn — the session stopped: touch'));
    expect(s.toRelay()['pendingAsks'], 0);
  });

  test('a question is answered by label and the whole input travels back', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    await s.start();
    s.send('decide');
    scriptQuestionAsk(fake);
    await pumpEventQueue();
    final ask = s.transcript.pending!;
    expect(ask.isQuestion, isTrue);
    s.answer(AskAnswer.answers(ask, {ask.questions.single.question: 'Public, documented'}));
    await fake.writtenLines(2);
    final m = jsonDecode(fake.written[1]) as Map;
    final resp = m['response']['response'] as Map;
    expect(resp['behavior'], 'allow');
    expect(resp['updatedInput']['answers'], {'Friends-only presence, or public and documented?': 'Public, documented'});
    expect(resp['updatedInput']['questions'], isNotEmpty);
  });

  test('resume reuses the recorded session id with --resume and keeps the conversation; a fresh start clears it', () async {
    final spawned = <FakeClaude>[];
    final s1 = fakeSessionEach(spawned, dir: project.path, home: home.path);
    await s1.start();
    final id = s1.sessionId!;
    s1.send('remember falcon');
    expect(s1.toRelay()['canResume'], isFalse, reason: 'not while running');
    await s1.stop();
    expect(s1.toRelay()['canResume'], isTrue);
    expect(s1.transcript.messages, isNotEmpty);
    await s1.start(resume: true);
    expect(spawned.last.startedWith, containsAllInOrder(['--resume', id]));
    expect(s1.transcript.messages.single.text, 'remember falcon', reason: 'resume keeps the rows');
    await s1.stop();
    await s1.start();
    expect(spawned.last.startedWith, contains('--session-id'));
    expect(s1.transcript.messages, isEmpty, reason: 'a fresh session is a fresh conversation');
    await s1.stop();
    expect(spawned.length, 3);

    final second = FakeClaude();
    final s2 = fakeSession(second, dir: project.path, home: home.path);
    expect(s2.previous(), isNotNull);
    await s2.start(resume: true);
    expect(second.startedWith, contains('--resume'));
    expect(second.startedWith, isNot(contains('--session-id')));
    expect(s2.sessionId, isNot(id), reason: 'the record now names the fresh session that replaced it');

    final fresh = fakeSession(FakeClaude(), dir: Directory.systemTemp.createTempSync('kit_other_').path, home: home.path);
    await fresh.start(resume: true);
    expect(fresh.state, BridgeState.failed);
    expect(fresh.error, contains('Nothing to resume'));
  });

  test('this session: the same request is allowed by the host without asking; a different one, or a stale answer, is not', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    final asked = <String>[];
    final answered = <String>[];
    s.onAsk = (a) => asked.add(a.requestId);
    s.onAnswered = (a, ans, by) => answered.add('${a.requestId}:$by:${ans.summary}');
    await s.start();
    s.send('touch a file');
    fake.emitJson({'type': 'system', 'subtype': 'init', 'session_id': s.sessionId, 'model': 'claude-fable-5'});
    scriptBashAsk(fake, requestId: 'r1');
    await pumpEventQueue();
    expect(s.state, BridgeState.waiting);
    expect(asked, ['r1']);

    s.answer(AskAnswer.allow(s.transcript.pending!), remember: true);
    await fake.writtenLines(2);
    expect((jsonDecode(fake.written[1]) as Map)['response']['response']['behavior'], 'allow');
    expect(answered, ['r1:Mac:Allowed']);
    expect(s.transcript.messages.last.text, 'Allowed (this session): touch /tmp/kit-ask');

    // The same command again: answered by the host, never shown.
    scriptBashAsk(fake, requestId: 'r2');
    await pumpEventQueue();
    await fake.writtenLines(3);
    expect(s.state, BridgeState.busy);
    expect(asked, ['r1'], reason: 'a remembered request does not reach the phone');
    expect((jsonDecode(fake.written[2]) as Map)['response']['request_id'], 'r2');
    expect(answered.last, 'r2:host:Allowed');
    expect(s.transcript.messages.last.text, startsWith('Allowed (this session)'));

    // A different command still asks.
    scriptBashAsk(fake, requestId: 'r3', command: 'touch /tmp/other');
    await pumpEventQueue();
    expect(s.state, BridgeState.waiting);
    expect(asked, ['r1', 'r3']);

    // A stale answer — the phone answering r2 after the host did — is dropped.
    s.answer(AskAnswer.deny('late'), requestId: 'r2', by: 'phone');
    await pumpEventQueue();
    expect(fake.written.length, 3);
    expect(s.state, BridgeState.waiting);
    s.answer(AskAnswer.deny('no'), requestId: 'r3', by: 'phone');
    await fake.writtenLines(4);
    expect(answered.last, 'r3:phone:Denied');

    // Memory ends with the process.
    await s.stop();
    final fake2 = FakeClaude();
    final s2 = fakeSession(fake2, dir: project.path, home: home.path);
    await s2.start(resume: true);
    s2.send('again');
    scriptBashAsk(fake2, requestId: 'r4');
    await pumpEventQueue();
    expect(s2.state, BridgeState.waiting);
  });

  test('always: the suggestions go back as updatedPermissions, are recorded for the Session tab, and can be taken back', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    await s.start();
    s.send('touch a file');
    scriptBashAsk(fake, requestId: 'r1');
    await pumpEventQueue();
    final ask = s.transcript.pending!;
    s.answer(AskAnswer.always(ask));
    await fake.writtenLines(2);
    final resp = (jsonDecode(fake.written[1]) as Map)['response']['response'] as Map;
    expect(resp['behavior'], 'allow');
    expect(resp['updatedPermissions'], ask.suggestions);
    expect(s.transcript.messages.last.text, startsWith('Allowed, always: touch'));
    final rule = s.alwaysApplied.single;
    expect(rule.ruleString, 'Bash(touch:*)');
    expect(rule.destination, 'localSettings');
    expect(s.previous()!.always.single.rule, 'touch:*');

    // Remembered for the rest of this session too.
    scriptBashAsk(fake, requestId: 'r2');
    await pumpEventQueue();
    expect(s.state, BridgeState.busy);

    // A new session in the same folder lists what was applied.
    final later = fakeSession(FakeClaude(), dir: project.path, home: home.path);
    expect(later.alwaysApplied, [rule]);

    // Taking it back edits the file the CLI wrote and forgets the rule.
    final settings = File(p.join(project.path, '.claude', 'settings.local.json'))..createSync(recursive: true);
    settings.writeAsStringSync(jsonEncode({'permissions': {'allow': ['Bash(touch:*)', 'Read'], 'deny': ['Bash(rm -rf:*)']}, 'other': true}));
    expect(PermissionRules.contains(project.path, rule), isTrue);
    expect(s.forgetAlways(rule), isTrue);
    expect(PermissionRules.contains(project.path, rule), isFalse);
    final written = jsonDecode(settings.readAsStringSync()) as Map;
    expect(written['permissions']['allow'], ['Read']);
    expect(written['permissions']['deny'], ['Bash(rm -rf:*)'], reason: 'nothing else moves');
    expect(written['other'], isTrue);
    expect(s.alwaysApplied, isEmpty);
    expect(s.previous()!.always, isEmpty);
    expect(s.forgetAlways(rule), isFalse, reason: 'already gone');
  });

  test('awaitReady: true once the init came, false when the process ended first — a resume of a session never written down', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path, readyGrace: const Duration(seconds: 5));
    await s.start();
    final ready = s.awaitReady();
    await pumpEventQueue();
    fake.emitJson({'type': 'system', 'subtype': 'init', 'session_id': s.sessionId, 'model': 'claude-fable-5', 'permissionMode': 'default'});
    expect(await ready, isTrue);
    expect(s.state, BridgeState.ready);
    await s.stop();

    final dead = FakeClaude();
    final d = fakeSession(dead, dir: project.path, home: home.path, readyGrace: const Duration(seconds: 5));
    await d.start(resume: true);
    final came = d.awaitReady();
    await pumpEventQueue();
    dead.emitErr('No conversation found with session ID: ${d.sessionId}');
    dead.exit(1);
    expect(await came, isFalse);
    expect(d.state, BridgeState.failed);
    expect(d.error, contains('No conversation found'));
    expect(await d.awaitReady(timeout: const Duration(milliseconds: 50)), isFalse, reason: 'not starting, not running');
  });

  test('Resume of a session the CLI never wrote down starts fresh, and says so in the log', () async {
    final first = FakeClaude();
    final s = fakeSession(first, dir: project.path, home: home.path);
    await s.start();
    final id = s.sessionId!;
    await s.stop();
    final second = FakeClaude();
    final again = BridgeSession(dir: project.path, starter: second.starter, findBinary: () async => '/fake/claude', versionOf: (_) async => '2.1.251', shellPath: () async => '/fake/bin', home: home.path, transcriptExists: (_) => false);
    await again.start(resume: true);
    expect(second.startedWith, isNot(contains('--resume')), reason: 'nothing to resume');
    expect(again.sessionId, isNot(id));
    expect(again.log.join('\n'), contains('never spoke'));
    await again.stop();
  });

  test('a process alive past the grace is ready before its init — the CLI only speaks with the first message', () async {
    final fake = FakeClaude();
    final s = BridgeSession(dir: project.path, starter: fake.starter, findBinary: () async => '/fake/claude', versionOf: (_) async => '2.1.251', shellPath: () async => '/fake/bin', home: home.path, transcriptExists: (_) => true, readyGrace: const Duration(milliseconds: 40));
    await s.start();
    expect(s.state, BridgeState.starting);
    expect(await s.awaitReady(), isTrue);
    expect(s.state, BridgeState.ready);
    // The init that comes with the first turn keeps it live, not starting.
    s.send('hello');
    await pumpEventQueue();
    fake.emitJson({'type': 'system', 'subtype': 'init', 'session_id': s.sessionId, 'model': 'claude-fable-5', 'permissionMode': 'default'});
    await pumpEventQueue();
    expect(s.state, isNot(BridgeState.starting));
    await s.stop();

    final dead = FakeClaude();
    final d = BridgeSession(dir: project.path, starter: dead.starter, findBinary: () async => '/fake/claude', versionOf: (_) async => '2.1.251', shellPath: () async => '/fake/bin', home: home.path, transcriptExists: (_) => true, readyGrace: const Duration(milliseconds: 40));
    await d.start();
    dead.exit(1);
    await pumpEventQueue();
    expect(await d.awaitReady(), isFalse, reason: 'it died inside the grace');
    expect(d.state, BridgeState.failed);
  });

  test('a crash is a failure with the last stderr line; stdout that is not protocol goes to the log', () async {
    final fake = FakeClaude();
    final s = fakeSession(fake, dir: project.path, home: home.path);
    await s.start();
    fake.emit('Warning: something about the terminal');
    fake.emitErr('Error: Not logged in');
    await pumpEventQueue();
    expect(s.log, ['Warning: something about the terminal', 'Error: Not logged in']);
    fake.exit(1);
    await pumpEventQueue();
    expect(s.state, BridgeState.failed);
    expect(s.error, contains('exited with code 1'));
    expect(s.error, contains('Not logged in'));
  });

  group('live', () {
    final live = Platform.environment['KIT_LIVE'] == '1';

    test('the real claude streams, asks, honours a denial and resumes', () async {
      final dir = Directory.systemTemp.createTempSync('kit_live_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final s = BridgeSession(dir: dir.path, home: home.path);

      Future<void> until(bool Function() done, {Duration timeout = const Duration(seconds: 120)}) async {
        final end = DateTime.now().add(timeout);
        while (!done()) {
          if (DateTime.now().isAfter(end)) fail('timed out; state ${s.state}, error ${s.error}, log ${s.log.join(' | ')}');
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      await s.start();
      expect(s.state, isNot(BridgeState.failed), reason: s.error);
      expect(s.cliVersion, isNotNull);

      // 1. A streamed reply.
      s.send('Reply with exactly the two words: bridge ready. Nothing else.');
      await until(() => s.state == BridgeState.ready && s.transcript.lastResult != null);
      final reply = s.transcript.messages.where((m) => m.role == DeckRole.assistant).last.text.toLowerCase();
      expect(reply, contains('bridge ready'));
      expect(s.transcript.deltasSeen, greaterThan(0), reason: 'partial messages must stream');
      expect(s.transcript.pool, isNotNull, reason: 'the subscription pool is reported');

      // 2. A question, answered by label.
      s.send('Use the AskUserQuestion tool to ask me one question: tea or coffee? Then say one sentence naming what I chose. Do nothing else.');
      await until(() => s.state == BridgeState.waiting);
      final ask = s.transcript.pending!;
      expect(ask.isQuestion, isTrue);
      final coffee = ask.questions.single.options.firstWhere((o) => o.label.toLowerCase().contains('coffee')).label;
      s.answer(AskAnswer.answers(ask, {ask.questions.single.question: coffee}));
      await until(() => s.state == BridgeState.ready);
      expect(s.transcript.messages.where((m) => m.role == DeckRole.assistant).last.text.toLowerCase(), contains('coffee'));

      // 3. A permission, denied — and the denial holds.
      final marker = p.join(dir.path, 'kit-live-denied.txt');
      s.send('Run the shell command `touch $marker` with Bash, then say done. Do nothing else.');
      await until(() => s.state == BridgeState.waiting);
      expect(s.transcript.pending!.toolName, 'Bash');
      s.answer(AskAnswer.deny('The user declined from the Mac.'));
      await until(() => s.state == BridgeState.ready);
      expect(File(marker).existsSync(), isFalse, reason: 'a denied command must not run');

      // 3b. Always: the CLI writes the rule itself, and the same shape of
      // command no longer asks — on either side.
      final marker2 = p.join(dir.path, 'kit-live-always.txt');
      s.send('Run the shell command `touch $marker2` with Bash, then say done. Do nothing else.');
      await until(() => s.state == BridgeState.waiting);
      final ask2 = s.transcript.pending!;
      expect(ask2.suggestions, isNotEmpty, reason: 'the CLI offers a rule to remember');
      s.answer(AskAnswer.always(ask2));
      await until(() => s.state == BridgeState.ready);
      expect(File(marker2).existsSync(), isTrue);
      final settings = File(p.join(dir.path, '.claude', 'settings.local.json'));
      expect(settings.existsSync(), isTrue, reason: 'updatedPermissions made the CLI write the rule where it said it would');
      expect(settings.readAsStringSync(), contains('touch'));
      expect(s.alwaysApplied.single.ruleString, contains('Bash('));
      final marker3 = p.join(dir.path, 'kit-live-always-2.txt');
      var askedAgain = false;
      s.addListener(() => askedAgain |= s.state == BridgeState.waiting);
      final before = s.transcript.lastResult;
      s.send('Run the shell command `touch $marker3` with Bash, then say done. Do nothing else.');
      await until(() => s.state == BridgeState.ready && !identical(s.transcript.lastResult, before));
      expect(askedAgain, isFalse, reason: 'the rule holds for the rest of the session');
      expect(File(marker3).existsSync(), isTrue);

      final id = s.sessionId!;
      await s.stop();
      expect(s.state, BridgeState.stopped);

      // 4. Resume remembers.
      final r = BridgeSession(dir: dir.path, home: home.path);
      expect(r.previous()!.sessionId, id);
      await r.start(resume: true);
      r.send('In one word: what drink did I choose earlier in this conversation?');
      await until(() => r.state == BridgeState.ready && r.transcript.lastResult != null);
      expect(r.transcript.messages.where((m) => m.role == DeckRole.assistant).last.text.toLowerCase(), contains('coffee'));
      await r.stop();
    }, skip: live ? false : 'set KIT_LIVE=1 to run against the real claude (spends subscription quota)', timeout: const Timeout(Duration(minutes: 8)));
  });
}
