// What the host does for the phone without a model: read a file inside
// the project, and run git. Each is a `host` command in the relay —
// `{type: host, action: read_file|git, …}` — answered in the command's
// result and, for a file, in `files/{commandId}`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_kit/kit.dart' show kitHome;
import 'package:path/path.dart' as p;

import 'claude_cli.dart';

// ---------------------------------------------------------------- worktrees

/// A worktree's relay slug: the parent's with the tree's name after `~`.
String worktreeSlug(String parentSlug, String name) => '$parentSlug~$name';

/// A tree's name is its branch: letters, digits, `.`, `_`, `-`; no `..`.
bool validWorktreeName(String name) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch(name) && !name.contains('..') && !name.endsWith('.lock');

/// Where a project's worktrees live: `~/.flutter_kit/worktrees/<slug>/<name>`.
String worktreePath(String parentSlug, String name, {String? home}) => p.join(kitHome(home: home), 'worktrees', parentSlug, name);

/// The names of the trees a project has on disk, from that folder.
List<String> worktreeNamesOf(String parentSlug, {String? home}) {
  final root = Directory(p.join(kitHome(home: home), 'worktrees', parentSlug));
  if (!root.existsSync()) return const [];
  return [for (final e in root.listSync()) if (e is Directory && validWorktreeName(p.basename(e.path))) p.basename(e.path)]..sort();
}

/// What a merge came to: the commit, or the files git left in conflict.
class MergeResult {
  const MergeResult({required this.ok, this.commit = '', this.conflicts = const [], this.output = ''});
  final bool ok;

  /// `1a2b3c4 Merge branch 'settings'` when [ok].
  final String commit;

  /// Paths git left with markers — the tree stays as git left it.
  final List<String> conflicts;
  final String output;
  bool get conflict => conflicts.isNotEmpty;
}

/// How much of a file rides in the Firestore document; past it the whole
/// file goes to Storage and the document carries the first part.
const fileInlineBytes = 200 * 1024;

/// Past this the host does not read it at all.
const fileMaxBytes = 8 * 1024 * 1024;

/// What the host answers to a `read_file`: the text, or why not.
class FileRead {
  const FileRead.ok({required this.path, required this.text, required this.lines, required this.bytes, this.truncated = false, this.blob}) : refused = null;
  const FileRead.refused(this.path, this.refused)
      : text = '',
        lines = 0,
        bytes = 0,
        truncated = false,
        blob = null;

  factory FileRead.fromMap(Map<String, Object?> m) {
    final refused = m['refused']?.toString();
    final path = (m['path'] ?? '').toString();
    if (refused != null) return FileRead.refused(path, refused);
    return FileRead.ok(
      path: path,
      text: (m['text'] ?? '').toString(),
      lines: (m['lines'] as num?)?.toInt() ?? 0,
      bytes: (m['bytes'] as num?)?.toInt() ?? 0,
      truncated: m['truncated'] == true,
      blob: m['blob']?.toString(),
    );
  }

  /// The path as the phone asked for it.
  final String path;
  final String text;
  final int lines;
  final int bytes;

  /// [text] is the first [fileInlineBytes]; the whole file is at [blob]
  /// in Storage.
  final bool truncated;
  final String? blob;
  final String? refused;

  bool get ok => refused == null;

  Map<String, Object?> toMap() => {
        'path': path,
        'text': text,
        'lines': lines,
        'bytes': bytes,
        'truncated': truncated,
        if (blob != null) 'blob': blob,
        if (refused != null) 'refused': refused,
      };
}

/// Reads files for the phone — only inside the project folder or its
/// attachments folder. Anything else, a folder, a binary, or a file past
/// [fileMaxBytes] is refused with a reason the row can show.
class HostFiles {
  HostFiles({required this.dir, required this.attachmentsDir});
  final String dir;
  final String attachmentsDir;

  /// The absolute path a request may read, or null when it lies outside
  /// both folders — after symlinks, so a link out of the project is out.
  String? resolve(String path) {
    if (path.trim().isEmpty) return null;
    final abs = p.normalize(p.isAbsolute(path) ? path : p.join(dir, path));
    final real = _real(abs);
    for (final root in [dir, attachmentsDir]) {
      final r = _real(root);
      if (p.equals(r, real) || p.isWithin(r, real)) return abs;
    }
    return null;
  }

  /// The path with every symlink followed. A path that is not there yet
  /// resolves through its nearest existing parent — a temp folder that is
  /// itself a link must not read as "outside".
  static String _real(String path) {
    try {
      return File(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      try {
        return Directory(path).resolveSymbolicLinksSync();
      } on FileSystemException {
        final parent = p.dirname(path);
        if (parent == path) return path;
        return p.join(_real(parent), p.basename(path));
      }
    }
  }

  FileRead read(String path, {int inlineBytes = fileInlineBytes}) {
    final abs = resolve(path);
    if (abs == null) return FileRead.refused(path, 'outside the project folder — the host reads only inside it and its attachments');
    if (Directory(abs).existsSync()) return FileRead.refused(path, 'a folder, not a file');
    final f = File(abs);
    if (!f.existsSync()) return FileRead.refused(path, 'not found');
    final size = f.lengthSync();
    if (size > fileMaxBytes) return FileRead.refused(path, 'too big to show (${(size / (1024 * 1024)).toStringAsFixed(1)} MB)');
    final bytes = f.readAsBytesSync();
    final head = bytes.length > 8192 ? bytes.sublist(0, 8192) : bytes;
    if (head.contains(0)) return FileRead.refused(path, 'a binary file');
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = text.isEmpty ? 0 : '\n'.allMatches(text).length + (text.endsWith('\n') ? 0 : 1);
    if (bytes.length <= inlineBytes) return FileRead.ok(path: path, text: text, lines: lines, bytes: bytes.length);
    return FileRead.ok(path: path, text: utf8.decode(bytes.sublist(0, inlineBytes), allowMalformed: true), lines: lines, bytes: bytes.length, truncated: true);
  }
}

/// The Git card's numbers: what the host reads after every turn.
class GitStatus {
  const GitStatus({required this.branch, this.ahead = 0, this.behind = 0, this.dirty = 0, this.lastCommit = '', this.error, this.at});

  factory GitStatus.fromMap(Map<String, Object?> m) => GitStatus(
        branch: (m['branch'] ?? '').toString(),
        ahead: (m['ahead'] as num?)?.toInt() ?? 0,
        behind: (m['behind'] as num?)?.toInt() ?? 0,
        dirty: (m['dirty'] as num?)?.toInt() ?? 0,
        lastCommit: (m['lastCommit'] ?? '').toString(),
        error: m['error']?.toString(),
        at: DateTime.tryParse((m['at'] ?? '').toString()),
      );

  final String branch;
  final int ahead;
  final int behind;

  /// Paths `git status --porcelain` lists — changed, added, untracked.
  final int dirty;

  /// The last commit's first line.
  final String lastCommit;

  /// Not a repository, or git said no.
  final String? error;
  final DateTime? at;

  bool get ok => error == null;

  Map<String, Object?> toMap() => {
        'branch': branch,
        'ahead': ahead,
        'behind': behind,
        'dirty': dirty,
        'lastCommit': lastCommit,
        if (error != null) 'error': error,
        if (at != null) 'at': at!.toUtc().toIso8601String(),
      };
}

/// What a git command came to.
class GitResult {
  const GitResult({required this.ok, required this.output});
  final bool ok;
  final String output;
}

typedef GitRunner = Future<ProcessResult> Function(List<String> args);

/// Git in the project folder, run by the host directly — no model, no
/// quota. [run] is injectable; the default runs `git` on the shell PATH.
class GitOps {
  GitOps(this.dir, {this.run});
  final String dir;
  final GitRunner? run;

  Future<ProcessResult> _git(List<String> args) async {
    final r = run;
    if (r != null) return r(args);
    return Process.run('git', args, workingDirectory: dir, environment: {...Platform.environment, 'PATH': await ClaudeCli.shellPath()});
  }

  static String _out(ProcessResult r) => '${r.stdout}${r.stderr}'.trim();

  Future<GitStatus> status() async {
    final now = DateTime.now();
    final branch = await _git(['rev-parse', '--abbrev-ref', 'HEAD']);
    if (branch.exitCode != 0) return GitStatus(branch: '', error: _out(branch).isEmpty ? 'not a git repository' : _out(branch), at: now);
    var ahead = 0, behind = 0;
    final counts = await _git(['rev-list', '--left-right', '--count', '@{u}...HEAD']);
    if (counts.exitCode == 0) {
      final parts = counts.stdout.toString().trim().split(RegExp(r'\s+'));
      if (parts.length == 2) {
        behind = int.tryParse(parts[0]) ?? 0;
        ahead = int.tryParse(parts[1]) ?? 0;
      }
    }
    final porcelain = await _git(['status', '--porcelain']);
    final dirty = porcelain.stdout.toString().split('\n').where((l) => l.trim().isNotEmpty).length;
    final last = await _git(['log', '-1', '--pretty=%s']);
    return GitStatus(branch: branch.stdout.toString().trim(), ahead: ahead, behind: behind, dirty: dirty, lastCommit: last.exitCode == 0 ? last.stdout.toString().trim() : '', at: now);
  }

  /// `git add -A && git commit -m <message>`.
  Future<GitResult> commit(String message) async {
    final m = message.trim();
    if (m.isEmpty) return const GitResult(ok: false, output: 'a commit needs a message');
    final add = await _git(['add', '-A']);
    if (add.exitCode != 0) return GitResult(ok: false, output: _out(add));
    final c = await _git(['commit', '-m', m]);
    return GitResult(ok: c.exitCode == 0, output: _out(c));
  }

  /// `git push` — the error line comes back verbatim when the remote or
  /// the credentials are not there.
  Future<GitResult> push() async {
    final r = await _git(['push']);
    return GitResult(ok: r.exitCode == 0, output: _out(r));
  }

  /// `git worktree add <path> -b <branch>` — a second checkout of this
  /// repository on a new branch, in its own folder.
  Future<GitResult> worktreeAdd(String path, String branch) async {
    // Remove keeps the branch; a new tree under the same name picks that
    // branch up again rather than failing on "already exists".
    final have = await _git(['rev-parse', '--verify', '--quiet', 'refs/heads/$branch']);
    final existing = have.exitCode == 0;
    final r = await _git(['worktree', 'add', path, if (!existing) '-b', branch]);
    return GitResult(ok: r.exitCode == 0, output: r.exitCode == 0 ? 'worktree $branch at $path${existing ? ' (the branch existed; it is checked out again)' : ''}' : _out(r));
  }

  /// `git worktree remove [--force] <path>`. Git refuses a dirty tree
  /// without [force]; its line comes back verbatim.
  Future<GitResult> worktreeRemove(String path, {bool force = false}) async {
    final r = await _git(['worktree', 'remove', if (force) '--force', path]);
    return GitResult(ok: r.exitCode == 0, output: r.exitCode == 0 ? 'removed $path' : _out(r));
  }

  /// `git merge --no-ff <branch>` in this folder. A clean merge names its
  /// commit; a conflict lists the files and leaves the tree as git left
  /// it; anything else (a dirty tree, an unknown branch) is git's own line.
  Future<MergeResult> merge(String branch) async {
    final r = await _git(['merge', '--no-ff', '--no-edit', branch]);
    if (r.exitCode == 0) {
      final last = await _git(['log', '-1', '--pretty=%h %s']);
      return MergeResult(ok: true, commit: last.exitCode == 0 ? last.stdout.toString().trim() : '', output: _out(r));
    }
    return MergeResult(ok: false, conflicts: await conflicts(), output: _out(r));
  }

  /// The paths a merge left with markers — empty when no merge is open.
  Future<List<String>> conflicts() async {
    final files = await _git(['diff', '--name-only', '--diff-filter=U']);
    if (files.exitCode != 0) return const [];
    return [for (final l in files.stdout.toString().split('\n')) if (l.trim().isNotEmpty) l.trim()];
  }

  /// `git checkout -- <path>`: the file as the last commit has it. The
  /// path must be inside the project.
  Future<GitResult> revertFile(String path) async {
    final abs = p.normalize(p.isAbsolute(path) ? path : p.join(dir, path));
    if (!p.isWithin(dir, abs)) return const GitResult(ok: false, output: 'not inside the project folder');
    final rel = p.relative(abs, from: dir);
    final r = await _git(['checkout', '--', rel]);
    return GitResult(ok: r.exitCode == 0, output: r.exitCode == 0 ? 'reverted $rel' : _out(r));
  }
}
