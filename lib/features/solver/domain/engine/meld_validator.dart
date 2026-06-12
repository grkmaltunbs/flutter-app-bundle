import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_meld.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_pair.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solved_spot.dart';

/// Independent legality checker for solved melds and pairs.
///
/// Validates the **played identities** (`playsAs`) of each spot — wilds and
/// needed spots are judged by what they stand for. Used as a debug invariant
/// by the reconstructors and directly by tests.
class MeldValidator {
  /// Creates a [MeldValidator].
  const MeldValidator();

  /// Whether [meld] is a legal run or set after wild substitution.
  bool isValidMeld(SolvedMeld meld) => switch (meld.kind) {
    MeldKind.run => _isValidRun(meld.spots),
    MeldKind.set => _isValidSet(meld.spots),
  };

  /// Whether [pair] is two spots of one identical color + number identity.
  bool isValidPair(SolvedPair pair) {
    final identity = pair.identity;
    if (identity.color == TileColor.joker || identity.number == null) {
      return false;
    }
    return pair.first.playsAs == identity && pair.second.playsAs == identity;
  }

  /// Run: same color, consecutive ascending numbers, no 13→1 wrap
  /// (1 is low only), length 3–13.
  bool _isValidRun(List<SolvedSpot> spots) {
    if (spots.length < 3 || spots.length > 13) return false;
    final color = spots.first.playsAs.color;
    if (color == TileColor.joker) return false;
    var previous = -1;
    for (final spot in spots) {
      final tile = spot.playsAs;
      final number = tile.number;
      if (tile.color != color || number == null) return false;
      if (previous != -1 && number != previous + 1) return false;
      previous = number;
    }
    return true;
  }

  /// Set: same number, 3–4 spots, all-distinct colors after substitution.
  bool _isValidSet(List<SolvedSpot> spots) {
    if (spots.length < 3 || spots.length > 4) return false;
    final number = spots.first.playsAs.number;
    if (number == null) return false;
    final seen = <TileColor>{};
    for (final spot in spots) {
      final tile = spot.playsAs;
      if (tile.number != number || tile.color == TileColor.joker) {
        return false;
      }
      if (!seen.add(tile.color)) return false;
    }
    return true;
  }
}
