import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_verdict.dart';

/// `fromResult` reads only the verdict and the total — melds/pairs/leftovers
/// content is irrelevant here, so the fixtures keep them empty.
SolveResult _result(SolveVerdict verdict, {required int totalScore}) =>
    SolveResult(
      melds: const [],
      pairs: const [],
      leftovers: const [],
      totalScore: totalScore,
      verdict: verdict,
      reasoning: const [],
    );

void main() {
  group('ScanSummary.fromResult', () {
    test('Opens101 via melds → opens101, opened, openPath only', () {
      final summary = ScanSummary.fromResult(
        _result(
          const SolveVerdict.opens101(score: 104, via: OpenPath.melds),
          totalScore: 104,
        ),
      );

      check(summary).equals(
        const ScanSummary(
          kind: ScanVerdictKind.opens101,
          opened: true,
          score: 104,
          openPath: OpenPath.melds,
        ),
      );
      check(summary.pointsShort).isNull();
      check(summary.tilesToWin).isNull();
      check(summary.okeyPath).isNull();
    });

    test('Opens101 via pairs → openPath pairs', () {
      final summary = ScanSummary.fromResult(
        _result(
          const SolveVerdict.opens101(score: 0, via: OpenPath.pairs),
          totalScore: 0,
        ),
      );

      check(summary.kind).equals(ScanVerdictKind.opens101);
      check(summary.opened).isTrue();
      check(summary.openPath).equals(OpenPath.pairs);
      check(summary.score).equals(0);
    });

    test('DoesNotOpen101 → not opened, pointsShort only', () {
      final summary = ScanSummary.fromResult(
        _result(
          const SolveVerdict.doesNotOpen101(score: 60, pointsShort: 41),
          totalScore: 60,
        ),
      );

      check(summary).equals(
        const ScanSummary(
          kind: ScanVerdictKind.doesNotOpen101,
          opened: false,
          score: 60,
          pointsShort: 41,
        ),
      );
      check(summary.openPath).isNull();
      check(summary.tilesToWin).isNull();
      check(summary.okeyPath).isNull();
    });

    test('OkeyOutcome with tilesToWin 0 is OPENED (winning now)', () {
      final summary = ScanSummary.fromResult(
        _result(
          const SolveVerdict.okeyOutcome(
            tilesToWin: 0,
            via: OkeyPath.sevenPairs,
          ),
          totalScore: 24,
        ),
      );

      check(summary).equals(
        const ScanSummary(
          kind: ScanVerdictKind.okeyOutcome,
          opened: true,
          score: 24,
          tilesToWin: 0,
          okeyPath: OkeyPath.sevenPairs,
        ),
      );
      check(summary.openPath).isNull();
      check(summary.pointsShort).isNull();
    });

    test('OkeyOutcome with tilesToWin > 0 is not opened', () {
      final summary = ScanSummary.fromResult(
        _result(
          const SolveVerdict.okeyOutcome(
            tilesToWin: 2,
            via: OkeyPath.meldsAndPair,
          ),
          totalScore: 54,
        ),
      );

      check(summary.opened).isFalse();
      check(summary.tilesToWin).equals(2);
      check(summary.okeyPath).equals(OkeyPath.meldsAndPair);
    });

    test('score is always SolveResult.totalScore, never the verdict score', () {
      // A deliberately mismatched verdict score proves the source of truth.
      final summary = ScanSummary.fromResult(
        _result(
          const SolveVerdict.opens101(score: 104, via: OpenPath.melds),
          totalScore: 107,
        ),
      );

      check(summary.score).equals(107);
    });
  });
}
