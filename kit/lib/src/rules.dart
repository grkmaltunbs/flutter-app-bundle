/// The rules the user edits where the user is: `CLAUDE.md`, and the
/// `qa.note` paragraph of `plan/kit.yaml` — the two targets the phone's
/// Rules editor opens. A save through the host writes the one file and
/// commits just that file, named after the first line that changed.
library;

/// The file the project's rules live in.
const rulesClaudeMd = 'CLAUDE.md';

/// A field, not a file: `qa.note` in the manifest, read and written
/// through the plan store. The host recognises this path.
const rulesQaNote = 'plan/kit.yaml:qa.note';

/// What the editor offers, in order.
const rulesTargets = [rulesClaudeMd, rulesQaNote];

/// The file a target is committed as.
String rulesCommitPath(String target) => target == rulesQaNote ? 'plan/kit.yaml' : target;

/// A short name for a target — `CLAUDE.md`, `qa note`.
String rulesLabel(String target) => target == rulesQaNote ? 'qa note' : target;

/// `rules: <first changed line>` — the first line [after] has that
/// [before] had not; failing that, the first line that went; failing
/// that, the file's name. Clipped to [width].
String rulesCommitMessage(String before, String after, {required String name, int width = 72}) {
  final was = before.split('\n');
  final now = after.split('\n');
  final gone = {...was};
  String? line;
  for (final l in now) {
    if (l.trim().isNotEmpty && !gone.contains(l)) {
      line = l.trim();
      break;
    }
  }
  if (line == null) {
    final kept = {...now};
    for (final l in was) {
      if (l.trim().isNotEmpty && !kept.contains(l)) {
        line = 'removed: ${l.trim()}';
        break;
      }
    }
  }
  line ??= '$name edited';
  final m = 'rules: $line';
  return m.length <= width ? m : '${m.substring(0, width - 1)}…';
}
