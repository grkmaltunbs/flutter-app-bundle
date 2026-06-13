import 'package:firebase_ai/firebase_ai.dart';

/// The structured-output schema and system instruction for the rack-reading
/// request. Isolated here so the prompt/schema can be tuned without touching
/// the client or detector.
abstract final class GeminiRackSchema {
  const GeminiRackSchema._();

  /// The JSON shape Gemini must return: rows (top first) of tiles, each tile a
  /// `kind` plus, for numbered tiles, a `color` + `number`.
  static final Schema schema = Schema.object(
    description: 'Every tile physically present on the Okey rack.',
    properties: {
      'rows': Schema.array(
        description:
            'Rack rows: index 0 is the TOP row, index 1 the BOTTOM row. '
            'Each row lists its tiles left-to-right.',
        items: Schema.array(
          description: 'One rack row, left to right.',
          items: Schema.object(
            properties: {
              'kind': Schema.enumString(
                enumValues: ['numbered', 'false_joker', 'face_down'],
                description:
                    'numbered = a normal tile showing a number; '
                    'false_joker = the fake okey / joker tile; '
                    'face_down = a tile flipped to its blank back '
                    '(the okey, by tradition).',
              ),
              'color': Schema.enumString(
                enumValues: ['red', 'black', 'yellow', 'blue'],
                description:
                    'Ink color of the printed number. Required for '
                    '"numbered" tiles only; omit otherwise.',
              ),
              'number': Schema.integer(
                description:
                    'Tile number 1–13. Required for "numbered" only; omit '
                    'otherwise.',
                minimum: 1,
                maximum: 13,
              ),
              'confidence': Schema.number(
                description: 'Reading confidence, 0–1.',
                minimum: 0,
                maximum: 1,
              ),
            },
            optionalProperties: ['color', 'number', 'confidence'],
          ),
        ),
      ),
    },
  );

  /// The system instruction that teaches Gemini the Okey domain.
  static const String prompt = '''
You are an expert at reading the tiles of the Turkish tile games "101 Okey" and "Okey".

You are given ONE photo of a player's rack — the wooden holder called an "istaka". The rack holds up to two horizontal rows of tiles, usually standing upright and side by side. Read EVERY tile on the rack and return it in the required JSON.

TILE COLORS — every numbered tile shows its number printed in exactly one of four ink colors:
- "red"
- "black" (a near-black dark ink — do NOT confuse it with dark "blue")
- "yellow" (can look orange or amber)
- "blue" (a clear medium blue — distinct from near-black "black")
Judge color by the printed number's ink, not the tile body (tiles are cream/ivory).

TILE NUMBERS: an integer 1 to 13.

THREE KINDS of tile (the "kind" field):
- "numbered": a normal tile showing a number 1–13 in one of the four colors. Provide BOTH "color" and "number".
- "false_joker": the special joker tile ("sahte okey" / fake okey). It usually shows a joker mark, star, or face and NO 1–13 number. Do NOT provide "color" or "number".
- "face_down": a tile flipped face-down so only its blank wooden back shows (no number, no color). By tradition this marks the okey (the wild). Do NOT provide "color" or "number".

TILE ORIENTATION: most tiles stand upright, but some players habitually lay one or more tiles SIDEWAYS — rotated about 90°, lying on their side. A sideways tile is still a normal tile: mentally rotate it, read its number and color the same way, and report it as "numbered" in its left-to-right rack position. A sideways tile is NOT "face_down" — face_down means the blank wooden back is showing with no number at all.

OUTPUT RULES:
- Group tiles by physical row: the FIRST array in "rows" is the TOP row, the SECOND is the BOTTOM row. Return a single row if the rack has only one.
- Within each row list tiles strictly LEFT to RIGHT, in physical order.
- Report ONLY tiles actually present. NEVER invent tiles to reach a count. An empty rack is allowed (empty rows).
- Give every tile a "confidence" 0–1. If a tile is blurry, glare-covered, or ambiguous, give your best guess and LOWER its confidence.
- Watch the common confusions: 6 vs 9 (account for rotation — a sideways tile is turned ~90°, so rely on the digit's shape, not just which way is "up"), 1 vs 7, 6 vs 8, and black vs dark blue ink.
''';
}
