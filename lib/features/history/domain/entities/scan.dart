import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/features/history/domain/entities/scan_summary.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart';

part 'scan.freezed.dart';

/// A persisted scan: the confirmed rack + indicator + mode, the solver's
/// summarized verdict, and ownership/timestamps for sync.
@freezed
abstract class Scan with _$Scan {
  /// Creates a [Scan].
  const factory Scan({
    /// Stable scan id (uuid v4); doubles as the Firestore doc id.
    required String id,

    /// Creation instant (UTC, from the injected `Clock`).
    required DateTime createdAt,

    /// Last mutation instant (UTC) — the last-write-wins sync key.
    required DateTime updatedAt,

    /// The confirmed tiles in rack order.
    required List<GameTile> tiles,

    /// The game the solver ran in.
    required GameMode gameMode,

    /// The solver verdict summary.
    required ScanSummary summary,

    /// The indicator (gösterge) the user picked, or `null` when a face-down
    /// (blank okey) tile let them skip it.
    Indicator? indicator,

    /// Owning user id, or `null` for a guest-created scan.
    String? ownerId,
  }) = _Scan;

  const Scan._();

  /// The scan's solve input, for re-running the solver (e.g. when reopening
  /// a history entry on the result screen).
  ReviewOutcome get outcome =>
      ReviewOutcome(tiles: tiles, indicator: indicator, gameMode: gameMode);
}
