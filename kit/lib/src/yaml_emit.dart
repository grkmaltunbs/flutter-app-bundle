/// A small YAML emitter for the shapes this package writes.
///
/// `package:yaml` reads and `package:yaml_edit` patches, but neither writes a
/// fresh document with block scalars for markdown bodies — and a plan file is
/// mostly markdown. This emits the subset we need: maps, lists, scalars, and
/// `|` blocks for anything with a newline.
library;

String emitYaml(Object? value) {
  final b = StringBuffer();
  _emit(b, value, 0, inList: false);
  final s = b.toString();
  return s.endsWith('\n') ? s : '$s\n';
}

void _emit(StringBuffer b, Object? v, int indent, {required bool inList}) {
  if (v is Map) {
    if (v.isEmpty) {
      b.writeln('{}');
      return;
    }
    var first = true;
    for (final e in v.entries) {
      final pad = (first && inList) ? '' : ' ' * indent;
      first = false;
      b.write('$pad${_key(e.key.toString())}:');
      _emitValue(b, e.value, indent);
    }
    return;
  }
  if (v is List) {
    if (v.isEmpty) {
      b.writeln('[]');
      return;
    }
    for (final x in v) {
      final pad = ' ' * indent;
      if (x is Map && x.isNotEmpty) {
        b.write('$pad- ');
        _emit(b, x, indent + 2, inList: true);
      } else if (x is List && x.isNotEmpty) {
        b.writeln('$pad-');
        _emit(b, x, indent + 2, inList: false);
      } else {
        b.write('$pad-');
        _emitValue(b, x, indent);
      }
    }
    return;
  }
  b.writeln(_scalar(v));
}

/// Emits the value that follows a `key:` or `-`, choosing inline vs nested.
void _emitValue(StringBuffer b, Object? v, int indent) {
  if (v is Map) {
    if (v.isEmpty) {
      b.writeln(' {}');
    } else {
      b.writeln();
      _emit(b, v, indent + 2, inList: false);
    }
  } else if (v is List) {
    if (v.isEmpty) {
      b.writeln(' []');
    } else if (v.every(_isSimpleScalar)) {
      b.writeln(' [${v.map(_scalar).join(', ')}]');
    } else {
      b.writeln();
      _emit(b, v, indent + 2, inList: false);
    }
  } else if (v is String && v.contains('\n')) {
    _emitBlock(b, v, indent + 2);
  } else {
    b.writeln(' ${_scalar(v)}');
  }
}

void _emitBlock(StringBuffer b, String s, int indent) {
  final keep = s.endsWith('\n');
  final text = keep ? s.substring(0, s.length - 1) : s;
  final lines = text.split('\n');
  final firstNonEmpty = lines.firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  // If the first content line is itself indented, the parser cannot infer
  // the block's indentation — say it explicitly.
  final indicator = firstNonEmpty.startsWith(' ') ? '2' : '';
  b.writeln(' |$indicator${keep ? '' : '-'}');
  final pad = ' ' * indent;
  for (final l in lines) {
    b.writeln(l.isEmpty ? '' : '$pad$l');
  }
}

bool _isSimpleScalar(Object? v) =>
    v == null || v is num || v is bool || (v is String && !v.contains('\n') && v.length < 60);

final _plainKey = RegExp(r'^[A-Za-z_][A-Za-z0-9_\-]*$');
final _looksSpecial = RegExp(
    r'^(true|false|null|yes|no|on|off|~|-?\d[\d_]*(\.\d+)?([eE][+-]?\d+)?|0x[0-9a-fA-F]+)$',
    caseSensitive: false);
final _needsQuote = RegExp(r'''^[\s\-?:,\[\]{}#&*!|>'"%@`]|[:#]\s|:$|\s$|^\s|\t''');

String _key(String k) => _plainKey.hasMatch(k) ? k : _quote(k);

String _scalar(Object? v) {
  if (v == null) return 'null';
  if (v is bool || v is num) return v.toString();
  final s = v.toString();
  if (s.isEmpty) return "''";
  if (_looksSpecial.hasMatch(s) || _needsQuote.hasMatch(s) || s.contains('\n')) {
    return _quote(s);
  }
  // A date-like value would be parsed as a timestamp by strict parsers;
  // package:yaml keeps it a string, but quoting is the portable choice.
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) return _quote(s);
  return s;
}

String _quote(String s) =>
    '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n').replaceAll('\t', r'\t')}"';
