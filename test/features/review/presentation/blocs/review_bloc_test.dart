import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/game/game_mode.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/game/tile_color.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_tile.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';

const List<TileColor> _colors = [
  TileColor.red,
  TileColor.black,
  TileColor.yellow,
  TileColor.blue,
];

/// [count] numbered tiles (colors and numerals cycling), optionally replacing
/// the last one with a joker candidate.
List<DetectedTile> _tiles(
  int count, {
  double confidence = 0.9,
  bool lastIsJoker = false,
}) {
  return [
    for (var i = 0; i < count; i++)
      if (lastIsJoker && i == count - 1)
        DetectedTile(
          color: TileColor.joker,
          position: TilePosition(row: 1, index: i),
          confidence: confidence,
        )
      else
        DetectedTile(
          color: _colors[i % 4],
          number: i % 13 + 1,
          position: TilePosition(row: i < (count / 2).ceil() ? 0 : 1, index: i),
          confidence: confidence,
        ),
  ];
}

DetectionResult _result(
  List<DetectedTile> tiles, {
  double overallConfidence = 0.9,
}) {
  return DetectionResult(
    tiles: tiles,
    overallConfidence: overallConfidence,
    sourceImagePath: 'fixture.jpg',
    frameCount: 1,
    detectedAt: DateTime(2026, 6, 11),
  );
}

ReviewBloc _bloc(
  List<DetectedTile> tiles, {
  GameMode mode = GameMode.oneZeroOne,
  double overallConfidence = 0.9,
}) {
  return ReviewBloc(
    _result(tiles, overallConfidence: overallConfidence),
    mode,
  );
}

Matcher _editing(int? index) =>
    isA<ReviewState>().having((s) => s.editingIndex, 'editingIndex', index);

void main() {
  group('1. seeding', () {
    test('preserves order, flags < 0.75 only, maps jokers', () {
      final bloc = _bloc(const [
        DetectedTile(
          color: TileColor.red,
          number: 7,
          position: TilePosition(row: 0, index: 0),
          confidence: 0.9,
        ),
        DetectedTile(
          color: TileColor.black,
          number: 3,
          position: TilePosition(row: 0, index: 1),
          confidence: 0.5,
        ),
        DetectedTile(
          color: TileColor.blue,
          number: 11,
          position: TilePosition(row: 0, index: 2),
          confidence: 0.75,
        ),
        DetectedTile(
          color: TileColor.joker,
          position: TilePosition(row: 0, index: 3),
          confidence: 0.9,
        ),
      ]);
      addTearDown(bloc.close);

      check(bloc.state.tiles).deepEquals(const [
        ReviewTile(color: TileColor.red, number: 7),
        ReviewTile(color: TileColor.black, number: 3, lowConfidence: true),
        ReviewTile(color: TileColor.blue, number: 11),
        ReviewTile(color: TileColor.joker),
      ]);
      check(bloc.state.editingIndex).isNull();
      check(bloc.state.indicator).isNull();
    });
  });

  group('2. tileTapped', () {
    blocTest<ReviewBloc, ReviewState>(
      'opens, toggles closed, and switches between tiles',
      build: () => _bloc(_tiles(20)),
      act: (bloc) => bloc
        ..add(const ReviewEvent.tileTapped(3))
        ..add(const ReviewEvent.tileTapped(3))
        ..add(const ReviewEvent.tileTapped(3))
        ..add(const ReviewEvent.tileTapped(5)),
      expect: () => [_editing(3), _editing(null), _editing(3), _editing(5)],
    );

    blocTest<ReviewBloc, ReviewState>(
      'ignores out-of-range indices',
      build: () => _bloc(_tiles(20)),
      act: (bloc) => bloc
        ..add(const ReviewEvent.tileTapped(-1))
        ..add(const ReviewEvent.tileTapped(20)),
      expect: () => const <ReviewState>[],
    );
  });

  group('3. tileNumberChanged', () {
    blocTest<ReviewBloc, ReviewState>(
      'updates the numeral AND clears the low-confidence flag',
      build: () => _bloc(_tiles(20, confidence: 0.4)),
      act: (bloc) => bloc
        ..add(const ReviewEvent.tileTapped(0))
        ..add(const ReviewEvent.tileNumberChanged(9)),
      verify: (bloc) {
        check(bloc.state.tiles[0]).equals(
          const ReviewTile(color: TileColor.red, number: 9),
        );
        check(bloc.state.tiles[1].lowConfidence).isTrue();
      },
    );

    blocTest<ReviewBloc, ReviewState>(
      'is a no-op while nothing is being edited',
      build: () => _bloc(_tiles(20)),
      act: (bloc) => bloc.add(const ReviewEvent.tileNumberChanged(9)),
      expect: () => const <ReviewState>[],
    );
  });

  group('4. tileColorChanged to joker', () {
    blocTest<ReviewBloc, ReviewState>(
      'clears the numeral and the flag (D6)',
      build: () => _bloc(_tiles(20, confidence: 0.4)),
      act: (bloc) => bloc
        ..add(const ReviewEvent.tileTapped(0))
        ..add(const ReviewEvent.tileColorChanged(TileColor.joker)),
      verify: (bloc) {
        check(bloc.state.tiles[0]).equals(
          const ReviewTile(color: TileColor.joker),
        );
        check(bloc.state.tiles[0].isComplete).isTrue();
      },
    );
  });

  group('5. tileColorChanged joker to real color', () {
    blocTest<ReviewBloc, ReviewState>(
      'keeps the null numeral, blocking canSolve despite indicator + count',
      build: () => _bloc(_tiles(20, lastIsJoker: true)),
      act: (bloc) => bloc
        ..add(const ReviewEvent.indicatorPicked(TileColor.blue, 5))
        ..add(const ReviewEvent.tileTapped(19))
        ..add(const ReviewEvent.tileColorChanged(TileColor.red)),
      verify: (bloc) {
        final tile = bloc.state.tiles[19];
        check(tile.color).equals(TileColor.red);
        check(tile.number).isNull();
        check(tile.isComplete).isFalse();
        check(bloc.state.indicator).isNotNull();
        check(bloc.state.countValid).isTrue();
        check(bloc.state.allTilesComplete).isFalse();
        check(bloc.state.canSolve).isFalse();
      },
    );
  });

  group('6. tileAdded', () {
    blocTest<ReviewBloc, ReviewState>(
      'is a no-op at the 101 maximum (21)',
      build: () => _bloc(_tiles(21)),
      act: (bloc) => bloc.add(const ReviewEvent.tileAdded()),
      expect: () => const <ReviewState>[],
    );

    blocTest<ReviewBloc, ReviewState>(
      'below max: appends an undefined placeholder and opens its editor (D3)',
      build: () => _bloc(_tiles(20)),
      act: (bloc) => bloc
        ..add(const ReviewEvent.indicatorPicked(TileColor.red, 1))
        ..add(const ReviewEvent.tileAdded()),
      verify: (bloc) {
        check(bloc.state.tileCount).equals(21);
        check(bloc.state.tiles.last).equals(const ReviewTile());
        check(bloc.state.editingIndex).equals(20);
        check(bloc.state.countValid).isTrue();
        check(bloc.state.canSolve).isFalse();
      },
    );
  });

  group('7. tileRemoved', () {
    blocTest<ReviewBloc, ReviewState>(
      'is a no-op at the 101 minimum (20)',
      build: () => _bloc(_tiles(20)),
      act: (bloc) => bloc
        ..add(const ReviewEvent.tileTapped(0))
        ..add(const ReviewEvent.tileRemoved()),
      expect: () => [_editing(0)],
    );

    blocTest<ReviewBloc, ReviewState>(
      'above min: removes the edited tile and closes the editor',
      build: () => _bloc(_tiles(21)),
      act: (bloc) => bloc
        ..add(const ReviewEvent.tileTapped(0))
        ..add(const ReviewEvent.tileRemoved()),
      verify: (bloc) {
        check(bloc.state.tileCount).equals(20);
        check(bloc.state.editingIndex).isNull();
        // _tiles(21)[1] is black 2 — it shifted into slot 0.
        check(bloc.state.tiles[0]).equals(
          const ReviewTile(color: TileColor.black, number: 2),
        );
      },
    );

    blocTest<ReviewBloc, ReviewState>(
      'is a no-op while nothing is being edited',
      build: () => _bloc(_tiles(21)),
      act: (bloc) => bloc.add(const ReviewEvent.tileRemoved()),
      expect: () => const <ReviewState>[],
    );
  });

  group('8. indicatorPicked', () {
    blocTest<ReviewBloc, ReviewState>(
      'blue 3 derives okey blue 4',
      build: () => _bloc(_tiles(20)),
      act: (bloc) =>
          bloc.add(const ReviewEvent.indicatorPicked(TileColor.blue, 3)),
      verify: (bloc) {
        check(bloc.state.indicator).equals(
          const Indicator(color: TileColor.blue, number: 3),
        );
        check(bloc.state.okeyTile).equals(
          const GameTile(color: TileColor.blue, number: 4),
        );
      },
    );

    blocTest<ReviewBloc, ReviewState>(
      'yellow 13 wraps to okey yellow 1',
      build: () => _bloc(_tiles(20)),
      act: (bloc) =>
          bloc.add(const ReviewEvent.indicatorPicked(TileColor.yellow, 13)),
      verify: (bloc) {
        check(bloc.state.okeyTile).equals(
          const GameTile(color: TileColor.yellow, number: 1),
        );
      },
    );

    blocTest<ReviewBloc, ReviewState>(
      'rejects the joker color and out-of-range numbers (D5)',
      build: () => _bloc(_tiles(20)),
      act: (bloc) => bloc
        ..add(const ReviewEvent.indicatorPicked(TileColor.joker, 3))
        ..add(const ReviewEvent.indicatorPicked(TileColor.red, 0))
        ..add(const ReviewEvent.indicatorPicked(TileColor.red, 14)),
      expect: () => const <ReviewState>[],
    );
  });

  group('9. canSolve + outcome()', () {
    test('canSolve requires indicator + valid count + complete tiles', () {
      final bloc = _bloc(_tiles(20, lastIsJoker: true));
      addTearDown(bloc.close);

      // Valid count, complete tiles — but no indicator yet.
      check(bloc.state.countValid).isTrue();
      check(bloc.state.allTilesComplete).isTrue();
      check(bloc.state.canSolve).isFalse();
    });

    test('wrong count blocks canSolve even with an indicator', () async {
      final bloc = _bloc(_tiles(19))
        ..add(const ReviewEvent.indicatorPicked(TileColor.red, 1));
      addTearDown(bloc.close);
      await Future<void>.delayed(Duration.zero);

      check(bloc.state.indicator).isNotNull();
      check(bloc.state.countValid).isFalse();
      check(bloc.state.canSolve).isFalse();
    });

    blocTest<ReviewBloc, ReviewState>(
      'outcome() carries tiles in order, jokers as GameTile(joker, null)',
      build: () => _bloc(_tiles(20, lastIsJoker: true)),
      act: (bloc) =>
          bloc.add(const ReviewEvent.indicatorPicked(TileColor.black, 12)),
      verify: (bloc) {
        check(bloc.state.canSolve).isTrue();
        final outcome = bloc.state.outcome();
        check(outcome.gameMode).equals(GameMode.oneZeroOne);
        check(outcome.indicator).equals(
          const Indicator(color: TileColor.black, number: 12),
        );
        check(outcome.okeyTile).equals(
          const GameTile(color: TileColor.black, number: 13),
        );
        check(outcome.tiles.length).equals(20);
        check(outcome.tiles.first).equals(
          const GameTile(color: TileColor.red, number: 1),
        );
        check(outcome.tiles.last).equals(
          const GameTile(color: TileColor.joker),
        );
        check(outcome.tiles.last.isJoker).isTrue();
      },
    );

    test('low confidence never blocks solving (D2)', () async {
      final bloc = _bloc(
        _tiles(20, confidence: 0.3),
        overallConfidence: 0.3,
      )..add(const ReviewEvent.indicatorPicked(TileColor.red, 1));
      addTearDown(bloc.close);
      await Future<void>.delayed(Duration.zero);

      check(bloc.state.lowOverallConfidence).isTrue();
      check(bloc.state.tiles.first.lowConfidence).isTrue();
      check(bloc.state.canSolve).isTrue();
    });
  });

  group('10. GameMode.okey limits (14-15)', () {
    blocTest<ReviewBloc, ReviewState>(
      'tileAdded is a no-op at 15',
      build: () => _bloc(_tiles(15), mode: GameMode.okey),
      act: (bloc) => bloc.add(const ReviewEvent.tileAdded()),
      expect: () => const <ReviewState>[],
    );

    blocTest<ReviewBloc, ReviewState>(
      'tileRemoved is a no-op at 14',
      build: () => _bloc(_tiles(14), mode: GameMode.okey),
      act: (bloc) => bloc
        ..add(const ReviewEvent.tileTapped(0))
        ..add(const ReviewEvent.tileRemoved()),
      expect: () => [_editing(0)],
    );

    test('counts 14 and 15 are valid; 16 and 13 are not', () {
      final at14 = _bloc(_tiles(14), mode: GameMode.okey);
      final at15 = _bloc(_tiles(15), mode: GameMode.okey);
      final at16 = _bloc(_tiles(16), mode: GameMode.okey);
      final at13 = _bloc(_tiles(13), mode: GameMode.okey);
      addTearDown(at14.close);
      addTearDown(at15.close);
      addTearDown(at16.close);
      addTearDown(at13.close);

      check(at14.state.countValid).isTrue();
      check(at14.state.canRemove).isFalse();
      check(at14.state.canAdd).isTrue();
      check(at15.state.countValid).isTrue();
      check(at15.state.canAdd).isFalse();
      check(at16.state.countValid).isFalse();
      check(at13.state.countValid).isFalse();
    });
  });
}
