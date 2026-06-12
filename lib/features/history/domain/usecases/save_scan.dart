import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/time/clock.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/history/domain/repositories/scan_repository.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';
import 'package:uuid/uuid.dart';

/// Persists a finished solve as a [Scan]: mints the id + UTC timestamps,
/// derives the summary, and stamps the current owner.
@injectable
class SaveScan {
  /// Creates a [SaveScan].
  const SaveScan(this._scans, this._auth, this._clock);

  final ScanRepository _scans;
  final AuthRepository _auth;
  final Clock _clock;

  /// Builds and saves the scan for [outcome] solved as [result]; returns the
  /// persisted entity.
  Future<Scan> call({
    required ReviewOutcome outcome,
    required SolveResult result,
  }) async {
    final now = _clock.now().toUtc();
    final scan = Scan(
      id: const Uuid().v4(),
      ownerId: _auth.currentUser?.id,
      createdAt: now,
      updatedAt: now,
      tiles: outcome.tiles,
      indicator: outcome.indicator,
      gameMode: outcome.gameMode,
      summary: ScanSummary.fromResult(result),
    );
    await _scans.save(scan);
    return scan;
  }
}
