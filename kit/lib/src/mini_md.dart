/// A deliberately small markdown → HTML converter for item bodies and step
/// sections: paragraphs, headings, bullet and numbered lists, fenced code,
/// inline code, bold, italic, strike, links, blockquotes. Anything else is
/// escaped text. No dependency, no surprises.
library;

String escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

final _inlineCode = RegExp(r'`([^`]+)`');
final _bold = RegExp(r'\*\*(.+?)\*\*');
final _italic = RegExp(r'(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])');
final _strike = RegExp(r'~~(.+?)~~');
final _link = RegExp(r'\[([^\]]+)\]\((https?://[^)\s]+)\)');
final _autoUrl = RegExp(r'(?<![">])(https?://[^\s<)]+)');
// Sentinels that cannot occur in escaped text.
const _open = '';
const _close = '';
final _placeholder = RegExp('$_open(\\d+)$_close');

String inlineMd(String s) {
  // Protect code spans first so nothing inside them is styled.
  final codes = <String>[];
  var t = escapeHtml(s).replaceAllMapped(_inlineCode, (m) {
    codes.add('<code>${m.group(1)}</code>');
    return '$_open${codes.length - 1}$_close';
  });
  t = t.replaceAllMapped(_link, (m) => '<a href="${m.group(2)}">${m.group(1)}</a>');
  t = t.replaceAllMapped(_autoUrl, (m) => '<a href="${m.group(1)}">${m.group(1)}</a>');
  t = t.replaceAllMapped(_bold, (m) => '<strong>${m.group(1)}</strong>');
  t = t.replaceAllMapped(_strike, (m) => '<s>${m.group(1)}</s>');
  t = t.replaceAllMapped(_italic, (m) => '<em>${m.group(1)}</em>');
  t = t.replaceAllMapped(_placeholder, (m) => codes[int.parse(m.group(1)!)]);
  return t;
}

final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
final _listLine = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+(.*)$');
final _listLead = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+');
final _checkbox = RegExp(r'^\[([ xX])\]\s+(.*)$');

String mdToHtml(String md) {
  final out = StringBuffer();
  final lines = md.split('\n');
  var i = 0;
  final para = <String>[];
  void flushPara() {
    if (para.isEmpty) return;
    out.writeln('<p>${inlineMd(para.join(' '))}</p>');
    para.clear();
  }

  while (i < lines.length) {
    final line = lines[i].trimRight();
    final t = line.trimLeft();
    if (t.isEmpty) {
      flushPara();
      i++;
      continue;
    }
    if (t.startsWith('```')) {
      flushPara();
      final buf = <String>[];
      i++;
      while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
        buf.add(lines[i]);
        i++;
      }
      i++;
      out.writeln('<pre><code>${escapeHtml(_dedent(buf).join('\n'))}</code></pre>');
      continue;
    }
    final h = _heading.firstMatch(t);
    if (h != null) {
      flushPara();
      final level = (h.group(1)!.length + 2).clamp(3, 6);
      out.writeln('<h$level>${inlineMd(h.group(2)!)}</h$level>');
      i++;
      continue;
    }
    if (t.startsWith('<!--')) {
      // HTML comments in the source stay invisible.
      while (i < lines.length && !lines[i].contains('-->')) {
        i++;
      }
      i++;
      continue;
    }
    if (t.startsWith('>')) {
      flushPara();
      final buf = <String>[];
      while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
        buf.add(lines[i].trimLeft().replaceFirst(RegExp(r'^>\s?'), ''));
        i++;
      }
      out.writeln('<blockquote>${mdToHtml(buf.join('\n'))}</blockquote>');
      continue;
    }
    final li = _listLine.firstMatch(line);
    if (li != null) {
      flushPara();
      final ordered = !RegExp(r'^[-*+]$').hasMatch(li.group(2)!);
      final baseIndent = li.group(1)!.length;
      out.writeln(ordered ? '<ol>' : '<ul>');
      while (i < lines.length) {
        final m = _listLine.firstMatch(lines[i].trimRight());
        if (m == null || m.group(1)!.length != baseIndent) break;
        final itemLines = <String>[m.group(3)!];
        i++;
        // Continuation: deeper-indented lines, or blank lines followed by them.
        final nested = <String>[];
        while (i < lines.length) {
          final l = lines[i];
          if (l.trim().isEmpty) {
            if (i + 1 < lines.length && lines[i + 1].startsWith(' ' * (baseIndent + 2))) {
              nested.add('');
              i++;
              continue;
            }
            break;
          }
          final indent = l.length - l.trimLeft().length;
          if (indent <= baseIndent) break;
          final sub = _listLead.firstMatch(l);
          if (sub != null || nested.isNotEmpty) {
            final cut = baseIndent + 2 <= l.length ? baseIndent + 2 : l.length;
            nested.add(l.substring(cut));
          } else {
            itemLines.add(l.trim());
          }
          i++;
        }
        final cb = _checkbox.firstMatch(itemLines.first);
        var head = itemLines.join(' ');
        var cls = '';
        if (cb != null) {
          head = '${cb.group(2)!} ${itemLines.skip(1).join(' ')}'.trim();
          cls = cb.group(1) == ' ' ? ' class="todo"' : ' class="done"';
        }
        out.write('<li$cls>${inlineMd(head)}');
        if (nested.isNotEmpty) out.write(mdToHtml(nested.join('\n')));
        out.writeln('</li>');
      }
      out.writeln(ordered ? '</ol>' : '</ul>');
      continue;
    }
    if (RegExp(r'^-{3,}$').hasMatch(t)) {
      flushPara();
      out.writeln('<hr>');
      i++;
      continue;
    }
    para.add(t);
    i++;
  }
  flushPara();
  return out.toString();
}

List<String> _dedent(List<String> lines) {
  var min = 1 << 20;
  for (final l in lines) {
    if (l.trim().isEmpty) continue;
    final n = l.length - l.trimLeft().length;
    if (n < min) min = n;
  }
  if (min == 1 << 20) return lines;
  return [for (final l in lines) l.length >= min ? l.substring(min) : l.trimLeft()];
}
