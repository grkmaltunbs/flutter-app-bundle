/// Fence-aware line scanning shared by the importer and the renderer.
///
/// A plan's markdown carries code fences whose *contents* can look like
/// headings (`## `, `### `) or checkboxes. Every structural scan in this
/// package goes through [scanLines] so a fence never splits a step.
library;

class ScannedLine {
  const ScannedLine(this.index, this.text, {required this.inFence});
  final int index;
  final String text;
  final bool inFence;
}

final _fence = RegExp(r'^\s*(```|~~~)');

Iterable<ScannedLine> scanLines(String text) sync* {
  var inFence = false;
  var i = 0;
  for (final line in text.split('\n')) {
    final isFence = _fence.hasMatch(line);
    if (isFence) {
      // The fence line itself is structural (never a heading) — report it as
      // inside so heading regexes skip it either way.
      yield ScannedLine(i, line, inFence: true);
      inFence = !inFence;
    } else {
      yield ScannedLine(i, line, inFence: inFence);
    }
    i++;
  }
}
