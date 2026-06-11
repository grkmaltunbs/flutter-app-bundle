import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/core/theme/app_palette.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';

// `TileColor` moved to core/game so pure-Dart layers (detection/solver
// domains) can use it without a Flutter import; re-exported here so every
// existing `tile.dart` call site keeps compiling unchanged.
export 'package:okey_acar_mi/core/game/tile_color.dart';

/// The preset render size of a [Tile].
///
/// Widths come from the design bundle (`tiles.jsx`); height is `width * 1.42`.
enum TileSize {
  /// 22pt wide.
  xs(22),

  /// 30pt wide.
  sm(30),

  /// 38pt wide.
  md(38),

  /// 46pt wide.
  lg(46),

  /// 60pt wide.
  xl(60)
  ;

  const TileSize(this.width);

  /// The tile width in logical pixels.
  final double width;
}

/// A single Okey tile rendered in one of four [TileStyle]s.
///
/// Sizing is derived entirely from [widthOverride] or [size] (height, radius,
/// and numeral size all scale from width), so a [Tile] never imposes a fixed
/// `MediaQuery`-relative dimension and is safe to shrink inside a rack.
class Tile extends StatelessWidget {
  /// Creates a [Tile].
  ///
  /// Pass [number] for a numbered tile; omit it (and set [color] to
  /// [TileColor.joker]) for the joker glyph.
  const Tile({
    required this.color,
    this.number,
    this.size = TileSize.md,
    this.style,
    this.widthOverride,
    this.selected = false,
    this.faded = false,
    this.onTap,
    super.key,
  });

  /// The tile numeral, or null for a joker.
  final int? number;

  /// The tile color (one of the four, or joker).
  final TileColor color;

  /// The preset size; ignored when [widthOverride] is set.
  final TileSize size;

  /// The render style; defaults to the active `context.palette.tileStyle`.
  final TileStyle? style;

  /// An explicit width override (used by a rack to fit a row to constraints).
  final double? widthOverride;

  /// Whether the tile is selected (accent ring + slight lift).
  final bool selected;

  /// Whether the tile is faded (used / unavailable).
  final bool faded;

  /// Tap handler; when null the tile is non-interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final effectiveStyle = style ?? palette.tileStyle;
    final width = widthOverride ?? size.width;
    final height = width * 1.42;
    final radius = width * 0.13;
    final numeralSize = width * 0.58;

    // A tile is a physical object: its footprint and numeral are derived from
    // [width] and must not change with the OS text scale, so disable scaling on
    // the numerals to keep the tile overflow-safe at any textScale.
    final visual = MediaQuery.withNoTextScaling(
      child: Opacity(
        opacity: faded ? 0.3 : 1,
        child: Transform.translate(
          offset: selected ? const Offset(0, -4) : Offset.zero,
          child: _face(
            context: context,
            palette: palette,
            tileStyle: effectiveStyle,
            width: width,
            height: height,
            radius: radius,
            numeralSize: numeralSize,
          ),
        ),
      ),
    );

    final labeled = Semantics(
      label: _semanticsLabel(context),
      button: onTap != null,
      // Exclude the inner numeral `Text` from the semantics tree so a screen
      // reader announces the composed label (e.g. "Red 7") once, rather than
      // "Red 7" followed by the numeral "7" again.
      excludeSemantics: true,
      child: visual,
    );

    if (onTap == null) return labeled;

    // Keep the visual at its intrinsic size, but guarantee a >=48dp hit target.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(child: labeled),
      ),
    );
  }

  String _semanticsLabel(BuildContext context) {
    final l10n = context.l10n;
    if (color == TileColor.joker) return l10n.jokerSemantics;
    final colorName = switch (color) {
      TileColor.red => l10n.tileColorRed,
      TileColor.black => l10n.tileColorBlack,
      TileColor.yellow => l10n.tileColorYellow,
      TileColor.blue => l10n.tileColorBlue,
      TileColor.joker => l10n.jokerSemantics,
    };
    return l10n.tileSemantics(colorName, number ?? 0);
  }

  Color _color(AppPalette palette) => switch (color) {
    TileColor.red => palette.tileRed,
    TileColor.black => palette.tileBlack,
    TileColor.yellow => palette.tileYellow,
    TileColor.blue => palette.tileBlue,
    TileColor.joker => palette.tileBlack,
  };

  Widget _face({
    required BuildContext context,
    required AppPalette palette,
    required TileStyle tileStyle,
    required double width,
    required double height,
    required double radius,
    required double numeralSize,
  }) {
    switch (tileStyle) {
      case TileStyle.classic:
        return _classic(palette, width, height, radius, numeralSize);
      case TileStyle.flat:
        return _flat(palette, width, height, radius, numeralSize);
      case TileStyle.minimal:
        return _minimal(palette, width, height, radius, numeralSize);
      case TileStyle.bold:
        return _bold(palette, width, height, radius, numeralSize);
    }
  }

  Widget _classic(
    AppPalette palette,
    double width,
    double height,
    double radius,
    double numeralSize,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.tileFace, palette.tileFaceEdge],
        ),
        border: selected
            ? Border.all(color: palette.accent, width: 1.5)
            : Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? 0.18 : 0.08),
            blurRadius: selected ? 10 : 2,
            offset: Offset(0, selected ? 4 : 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (color == TileColor.joker)
            _joker(numeralSize, _color(palette))
          else
            Text(
              '$number',
              style: AppTypography.serifStyle(
                fontSize: numeralSize * 1.05,
                color: _color(palette),
              ),
            ),
          Positioned(
            left: 3,
            right: 3,
            top: height * 0.52,
            child: Container(
              height: 1,
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flat(
    AppPalette palette,
    double width,
    double height,
    double radius,
    double numeralSize,
  ) {
    final face = color == TileColor.joker ? palette.ink : _color(palette);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: face,
        borderRadius: BorderRadius.circular(radius),
        border: selected ? Border.all(color: palette.accent, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? 0.2 : 0.08),
            blurRadius: selected ? 12 : 2,
            offset: Offset(0, selected ? 4 : 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: color == TileColor.joker
          ? _joker(numeralSize, Colors.white)
          : Text(
              '$number',
              style: AppTypography.monoStyle(
                fontSize: numeralSize,
                color: Colors.white,
              ),
            ),
    );
  }

  Widget _minimal(
    AppPalette palette,
    double width,
    double height,
    double radius,
    double numeralSize,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(radius),
        border: selected
            ? Border.all(color: palette.accent, width: 2)
            : Border.all(color: palette.line),
      ),
      alignment: Alignment.center,
      child: color == TileColor.joker
          ? _joker(numeralSize * 0.7, _color(palette))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: numeralSize * 0.32,
                  height: numeralSize * 0.32,
                  decoration: BoxDecoration(
                    color: _color(palette),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(height: numeralSize * 0.18),
                Text(
                  '$number',
                  style: AppTypography.monoStyle(
                    fontSize: numeralSize * 0.85,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _bold(
    AppPalette palette,
    double width,
    double height,
    double radius,
    double numeralSize,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.tileFace,
        borderRadius: BorderRadius.circular(radius + 2),
        border: selected ? Border.all(color: palette.accent, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? 0.2 : 0.1),
            blurRadius: selected ? 14 : 4,
            offset: Offset(0, selected ? 6 : 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: color == TileColor.joker
          ? _joker(numeralSize, _color(palette))
          : Text(
              '$number',
              style: AppTypography.serifStyle(
                fontSize: numeralSize * 1.35,
                color: _color(palette),
                fontStyle: FontStyle.italic,
              ),
            ),
    );
  }

  Widget _joker(double glyphSize, Color color) {
    return CustomPaint(
      size: Size.square(glyphSize),
      painter: JokerGlyph(color: color),
    );
  }
}

/// Paints the joker / okey mark: a four-spoke star with a center dot.
///
/// Ported from the SVG path in the design bundle's `tiles.jsx`.
class JokerGlyph extends CustomPainter {
  /// Creates a [JokerGlyph] in the given [color].
  const JokerGlyph({required this.color});

  /// The stroke and dot color.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // viewBox 0 0 24 24 scaled to size.
    Offset p(double x, double y) => Offset(x / 24 * w, y / 24 * size.height);

    canvas
      // M12 3v18
      ..drawLine(p(12, 3), p(12, 21), stroke)
      // M5 8l14 8
      ..drawLine(p(5, 8), p(19, 16), stroke)
      // M5 16l14-8
      ..drawLine(p(5, 16), p(19, 8), stroke)
      // M3 12h18
      ..drawLine(p(3, 12), p(21, 12), stroke)
      // center dot r=2
      ..drawCircle(
        p(12, 12),
        2 / 24 * w,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
  }

  @override
  bool shouldRepaint(JokerGlyph oldDelegate) => oldDelegate.color != color;
}
