// Rich pushes, the pure half: the lines an ask's push carries, the quiet
// window a phone keeps, what waits through it and the digest at its end.
import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

void main() {
  test('an edit ask carries its first changed lines; a plan its heading and step count; a problem its error line as it was', () {
    const diff = '--- a/lib/main.dart\n+++ b/lib/main.dart\n@@ -1,4 +1,4 @@\n import x;\n-  title: \'Home\',\n+  title: \'Settings\',\n+\n+  subtitle: \'new\',\n-  gone: true,\n';
    expect(diffPreview(diff), ['- title: \'Home\',', '+ title: \'Settings\',', '+ subtitle: \'new\','], reason: 'three changed lines, headers and context skipped, a blank change skipped');
    expect(diffPreview(diff, lines: 5).length, 4);
    expect(diffPreview('+${'x' * 200}', width: 20).single.length, 20);
    expect(diffPreview('no changes here'), isEmpty);

    final edit = Ask.fromMap({'requestId': 'r1', 'toolName': 'Edit', 'toolUseId': 't1', 'at': '2026-09-10T10:00:00Z', 'input': {'file_path': '/p/lib/main.dart', 'old_string': 'Home', 'new_string': 'Settings'}, 'diff': diff});
    final n = noticeForAsk(edit, project: 'Kit');
    expect(n.title, 'Allow Edit? · Kit');
    expect(n.body.split('\n').first, edit.summary);
    expect(n.body, contains('- title: \'Home\','));
    expect(n.body, contains('+ title: \'Settings\','));
    expect(n.body.length, lessThanOrEqualTo(240));
    final plain = Ask.fromMap({'requestId': 'r2', 'toolName': 'Edit', 'toolUseId': 't2', 'at': '2026-09-10T10:00:00Z', 'input': {'file_path': '/p/lib/main.dart', 'old_string': 'a', 'new_string': 'b'}});
    expect(noticeForAsk(plain, project: 'Kit').body, plain.summary, reason: 'no diff, the summary alone');

    expect(planOutline('# Settings screen\n\nWhat we do:\n\n1. Add the route.\n2. The screen.\n3. Tests.\n'), (heading: 'Settings screen', steps: 3));
    expect(planOutline('# Plan\n\n## Route\nwords\n## Screen\n## Tests\n'), (heading: 'Plan', steps: 3), reason: 'headings under the first when nothing is numbered or bulleted');
    expect(planOutline('# Plan\n\n## Steps\n- a\n- b\n'), (heading: 'Plan', steps: 2), reason: 'bullets before headings');
    expect(planOutline('Just a line\n- one\n- two\n'), (heading: 'Just a line', steps: 2));
    expect(planOutline(''), (heading: '', steps: 0));
    expect(planPreview('# Settings screen\n1. a\n'), 'Settings screen · 1 step');
    expect(planPreview('# Only a title'), 'Only a title');
    final plan = Ask.fromMap({'requestId': 'r3', 'toolName': 'ExitPlanMode', 'toolUseId': 't3', 'at': '2026-09-10T10:00:00Z', 'input': {'plan': '# Settings screen\n\n1. Add the route.\n2. The screen.\n3. Tests.\n'}});
    expect(noticeForAsk(plan, project: 'Kit').body, 'Settings screen · 3 steps');
    expect(noticeForAsk(plan, project: 'Kit').title, 'Plan ready · Kit');

    expect(errorLine('\n\nclaude exited with code 1 — boom\n  at x\n'), 'claude exited with code 1 — boom');
    expect(errorLine('x' * 600).length, 480);
    expect(errorLine('   '), '');
  });

  test('a done notice carries its frame and the turn a tap opens; the data map says so', () {
    final n = noticeForDone(const ResultEvent(subtype: 'success', sessionId: 's1', text: 'Changed the title.'), project: 'Kit', image: 'projects/kit/shots/1.jpg', sessionId: 's1', rowId: 'm42');
    expect(n.image, 'projects/kit/shots/1.jpg');
    expect(n.data('kit'), {'slug': 'kit', 'kind': 'done', 'image': 'projects/kit/shots/1.jpg', 'sessionId': 's1', 'rowId': 'm42'});
    expect(noticeForDone(const ResultEvent(subtype: 'success', sessionId: 's1'), project: 'Kit').data('kit'), {'slug': 'kit', 'kind': 'done'}, reason: 'nothing extra when nothing is known');
    final plain = const Notice(kind: NoticeKind.done, title: 't', body: 'b');
    expect(plain.copyWith(image: 'p', urgent: true).data('kit'), {'slug': 'kit', 'kind': 'done', 'image': 'p', 'urgent': '1'});
    expect(plain.copyWith(extra: {'rowId': 'r'}).extra, {'rowId': 'r'});
  });

  test('the quiet window: from the row, across midnight, its end, off, whole day', () {
    final w = QuietWindow.fromMap({'on': true, 'start': '23:00', 'end': '08:00', 'offset': 180})!;
    expect(w.label, '23:00–08:00');
    expect(w.toMap(), {'on': true, 'start': '23:00', 'end': '08:00', 'offset': 180});
    // 20:30Z is 23:30 in a +03:00 phone: inside.
    expect(w.contains(DateTime.utc(2026, 9, 10, 20, 30)), isTrue);
    expect(w.contains(DateTime.utc(2026, 9, 11, 4, 59)), isTrue, reason: '07:59 phone time');
    expect(w.contains(DateTime.utc(2026, 9, 11, 5, 0)), isFalse, reason: '08:00 is the end');
    expect(w.contains(DateTime.utc(2026, 9, 10, 12, 0)), isFalse, reason: 'afternoon');
    expect(w.contains(DateTime.utc(2026, 9, 10, 19, 59)), isFalse, reason: '22:59 phone time');
    expect(w.endAfter(DateTime.utc(2026, 9, 10, 20, 30)), DateTime.utc(2026, 9, 11, 5, 0), reason: '08:00 phone time, the next morning');
    expect(w.endAfter(DateTime.utc(2026, 9, 11, 4, 59)), DateTime.utc(2026, 9, 11, 5, 0));
    expect(w.endAfter(DateTime.utc(2026, 9, 10, 12, 0)), DateTime.utc(2026, 9, 10, 12, 0), reason: 'outside: nothing to wait for');
    expect(w.copyWith(on: false).contains(DateTime.utc(2026, 9, 10, 20, 30)), isFalse, reason: 'off');
    expect(w.copyWith(on: false).endAfter(DateTime.utc(2026, 9, 10, 20, 30)), DateTime.utc(2026, 9, 10, 20, 30));

    final day = QuietWindow.fromMap({'on': true, 'start': '13:00', 'end': '14:00', 'offset': -300})!;
    expect(day.contains(DateTime.utc(2026, 9, 10, 18, 30)), isTrue, reason: '13:30 in a -05:00 phone');
    expect(day.contains(DateTime.utc(2026, 9, 10, 19, 0)), isFalse);
    expect(day.endAfter(DateTime.utc(2026, 9, 10, 18, 30)), DateTime.utc(2026, 9, 10, 19, 0));
    final whole = QuietWindow.fromMap({'on': true, 'start': '09:00', 'end': '09:00', 'offset': 0})!;
    expect(whole.contains(DateTime.utc(2026, 9, 10, 3, 0)), isTrue, reason: 'start and end agree: a whole day');

    expect(QuietWindow.fromMap(null), isNull);
    expect(QuietWindow.fromMap({'on': true}), isNull, reason: 'no times, no window');
    expect(QuietWindow.fromMap({'on': true, 'start': '25:00', 'end': '08:00'}), isNull);
    expect(QuietWindow.fromMap({'start': '23:00', 'end': '08:00'})!.on, isFalse, reason: 'off unless said');
    expect(QuietWindow.parseHm('7:05'), 7 * 60 + 5);
    expect(QuietWindow.parseHm('x'), isNull);
    expect(QuietWindow.hm(8 * 60), '08:00');
    expect(QuietWindow.defaultStart, 23 * 60);
    expect(QuietWindow.defaultEnd, 8 * 60);
  });

  test('what waits through quiet hours, and the digest at the end', () {
    Notice mk(NoticeKind k, String body, {bool urgent = false}) => Notice(kind: k, title: 't', body: body, urgent: urgent);
    expect(heldInQuiet(mk(NoticeKind.done, 'x')), isTrue);
    expect(heldInQuiet(mk(NoticeKind.note, 'x')), isTrue);
    expect(heldInQuiet(mk(NoticeKind.problem, 'x')), isTrue);
    expect(heldInQuiet(mk(NoticeKind.problem, 'x', urgent: true)), isFalse, reason: 'a dead session pushes at once');
    expect(heldInQuiet(mk(NoticeKind.permission, 'x')), isFalse, reason: 'asks always push');
    expect(heldInQuiet(mk(NoticeKind.question, 'x')), isFalse);
    expect(heldInQuiet(mk(NoticeKind.plan, 'x')), isFalse);
    expect(heldInQuiet(mk(NoticeKind.step, 'x')), isFalse);
    expect(heldInQuiet(mk(NoticeKind.build, 'x')), isFalse);

    final d = digestNotice(project: 'Kit', held: [mk(NoticeKind.done, 'Added the route.'), mk(NoticeKind.done, 'Wrote the screen.\nSecond line'), mk(NoticeKind.problem, 'boom'), mk(NoticeKind.done, 'Tests pass.')]);
    expect(d.title, 'While you slept · Kit');
    expect(d.body, '3 turns ended · 1 problem\nTests pass.');
    expect(d.kind, NoticeKind.problem, reason: 'a problem among them: the problems channel');
    expect(d.extra['digest'], '4');
    final quiet = digestNotice(project: 'Kit', held: [mk(NoticeKind.done, 'One.')]);
    expect(quiet.body, '1 turn ended\nOne.');
    expect(quiet.kind, NoticeKind.done);
    expect(quiet.channel, 'done');
  });
}
