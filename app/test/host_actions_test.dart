// The host's own hands: a file read that stays inside the project, and
// git run directly — in a real temporary repository, with a bare remote.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/host/host_actions.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late String project;
  late String attachments;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('host-actions');
    project = p.join(tmp.path, 'proj');
    attachments = p.join(tmp.path, 'attachments');
    Directory(p.join(project, 'lib')).createSync(recursive: true);
    Directory(attachments).createSync(recursive: true);
    File(p.join(project, 'lib', 'main.dart')).writeAsStringSync('void main() {\n  print(1);\n}\n');
    File(p.join(attachments, 'shot.txt')).writeAsStringSync('a shot');
    File(p.join(tmp.path, 'secret.txt')).writeAsStringSync('nope');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('read_file stays inside the project and the attachments; refuses the rest with a reason', () {
    final files = HostFiles(dir: project, attachmentsDir: attachments);
    final r = files.read('lib/main.dart');
    expect(r.ok, isTrue);
    expect(r.text, 'void main() {\n  print(1);\n}\n');
    expect(r.lines, 3);
    expect(r.bytes, 28);
    expect(r.truncated, isFalse);
    expect(files.read(p.join(project, 'lib', 'main.dart')).ok, isTrue, reason: 'absolute inside');
    expect(files.read(p.join(attachments, 'shot.txt')).text, 'a shot');
    expect(files.read('/etc/passwd').refused, contains('outside the project folder'));
    expect(files.read('../secret.txt').refused, contains('outside'));
    expect(files.read(p.join(tmp.path, 'secret.txt')).refused, contains('outside'));
    expect(files.read('lib').refused, 'a folder, not a file');
    expect(files.read('lib/none.dart').refused, 'not found');
    expect(files.read('').refused, contains('outside'));
    File(p.join(project, 'bin.dat')).writeAsBytesSync([0, 1, 2, 3]);
    expect(files.read('bin.dat').refused, 'a binary file');
    // A link out of the project is out.
    Link(p.join(project, 'leak')).createSync(p.join(tmp.path, 'secret.txt'));
    expect(files.read('leak').refused, contains('outside'));
    // Past the inline size: the first part, and the truth about the rest.
    File(p.join(project, 'big.txt')).writeAsStringSync(List.filled(1000, 'x' * 99).join('\n'));
    final big = files.read('big.txt', inlineBytes: 1000);
    expect(big.truncated, isTrue);
    expect(big.text.length, 1000);
    expect(big.lines, 1000);
    expect(big.bytes, 99999);
    final back = FileRead.fromMap(big.toMap());
    expect(back.truncated, isTrue);
    expect(back.lines, 1000);
    expect(FileRead.fromMap(files.read('lib').toMap()).refused, 'a folder, not a file');
  });

  test('git: status, commit, push to a bare remote, revert a file', () async {
    Future<ProcessResult> git(List<String> args, {String? cwd}) => Process.run('git', args, workingDirectory: cwd ?? project);
    await git(['init', '-q', '-b', 'main']);
    await git(['config', 'user.email', 't@example.com']);
    await git(['config', 'user.name', 'Test']);
    await git(['add', '-A']);
    await git(['commit', '-q', '-m', 'first']);
    final remote = p.join(tmp.path, 'remote.git');
    await Process.run('git', ['init', '-q', '--bare', remote]);
    await git(['remote', 'add', 'origin', remote]);
    await git(['push', '-q', '-u', 'origin', 'main']);
    final ops = GitOps(project, run: (args) => Process.run('git', args, workingDirectory: project));

    var s = await ops.status();
    expect(s.ok, isTrue);
    expect(s.branch, 'main');
    expect(s.dirty, 0);
    expect(s.ahead, 0);
    expect(s.behind, 0);
    expect(s.lastCommit, 'first');
    expect(GitStatus.fromMap(s.toMap()).lastCommit, 'first');

    File(p.join(project, 'lib', 'main.dart')).writeAsStringSync('void main() {}\n');
    File(p.join(project, 'new.txt')).writeAsStringSync('new');
    s = await ops.status();
    expect(s.dirty, 2, reason: 'a change and an untracked file');

    expect((await ops.commit('  ')).ok, isFalse);
    final c = await ops.commit('wip: title');
    expect(c.ok, isTrue, reason: c.output);
    s = await ops.status();
    expect(s.dirty, 0);
    expect(s.ahead, 1);
    expect(s.lastCommit, 'wip: title');

    final push = await ops.push();
    expect(push.ok, isTrue, reason: push.output);
    s = await ops.status();
    expect(s.ahead, 0);
    final remoteLog = await Process.run('git', ['log', '-1', '--pretty=%s'], workingDirectory: remote);
    expect(remoteLog.stdout.toString().trim(), 'wip: title');

    File(p.join(project, 'lib', 'main.dart')).writeAsStringSync('broken');
    expect((await ops.status()).dirty, 1);
    expect((await ops.revertFile('/etc/passwd')).ok, isFalse);
    final rv = await ops.revertFile('lib/main.dart');
    expect(rv.ok, isTrue, reason: rv.output);
    expect(rv.output, 'reverted lib/main.dart');
    expect(File(p.join(project, 'lib', 'main.dart')).readAsStringSync(), 'void main() {}\n');
    expect((await ops.status()).dirty, 0);
    final untracked = await ops.revertFile('nope.txt');
    expect(untracked.ok, isFalse);
    expect(untracked.output, contains('nope.txt'), reason: 'git\'s own line, verbatim');

    final none = await GitOps(tmp.path, run: (args) => Process.run('git', args, workingDirectory: attachments)).status();
    expect(none.ok, isFalse);
    expect(none.branch, isEmpty);
  });
}
