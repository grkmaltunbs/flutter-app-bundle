import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

void main() {
  test('a unified diff: hunks with context, headers, and nothing for the same text', () {
    final a = List.generate(20, (i) => 'line $i').join('\n');
    final b = a.replaceFirst('line 10', 'line ten');
    final d = unifiedDiff(a, b, path: 'lib/x.dart');
    expect(d.split('\n').take(2), ['--- a/lib/x.dart', '+++ b/lib/x.dart']);
    expect(d, contains('@@ -8,7 +8,7 @@'));
    expect(d, contains('\n-line 10\n+line ten\n'));
    expect(d, contains(' line 7\n line 8\n line 9\n-line 10'));
    expect(d, contains('+line ten\n line 11\n line 12\n line 13'));
    expect(d, isNot(contains('line 14')), reason: 'three lines of context, no more');
    expect(unifiedDiff(a, a), isEmpty);
    // Two changes close together share a hunk; far apart, two hunks.
    final near = a.replaceFirst('line 2', 'two').replaceFirst('line 5', 'five');
    int hunks(String d) => d.split('\n').where((l) => l.startsWith('@@')).length;
    expect(hunks(unifiedDiff(a, near)), 1);
    final far = a.replaceFirst('line 2', 'two').replaceFirst('line 17', 'seventeen');
    expect(hunks(unifiedDiff(a, far)), 2);
    // An insertion and a deletion.
    expect(unifiedDiff('a\nb\nc\n', 'a\nb\nx\nc\n'), contains('+x'));
    expect(unifiedDiff('a\nb\nc\n', 'a\nc\n'), contains('-b'));
    expect(unifiedDiff('', 'a\nb\n'), '@@ -1,0 +1,2 @@\n+a\n+b');
  });

  test('the diff is bounded, and the tail says how much was left out', () {
    final a = List.generate(3000, (i) => 'row $i').join('\n');
    final b = List.generate(3000, (i) => 'ROW $i').join('\n');
    final d = unifiedDiff(a, b, maxBytes: 2000);
    expect(d.length, lessThan(2100));
    expect(d, matches(RegExp(r'… \d+ more lines$')));
    expect(clipDiff(['a', 'b'], maxBytes: 100), 'a\nb');
    expect(clipDiff(['aaaa', 'b', 'c'], maxBytes: 6), 'aaaa\n… 2 more lines');
    // Big and unlike: shown as a whole replacement, still bounded.
    final big = unifiedDiff(a, b);
    expect(big.length, lessThanOrEqualTo(diffMaxBytes + 40));
  });

  test('an ask for Edit, Write or NotebookEdit carries a diff; anything else does not', () {
    final files = {'lib/main.dart': "void main() {\n  runApp(const App(title: 'Old'));\n}\n"};
    String? read(String p) => files[p];
    final edit = diffForAsk(toolName: 'Edit', input: {'file_path': 'lib/main.dart', 'old_string': "title: 'Old'", 'new_string': "title: 'New'"}, read: read)!;
    expect(edit, contains("-  runApp(const App(title: 'Old'));"));
    expect(edit, contains("+  runApp(const App(title: 'New'));"));
    expect(edit, startsWith('--- a/lib/main.dart\n+++ b/lib/main.dart\n@@'));
    final miss = diffForAsk(toolName: 'Edit', input: {'file_path': 'lib/main.dart', 'old_string': 'nope', 'new_string': 'x'}, read: read)!;
    expect(miss, contains('not in the file as it is now'));
    expect(miss, contains('-nope'));
    final gone = diffForAsk(toolName: 'Edit', input: {'file_path': 'lib/none.dart', 'old_string': 'a', 'new_string': 'b'}, read: read)!;
    expect(gone, contains('is not there'));
    final all = diffForAsk(toolName: 'Edit', input: {'file_path': 'lib/main.dart', 'old_string': 'runApp', 'new_string': 'run', 'replace_all': true}, read: (_) => 'runApp\nrunApp\n')!;
    expect('-runApp'.allMatches(all).length, 2);
    final write = diffForAsk(toolName: 'Write', input: {'file_path': 'lib/main.dart', 'content': 'void main() {}\n'}, read: read)!;
    expect(write, contains('-void main() {'));
    expect(write, contains('+void main() {}'));
    final create = diffForAsk(toolName: 'Write', input: {'file_path': 'lib/new.dart', 'content': 'a\nb'}, read: read)!;
    expect(create, '--- /dev/null\n+++ b/lib/new.dart\n+a\n+b');
    final nb = diffForAsk(toolName: 'NotebookEdit', input: {'notebook_path': 'x.ipynb', 'cell_id': 'c1', 'new_source': 'print(1)'}, read: read)!;
    expect(nb, contains('@@ cell c1 replace @@\n+print(1)'));
    expect(diffForAsk(toolName: 'Bash', input: {'command': 'ls'}, read: read), isNull);
    expect(isEditTool('Edit'), isTrue);
    expect(isEditTool('Read'), isFalse);
    expect(editedPath({'file_path': 'a.dart'}), 'a.dart');
    expect(editedPath({'notebook_path': 'n.ipynb'}), 'n.ipynb');
    expect(editedPath({'command': 'ls'}), isNull);
  });
}
