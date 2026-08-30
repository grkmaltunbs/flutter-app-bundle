// The bridge runner against a scripted claude, and — under KIT_LIVE=1 —
// against the real one. The live test spends subscription quota; it is the
// step's runtime gate, not a habit.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/bridge_session.dart';
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
    final s = fakeSession(fake, dir: project.path, home: home.path);
    final states = <BridgeState>[];
    s.addListener(() => states.add(s.state));

    await s.start();
    expect(s.state, BridgeState.starting);
    expect(fake.startedIn, project.path);
    expect(fake.startedWith, containsAllInOrder(['-p', '--permission-prompt-tool', 'stdio', '--session-id', s.sessionId]));
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

  test('resume reuses the recorded session id with --resume', () async {
    final first = FakeClaude();
    final s1 = fakeSession(first, dir: project.path, home: home.path);
    await s1.start();
    final id = s1.sessionId!;
    await s1.stop();

    final second = FakeClaude();
    final s2 = fakeSession(second, dir: project.path, home: home.path);
    expect(s2.previous()!.sessionId, id);
    await s2.start(resume: true);
    expect(second.startedWith, containsAllInOrder(['--resume', id]));
    expect(second.startedWith, isNot(contains('--session-id')));
    expect(s2.sessionId, id);

    final fresh = fakeSession(FakeClaude(), dir: Directory.systemTemp.createTempSync('kit_other_').path, home: home.path);
    await fresh.start(resume: true);
    expect(fresh.state, BridgeState.failed);
    expect(fresh.error, contains('Nothing to resume'));
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
