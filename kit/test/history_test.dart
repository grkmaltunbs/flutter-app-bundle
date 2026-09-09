// The CLI's transcript file read back into rows, and what a session's
// entry keeps. The fixture mirrors the shapes seen on 2.1.261.
import 'dart:io';

import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

void main() {
  final lines = File('test/fixtures/session_fixture.jsonl').readAsLinesSync();

  test('the rows come back in order: prompts, replies, tools with their results; meta and sidechain lines do not', () {
    final rows = restoreRows(lines);
    expect(rows.map((r) => r.role), [
      DeckRole.user,
      DeckRole.assistant,
      DeckRole.user,
      DeckRole.tool,
      DeckRole.tool,
      DeckRole.assistant,
      DeckRole.user,
      DeckRole.assistant,
    ]);
    expect(rows[0].text, 'remember falcon');
    expect(rows[0].at, DateTime.parse('2026-09-08T10:00:01.000Z'));
    expect(rows[1].text, 'Falcon, kept.');
    expect(rows[2].text, '/step greet', reason: 'a slash command is shown as it was typed');
    expect(rows[3].toolName, 'Bash');
    expect(rows[3].toolInput!['command'], 'bash kit/kit.sh next --step');
    expect(rows[3].toolResult, 'greet');
    expect(rows[3].doneAt, DateTime.parse('2026-09-08T10:01:03.000Z'));
    expect(rows[4].toolName, 'Read');
    expect(rows[4].toolResult, 'id: greet\ntitle: Greet', reason: 'a result given as blocks is joined');
    expect(rows[6].text, '(an image)\nwhat is wrong here?', reason: 'the attachments trailer is cut; the image is named');
    expect(rows.map((r) => r.text), isNot(contains(contains('subagent'))));
    expect(rows.map((r) => r.text), isNot(contains(contains('Do nothing else'))));
    expect(rows.map((r) => r.id).toList(), [for (var i = 0; i < 8; i++) 'h${i.toString().padLeft(5, '0')}']);
    expect('h00007'.compareTo('m00000') < 0, isTrue, reason: 'restored rows sort before live ones on the phone');
  });

  test('only the tail comes back when the file is long', () {
    final rows = restoreRows(lines, last: 3);
    expect(rows.map((r) => r.role), [DeckRole.assistant, DeckRole.user, DeckRole.assistant]);
    expect(rows.last.text, 'The button overflows at 3.12×.');
  });

  test('the summary: the first prompt, the turns the person sent, the model, the span', () {
    final s = summarizeTranscript(lines);
    expect(s.firstMessage, 'remember falcon');
    expect(s.turns, 3);
    expect(s.model, 'claude-fable-5-1');
    expect(s.firstAt, DateTime.parse('2026-09-08T10:00:00.000Z'));
    expect(s.lastAt, DateTime.parse('2026-09-08T10:02:05.000Z'));
    expect(summarizeTranscript(const ['', 'garbage']).turns, 0);
  });

  test('an entry round-trips through its map; the list line clips to the first line', () {
    final e = SessionEntry(id: 'abc', startedAt: DateTime.utc(2026, 9, 8, 10), firstMessage: 'remember falcon', turns: 2, model: 'claude-fable-5-1', mode: 'default');
    final back = SessionEntry.fromMap(e.toMap());
    expect(back.id, 'abc');
    expect(back.startedAt, e.startedAt);
    expect(back.endedAt, isNull);
    expect(back.firstMessage, 'remember falcon');
    expect(back.turns, 2);
    expect(back.model, 'claude-fable-5-1');
    expect(back.mode, 'default');
    expect(back.title, 'remember falcon');
    expect(SessionEntry(id: 'x', startedAt: e.startedAt).title, '(nothing said yet)');
    expect(clipLine('one line\nsecond', 20), 'one line');
    expect(clipLine('a' * 30, 10), '${'a' * 9}…');
  });
}
