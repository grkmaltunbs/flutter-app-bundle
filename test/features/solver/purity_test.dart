import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

/// CLAUDE.md layer rule: `domain/` is pure Dart. The solver domain may only
/// import the Dart SDK, `core/game` (pure shared entities), the codegen
/// annotations, and its own files.
final _allowedPatterns = <RegExp>[
  RegExp('^dart:'),
  RegExp('^package:freezed_annotation/'),
  RegExp('^package:injectable/'),
  RegExp('^package:okey_acar_mi/core/game/'),
  RegExp('^package:okey_acar_mi/features/solver/domain/'),
];

final _import = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

void main() {
  group('solver domain purity', () {
    final domainDir = Directory('lib/features/solver/domain');
    final files =
        domainDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    test('the solver domain exists and is non-trivial', () {
      check(files.length).isGreaterOrEqual(10);
    });

    for (final file in files) {
      test('${file.path} imports only pure-Dart dependencies', () {
        final directives = <String>[
          for (final line in file.readAsLinesSync())
            if (_import.firstMatch(line) case final match?) match.group(1)!,
        ];
        for (final uri in directives) {
          // Relative imports stay inside the domain by construction.
          if (!uri.contains(':')) continue;
          check(
            because:
                '$uri must match an allowed pattern '
                '(no flutter, data, presentation or foreign features)',
            _allowedPatterns.any((p) => p.hasMatch(uri)),
          ).isTrue();
          check(
            because: 'no Flutter import',
            uri,
          ).not((it) => it.startsWith('package:flutter'));
          check(
            because: 'no data-layer import',
            uri,
          ).not((it) => it.contains('/data/'));
          check(
            because: 'no presentation-layer import',
            uri,
          ).not((it) => it.contains('/presentation/'));
        }
      });
    }
  });
}
