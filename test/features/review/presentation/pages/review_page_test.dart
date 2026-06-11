import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/game/game_tile.dart';
import 'package:okey_acar_mi/core/game/indicator.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/tile.dart';
import 'package:okey_acar_mi/core/widgets/tile_slot.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/seeded_detections.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detected_tile.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_outcome.dart';
import 'package:okey_acar_mi/features/review/domain/entities/review_tile.dart';
import 'package:okey_acar_mi/features/review/presentation/blocs/review_bloc.dart';
import 'package:okey_acar_mi/features/review/presentation/pages/review_page.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/indicator_picker_sheet.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/review_rack.dart';
import 'package:okey_acar_mi/features/review/presentation/widgets/tile_edit_panel.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// The locale every assertion reads its strings from.
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

final DateTime _instant = DateTime.utc(2026, 6, 11, 9, 30);

/// Seed map of `SeededDetections.rack101()` (rack order, 21 tiles):
/// index 9 = yellow 5 @ 0.58 (low), index 11 = the joker candidate,
/// index 15 = blue 1 @ 0.62 (low).
const int _lowYellow5 = 9;
const int _jokerIndex = 11;
const int _lowBlue1 = 15;

DetectionResult _result(
  List<DetectedTile> tiles, {
  double overallConfidence = 0.9,
}) {
  return DetectionResult(
    tiles: tiles,
    overallConfidence: overallConfidence,
    sourceImagePath: 'fixture.jpg',
    frameCount: 1,
    detectedAt: _instant,
  );
}

/// The composed rack-cell semantics label, optionally with the
/// low-confidence suffix.
String _cellLabel(String base, int index, int count, {bool low = false}) {
  final label = _l10n.reviewTileSemantics(base, index, count);
  return low ? '$label, ${_l10n.reviewLowConfidenceLegend}' : label;
}

void main() {
  late GoRouter router;

  /// What the stub `/result` route received via `state.extra`.
  Object? resultExtra;

  setUp(() => resultExtra = null);

  /// `ReviewView` pushed over a base route (so the back pop is observable),
  /// with a stub `/result` route capturing the navigation extra.
  Widget harness(ReviewBloc bloc) {
    router = GoRouter(
      initialLocation: '/base',
      routes: [
        GoRoute(
          path: '/base',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('base-stub')),
          ),
        ),
        GoRoute(
          path: AppRoutes.review,
          builder: (context, state) => BlocProvider<ReviewBloc>.value(
            value: bloc,
            child: const ReviewView(),
          ),
        ),
        GoRoute(
          path: AppRoutes.result,
          builder: (context, state) {
            resultExtra = state.extra;
            return const Scaffold(body: Center(child: Text('result-stub')));
          },
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr'), Locale('en')],
      routerConfig: router,
    );
  }

  /// Builds the screen-scoped bloc, pushes the review route, and settles.
  Future<ReviewBloc> pumpReview(
    WidgetTester tester,
    DetectionResult result, {
    GameMode mode = GameMode.oneZeroOne,
  }) async {
    final bloc = ReviewBloc(result, mode);
    addTearDown(bloc.close);
    await tester.pumpWidget(harness(bloc));
    await tester.pump();
    unawaited(router.push(AppRoutes.review));
    await tester.pumpAndSettle();
    return bloc;
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  /// The tappable rack cells, in rack order (the only InkWells inside
  /// [ReviewRack]).
  Finder rackCells() => find.descendant(
    of: find.byType(ReviewRack),
    matching: find.byType(InkWell),
  );

  /// The rendered tiles inside the rack, in rack order.
  Finder rackTiles() => find.descendant(
    of: find.byType(ReviewRack),
    matching: find.byType(Tile),
  );

  Finder inPanel(Finder matching) =>
      find.descendant(of: find.byType(TileEditPanel), matching: matching);

  Future<void> tapCell(WidgetTester tester, int index) async {
    await tester.ensureVisible(rackCells().at(index));
    await tester.pumpAndSettle();
    await tester.tap(rackCells().at(index));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Opens the indicator sheet and confirms [colorName] + [number].
  Future<void> pickIndicator(
    WidgetTester tester, {
    required String colorName,
    required int number,
  }) async {
    final handle = tester.ensureSemantics();
    await tap(tester, key('review-pick-indicator'));
    check(find.byType(IndicatorPickerSheet).evaluate()).length.equals(1);
    await tap(
      tester,
      find.bySemanticsLabel(_l10n.indicatorColorSemantics(colorName)),
    );
    await tap(
      tester,
      find.bySemanticsLabel(_l10n.indicatorNumberSemantics(number)),
    );
    await tap(tester, key('indicator-confirm'));
    check(find.byType(IndicatorPickerSheet).evaluate()).isEmpty();
    handle.dispose();
  }

  PrimaryButton calculateButton(WidgetTester tester) =>
      tester.widget<PrimaryButton>(key('review-calculate'));

  group('rack rendering', () {
    testWidgets('renders all 21 seeded tiles with the count bar, the '
        'low-confidence legend, and no banners or panel', (tester) async {
      await pumpReview(tester, _result(SeededDetections.rack101()));

      check(rackTiles().evaluate()).length.equals(21);
      check(find.byType(TileSlot).evaluate()).isEmpty();
      check(
        find.text(_l10n.reviewCount(21, 20, 21)).evaluate(),
      ).length.equals(1);
      // Two seeded tiles read below the threshold → the legend is shown.
      check(
        find.text(_l10n.reviewLowConfidenceLegend).evaluate(),
      ).length.equals(1);
      check(key('review-retake').evaluate()).isEmpty();
      check(find.text(_l10n.reviewWrongCountFew(20)).evaluate()).isEmpty();
      check(find.byType(TileEditPanel).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('flags exactly the low-confidence tiles with the warn-dot '
        'semantics suffix', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpReview(tester, _result(SeededDetections.rack101()));

      check(
        find
            .bySemanticsLabel(
              _cellLabel(
                _l10n.tileSemantics(_l10n.tileColorYellow, 5),
                _lowYellow5 + 1,
                21,
                low: true,
              ),
            )
            .evaluate(),
      ).length.equals(1);
      check(
        find
            .bySemanticsLabel(
              _cellLabel(
                _l10n.tileSemantics(_l10n.tileColorBlue, 1),
                _lowBlue1 + 1,
                21,
                low: true,
              ),
            )
            .evaluate(),
      ).length.equals(1);
      // A confident tile carries no warn suffix.
      check(
        find
            .bySemanticsLabel(
              _cellLabel(_l10n.tileSemantics(_l10n.tileColorRed, 1), 1, 21),
            )
            .evaluate(),
      ).length.equals(1);
      handle.dispose();
    });
  });

  group('edit panel', () {
    testWidgets('tapping a tile opens its editor; picking a color and a '
        'number updates the tile and clears its warn dot', (tester) async {
      final bloc = await pumpReview(
        tester,
        _result(SeededDetections.rack101()),
      );

      await tapCell(tester, _lowYellow5);
      check(find.byType(TileEditPanel).evaluate()).length.equals(1);
      check(
        find.text(_l10n.reviewEditTileTitle(_lowYellow5 + 1)).evaluate(),
      ).length.equals(1);

      final handle = tester.ensureSemantics();
      await tap(tester, find.bySemanticsLabel(_l10n.tileColorBlack));
      handle.dispose();
      await tap(tester, inPanel(find.text('9')));

      check(bloc.state.tiles[_lowYellow5]).equals(
        const ReviewTile(color: TileColor.black, number: 9),
      );
      final tile = tester.widget<Tile>(rackTiles().at(_lowYellow5));
      check(tile.color).equals(TileColor.black);
      check(tile.number).equals(9);
      check(tester.takeException()).isNull();
    });

    testWidgets('fixing every flagged tile clears the legend', (tester) async {
      await pumpReview(tester, _result(SeededDetections.rack101()));

      await tapCell(tester, _lowYellow5);
      await tap(tester, inPanel(find.text('5')));
      // The blue 1 is still flagged → the legend stays.
      check(
        find.text(_l10n.reviewLowConfidenceLegend).evaluate(),
      ).length.equals(1);

      await tapCell(tester, _lowBlue1);
      await tap(tester, inPanel(find.text('1')));
      check(find.text(_l10n.reviewLowConfidenceLegend).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('the close button hides the panel', (tester) async {
      final bloc = await pumpReview(
        tester,
        _result(SeededDetections.rack101()),
      );

      await tapCell(tester, 0);
      check(find.byType(TileEditPanel).evaluate()).length.equals(1);

      await tap(tester, inPanel(find.byIcon(Icons.close)));
      check(find.byType(TileEditPanel).evaluate()).isEmpty();
      check(bloc.state.editingIndex).isNull();
      check(tester.takeException()).isNull();
    });

    testWidgets('picking the joker color hides the number grid and renders '
        'the joker tile', (tester) async {
      final bloc = await pumpReview(
        tester,
        _result(SeededDetections.rack101()),
      );

      await tapCell(tester, 0);
      check(
        inPanel(find.text(_l10n.reviewEditNumberLabel)).evaluate(),
      ).length.equals(1);

      final handle = tester.ensureSemantics();
      await tap(tester, find.bySemanticsLabel(_l10n.jokerSemantics));
      handle.dispose();

      check(
        inPanel(find.text(_l10n.reviewEditNumberLabel)).evaluate(),
      ).isEmpty();
      check(bloc.state.tiles[0]).equals(
        const ReviewTile(color: TileColor.joker),
      );
      final tile = tester.widget<Tile>(rackTiles().first);
      check(tile.color).equals(TileColor.joker);
      check(tile.number).isNull();
      check(tester.takeException()).isNull();
    });
  });

  group('add & remove', () {
    // The seeded 101 rack trimmed to the mode minimum (20), so adding is
    // legal.
    List<DetectedTile> twenty() => SeededDetections.rack101().sublist(0, 20);

    testWidgets('add appends a dashed slot with its editor open; remove '
        'deletes it again', (tester) async {
      final bloc = await pumpReview(tester, _result(twenty()));
      check(
        find.text(_l10n.reviewCount(20, 20, 21)).evaluate(),
      ).length.equals(1);

      await tap(tester, key('review-add-tile'));
      check(find.byType(TileSlot).evaluate()).length.equals(1);
      check(find.byType(TileEditPanel).evaluate()).length.equals(1);
      check(
        find.text(_l10n.reviewEditTileTitle(21)).evaluate(),
      ).length.equals(1);
      check(
        find.text(_l10n.reviewCount(21, 20, 21)).evaluate(),
      ).length.equals(1);

      await tap(tester, key('review-remove-tile'));
      check(find.byType(TileSlot).evaluate()).isEmpty();
      check(find.byType(TileEditPanel).evaluate()).isEmpty();
      check(bloc.state.tileCount).equals(20);
      check(tester.takeException()).isNull();
    });

    testWidgets('add is disabled at the mode maximum', (tester) async {
      await pumpReview(tester, _result(SeededDetections.rack101()));

      check(
        tester.widget<SecondaryButton>(key('review-add-tile')).onPressed,
      ).isNull();
    });

    testWidgets('remove is disabled at the mode minimum', (tester) async {
      await pumpReview(tester, _result(twenty()));

      await tapCell(tester, 0);
      check(
        tester.widget<GhostButton>(key('review-remove-tile')).onPressed,
      ).isNull();
    });
  });

  group('count banner', () {
    testWidgets('a wrong-count seed shows the too-few warning and blocks '
        'calculate on the count', (tester) async {
      await pumpReview(tester, _result(SeededDetections.rackWrongCount()));

      check(
        find.text(_l10n.reviewWrongCountFew(20)).evaluate(),
      ).length.equals(1);
      check(calculateButton(tester).onPressed).isNull();
      check(find.text(_l10n.reviewBlockerCount).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('the 21-tile rack in okey mode shows the too-many warning', (
      tester,
    ) async {
      await pumpReview(
        tester,
        _result(SeededDetections.rack101()),
        mode: GameMode.okey,
      );

      check(
        find.text(_l10n.reviewWrongCountMany(15)).evaluate(),
      ).length.equals(1);
      check(calculateButton(tester).onPressed).isNull();
      check(tester.takeException()).isNull();
    });

    testWidgets('a legal count shows no warning', (tester) async {
      await pumpReview(tester, _result(SeededDetections.rack101()));

      check(find.text(_l10n.reviewWrongCountFew(20)).evaluate()).isEmpty();
      check(find.text(_l10n.reviewWrongCountMany(21)).evaluate()).isEmpty();
    });
  });

  group('indicator & calculate', () {
    testWidgets('while unset: calculate is disabled with the indicator '
        'blocker line', (tester) async {
      await pumpReview(tester, _result(SeededDetections.rack101()));

      check(calculateButton(tester).onPressed).isNull();
      check(
        find.text(_l10n.reviewBlockerIndicator).evaluate(),
      ).length.equals(1);
      check(key('review-pick-indicator').evaluate()).length.equals(1);
    });

    testWidgets('picking yellow 13 wraps the okey to yellow 1, re-renders '
        'the false joker as the okey tile, and enables calculate', (
      tester,
    ) async {
      final bloc = await pumpReview(
        tester,
        _result(SeededDetections.rack101()),
      );

      await pickIndicator(tester, colorName: _l10n.tileColorYellow, number: 13);

      check(bloc.state.indicator).equals(
        const Indicator(color: TileColor.yellow, number: 13),
      );
      // The 13 → 1 wrap, surfaced in the okey label.
      check(
        find.text(_l10n.reviewOkeyLabel(_l10n.tileColorYellow, 1)).evaluate(),
      ).length.equals(1);
      // The false joker now displays as the okey tile (data stays joker).
      final jokerCell = tester.widget<Tile>(rackTiles().at(_jokerIndex));
      check(jokerCell.color).equals(TileColor.yellow);
      check(jokerCell.number).equals(1);
      check(bloc.state.tiles[_jokerIndex]).equals(
        const ReviewTile(color: TileColor.joker),
      );
      check(calculateButton(tester).onPressed).isNotNull();
      check(find.text(_l10n.reviewBlockerIndicator).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('calculate pushes /result with the confirmed outcome', (
      tester,
    ) async {
      await pumpReview(tester, _result(SeededDetections.rack101()));
      await pickIndicator(tester, colorName: _l10n.tileColorYellow, number: 13);

      await tap(tester, key('review-calculate'));

      check(find.text('result-stub').evaluate()).length.equals(1);
      check(resultExtra).isA<ReviewOutcome>()
        ..has((o) => o.gameMode, 'gameMode').equals(GameMode.oneZeroOne)
        ..has((o) => o.indicator, 'indicator').equals(
          const Indicator(color: TileColor.yellow, number: 13),
        )
        ..has((o) => o.okeyTile, 'okeyTile').equals(
          const GameTile(color: TileColor.yellow, number: 1),
        )
        ..has((o) => o.tiles.length, 'tiles.length').equals(21)
        ..has((o) => o.tiles[_jokerIndex], 'tiles[joker]').equals(
          const GameTile(color: TileColor.joker),
        );
      check(tester.takeException()).isNull();
    });
  });

  group('retake banner', () {
    testWidgets('a low overall confidence shows the banner; Retake pops back '
        'toward the camera', (tester) async {
      await pumpReview(
        tester,
        _result(SeededDetections.lowConfidenceRack(), overallConfidence: 0.62),
      );

      check(
        find.text(_l10n.reviewLowOverallBanner).evaluate(),
      ).length.equals(1);

      await tap(tester, key('review-retake'));
      check(find.text('base-stub').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });

  group('back', () {
    testWidgets('the top-bar back pops to the previous screen', (tester) async {
      await pumpReview(tester, _result(SeededDetections.rack101()));

      await tap(tester, key('review-back'));
      check(find.text('base-stub').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });

  group('ReviewPage wiring (demo DI)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    Widget pageHarness(DetectionResult result, GameMode mode) {
      final pageRouter = GoRouter(
        initialLocation: AppRoutes.review,
        routes: [
          GoRoute(
            path: AppRoutes.review,
            builder: (context, state) => ReviewPage(result: result),
          ),
        ],
      );
      return MaterialApp.router(
        theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('tr'), Locale('en')],
        routerConfig: pageRouter,
        builder: (context, child) => BlocProvider<SettingsCubit>(
          create: (_) => SettingsCubit()..setGameMode(mode),
          child: child,
        ),
      );
    }

    testWidgets('seeds its bloc with the 101 mode from SettingsCubit', (
      tester,
    ) async {
      await tester.pumpWidget(
        pageHarness(_result(SeededDetections.rack101()), GameMode.oneZeroOne),
      );
      await tester.pumpAndSettle();

      check(
        find.text(_l10n.reviewCount(21, 20, 21)).evaluate(),
      ).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('seeds its bloc with the okey mode from SettingsCubit', (
      tester,
    ) async {
      await tester.pumpWidget(
        pageHarness(_result(SeededDetections.rackOkey()), GameMode.okey),
      );
      await tester.pumpAndSettle();

      check(
        find.text(_l10n.reviewCount(14, 14, 15)).evaluate(),
      ).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });

  group('overflow guard', () {
    // Responsive size matrix from CLAUDE.md: smallest phone, typical phone,
    // largest phone, tablet — each at textScale 1.0 and 2.0, in both locales.
    const matrix = <Size>[
      Size(320, 568),
      Size(393, 852),
      Size(430, 932),
      Size(834, 1194),
    ];
    const textScales = <double>[1, 2];
    const locales = <Locale>[Locale('tr'), Locale('en')];

    // Worst-case screen contents: the edit panel open AND the indicator set
    // (okey card + false-joker note + footer CTA all visible), on the
    // smallest and largest legal racks plus the banner-heavy wrong-count +
    // low-confidence read.
    final scenarios = <String, (DetectionResult, GameMode)>{
      '21-tile 101 rack': (
        _result(SeededDetections.rack101()),
        GameMode.oneZeroOne,
      ),
      '14-tile okey rack': (
        _result(SeededDetections.rackOkey()),
        GameMode.okey,
      ),
      '19-tile wrong count + low confidence': (
        _result(SeededDetections.rackWrongCount(), overallConfidence: 0.6),
        GameMode.oneZeroOne,
      ),
    };

    Widget overflowHarness({
      required Size size,
      required double textScale,
      required Locale locale,
      required ReviewBloc bloc,
    }) {
      final guardRouter = GoRouter(
        initialLocation: AppRoutes.review,
        routes: [
          GoRoute(
            path: AppRoutes.review,
            builder: (context, state) => BlocProvider<ReviewBloc>.value(
              value: bloc,
              child: const ReviewView(),
            ),
          ),
        ],
      );
      return MaterialApp.router(
        theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('tr'), Locale('en')],
        routerConfig: guardRouter,
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
      );
    }

    for (final MapEntry(key: name, value: (result, mode))
        in scenarios.entries) {
      for (final locale in locales) {
        for (final size in matrix) {
          for (final textScale in textScales) {
            testWidgets(
              'ReviewView ($name) no overflow '
              '@ ${locale.languageCode} $size x$textScale',
              (tester) async {
                tester.view.physicalSize = size;
                tester.view.devicePixelRatio = 1.0;
                addTearDown(tester.view.resetPhysicalSize);
                addTearDown(tester.view.resetDevicePixelRatio);

                final bloc = ReviewBloc(result, mode)
                  // Worst case: indicator set + the edit panel open.
                  ..add(
                    const ReviewEvent.indicatorPicked(TileColor.yellow, 13),
                  )
                  ..add(const ReviewEvent.tileTapped(0));
                addTearDown(bloc.close);

                await tester.pumpWidget(
                  overflowHarness(
                    size: size,
                    textScale: textScale,
                    locale: locale,
                    bloc: bloc,
                  ),
                );
                await tester.pumpAndSettle();

                check(tester.takeException()).isNull();
              },
            );
          }
        }
      }
    }
  });
}
