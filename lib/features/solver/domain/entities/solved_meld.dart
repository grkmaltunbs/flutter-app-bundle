import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

part 'solved_meld.freezed.dart';

/// The kind of a meld: a run (same color, consecutive numbers) or a set
/// (same number, all-distinct colors).
enum MeldKind {
  /// Same color, consecutive numbers, length 3–13, 1 low only.
  run,

  /// Same number, 3–4 tiles, all-distinct colors.
  set,
}

/// A legal meld in a solved arrangement, with its face-value points.
@freezed
abstract class SolvedMeld with _$SolvedMeld {
  /// Creates a [SolvedMeld].
  const factory SolvedMeld({
    required MeldKind kind,
    required List<SolvedSpot> spots,
    required int points,
  }) = _SolvedMeld;
}
