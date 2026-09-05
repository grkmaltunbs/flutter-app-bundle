// A unified diff in pure Dart — what an Edit or Write ask shows on the
// phone before Allow, computed on the host against the file as it is on
// disk. No I/O here: the host reads, this compares.

import 'dart:typed_data';

/// How much diff travels to the phone; past it, a tail says how many
/// lines were left out.
const diffMaxBytes = 24 * 1024;

/// A unified diff of [oldText] against [newText], line by line, with
/// [context] lines around each change and `@@` hunk headers. Empty when
/// the texts are the same. Bounded at [maxBytes] with a "… n more lines"
/// tail.
String unifiedDiff(String oldText, String newText, {String? path, int context = 3, int maxBytes = diffMaxBytes}) {
  if (oldText == newText) return '';
  final a = _lines(oldText);
  final b = _lines(newText);
  final ops = _diffOps(a, b);
  final out = <String>[];
  if (path != null) {
    out.add('--- a/${_rel(path)}');
    out.add('+++ b/${_rel(path)}');
  }
  // Group the ops into hunks: a run of changes with [context] equal lines
  // on either side; two runs closer than 2×context share one hunk.
  var i = 0;
  while (i < ops.length) {
    if (ops[i].kind == _Kind.same) {
      i++;
      continue;
    }
    final start = i;
    var end = i;
    var j = i;
    while (j < ops.length) {
      if (ops[j].kind != _Kind.same) {
        end = j;
        j++;
        continue;
      }
      // Equal lines: look ahead — another change within 2×context joins.
      var k = j;
      while (k < ops.length && ops[k].kind == _Kind.same) {
        k++;
      }
      if (k < ops.length && k - j <= 2 * context) {
        j = k;
        continue;
      }
      break;
    }
    final from = start - context < 0 ? 0 : start - context;
    final to = end + context + 1 > ops.length ? ops.length : end + context + 1;
    var oldStart = 0, newStart = 0;
    for (var x = 0; x < from; x++) {
      if (ops[x].kind != _Kind.add) oldStart++;
      if (ops[x].kind != _Kind.remove) newStart++;
    }
    var oldCount = 0, newCount = 0;
    for (var x = from; x < to; x++) {
      if (ops[x].kind != _Kind.add) oldCount++;
      if (ops[x].kind != _Kind.remove) newCount++;
    }
    out.add('@@ -${oldStart + 1},$oldCount +${newStart + 1},$newCount @@');
    for (var x = from; x < to; x++) {
      final o = ops[x];
      out.add(switch (o.kind) {
        _Kind.same => ' ${o.text}',
        _Kind.add => '+${o.text}',
        _Kind.remove => '-${o.text}',
      });
    }
    i = to;
  }
  return clipDiff(out, maxBytes: maxBytes);
}

/// The first [maxBytes] of [lines], joined, with a tail naming what was
/// left out — never a cut in the middle of a line.
String clipDiff(List<String> lines, {int maxBytes = diffMaxBytes}) {
  var size = 0;
  for (var i = 0; i < lines.length; i++) {
    size += lines[i].length + 1;
    if (size > maxBytes) {
      final kept = lines.sublist(0, i);
      final left = lines.length - i;
      kept.add('… $left more line${left == 1 ? '' : 's'}');
      return kept.join('\n');
    }
  }
  return lines.join('\n');
}

/// The diff an ask for an editing tool shows — null for any other tool.
/// [read] hands back the file as it is on disk, or null when there is
/// none (a Write that creates it). `Edit` applies its old/new strings to
/// the file; `Write` compares the whole file; `NotebookEdit` shows the
/// new source as added lines, since a notebook is not a text file.
String? diffForAsk({required String toolName, required Map<String, Object?> input, required String? Function(String path) read}) {
  switch (toolName) {
    case 'Edit':
      final path = (input['file_path'] ?? '').toString();
      final oldS = (input['old_string'] ?? '').toString();
      final newS = (input['new_string'] ?? '').toString();
      final file = read(path);
      if (file == null) return clipDiff(['--- a/${_rel(path)}', '+++ b/${_rel(path)}', '(the file is not there — this edit will fail)', ...oldS.split('\n').map((l) => '-$l'), ...newS.split('\n').map((l) => '+$l')]);
      if (!file.contains(oldS)) {
        return clipDiff(['--- a/${_rel(path)}', '+++ b/${_rel(path)}', '(the old text is not in the file as it is now — this edit will fail)', ...oldS.split('\n').map((l) => '-$l'), ...newS.split('\n').map((l) => '+$l')]);
      }
      final after = input['replace_all'] == true ? file.replaceAll(oldS, newS) : file.replaceFirst(oldS, newS);
      return unifiedDiff(file, after, path: path);
    case 'Write':
      final path = (input['file_path'] ?? '').toString();
      final content = (input['content'] ?? '').toString();
      final file = read(path);
      if (file == null) return clipDiff(['--- /dev/null', '+++ b/${_rel(path)}', ...content.split('\n').map((l) => '+$l')]);
      return unifiedDiff(file, content, path: path);
    case 'NotebookEdit':
      final path = (input['notebook_path'] ?? '').toString();
      final mode = (input['edit_mode'] ?? 'replace').toString();
      final source = (input['new_source'] ?? '').toString();
      final cell = (input['cell_id'] ?? '').toString();
      return clipDiff(['--- a/${_rel(path)}', '+++ b/${_rel(path)}', '@@ cell ${cell.isEmpty ? '' : '$cell '}$mode @@', ...source.split('\n').map((l) => '+$l')]);
    default:
      return null;
  }
}

/// True for the tools whose asks and rows carry a diff.
bool isEditTool(String toolName) => toolName == 'Edit' || toolName == 'Write' || toolName == 'NotebookEdit';

/// The path an editing tool's input names — for the tap that opens it.
String? editedPath(Map<String, Object?> input) {
  final v = input['file_path'] ?? input['notebook_path'] ?? input['path'];
  final s = v?.toString() ?? '';
  return s.isEmpty ? null : s;
}

/// git's headers carry paths without a leading slash — `a//Users/…` reads
/// wrong, and the CLI hands the host absolute paths.
String _rel(String path) => path.startsWith('/') ? path.substring(1) : path;

enum _Kind { same, add, remove }

class _Op {
  const _Op(this.kind, this.text);
  final _Kind kind;
  final String text;
}

List<String> _lines(String s) {
  if (s.isEmpty) return const [];
  final l = s.split('\n');
  if (l.isNotEmpty && l.last.isEmpty) l.removeLast();
  return l;
}

/// The cells the LCS table may hold before the middle is shown as a whole
/// replacement instead — 1500 × 1500 lines.
const _lcsCap = 2250000;

/// Same / add / remove per line: common prefix and suffix first, then a
/// longest-common-subsequence over what is left when it is small enough.
List<_Op> _diffOps(List<String> a, List<String> b) {
  var pre = 0;
  while (pre < a.length && pre < b.length && a[pre] == b[pre]) {
    pre++;
  }
  var suf = 0;
  while (suf < a.length - pre && suf < b.length - pre && a[a.length - 1 - suf] == b[b.length - 1 - suf]) {
    suf++;
  }
  final ops = <_Op>[for (var i = 0; i < pre; i++) _Op(_Kind.same, a[i])];
  final ma = a.sublist(pre, a.length - suf);
  final mb = b.sublist(pre, b.length - suf);
  if (ma.isEmpty || mb.isEmpty || ma.length * mb.length > _lcsCap) {
    ops.addAll(ma.map((l) => _Op(_Kind.remove, l)));
    ops.addAll(mb.map((l) => _Op(_Kind.add, l)));
  } else {
    ops.addAll(_lcs(ma, mb));
  }
  ops.addAll([for (var i = a.length - suf; i < a.length; i++) _Op(_Kind.same, a[i])]);
  return ops;
}

List<_Op> _lcs(List<String> a, List<String> b) {
  final n = a.length, m = b.length;
  final w = m + 1;
  final t = Uint32List((n + 1) * w);
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      t[i * w + j] = a[i] == b[j] ? t[(i + 1) * w + j + 1] + 1 : (t[(i + 1) * w + j] > t[i * w + j + 1] ? t[(i + 1) * w + j] : t[i * w + j + 1]);
    }
  }
  final ops = <_Op>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      ops.add(_Op(_Kind.same, a[i]));
      i++;
      j++;
    } else if (t[(i + 1) * w + j] >= t[i * w + j + 1]) {
      ops.add(_Op(_Kind.remove, a[i]));
      i++;
    } else {
      ops.add(_Op(_Kind.add, b[j]));
      j++;
    }
  }
  while (i < n) {
    ops.add(_Op(_Kind.remove, a[i++]));
  }
  while (j < m) {
    ops.add(_Op(_Kind.add, b[j++]));
  }
  return ops;
}
