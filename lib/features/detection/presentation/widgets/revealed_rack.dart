import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/widgets/rack.dart';
import 'package:okey_acar_mi/core/widgets/tile_data.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';

/// Maps a detection-domain tile onto the design system's rack tile model.
extension DetectedTileX on DetectedTile {
  /// The [TileData] equivalent: jokers keep their null number and any tile
  /// under the confidence threshold carries the low-confidence warn ring.
  TileData toTileData() => TileData(
    color: color,
    number: number,
    lowConfidence: confidence < kLowConfidenceThreshold,
  );
}

/// The progressive rack reveal on the analyzing screen: renders the tiles
/// detected so far on the shared [Rack] (which flexes 14–21 tiles across two
/// rows without overflow at any size).
///
/// The reveal "animation" is the rack growing as tiles stream in; under
/// reduce-motion the growth snaps instead of animating.
class RevealedRack extends StatelessWidget {
  /// Creates a [RevealedRack].
  const RevealedRack({required this.tiles, super.key});

  /// The tiles revealed so far, in rack order.
  final List<DetectedTile> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final rack = Rack(
      tiles: [for (final tile in tiles) tile.toTileData()],
    );
    if (MediaQuery.disableAnimationsOf(context)) return rack;
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.topCenter,
      child: rack,
    );
  }
}
