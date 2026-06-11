import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/rack.dart';
import 'package:okey_acar_mi/features/capture/domain/entities/capture_payload.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/seeded_detections.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_result.dart';
import 'package:okey_acar_mi/features/detection/domain/entities/detection_stage.dart';
import 'package:okey_acar_mi/features/detection/presentation/blocs/detection_bloc.dart';
import 'package:okey_acar_mi/features/detection/presentation/pages/analyzing_page.dart';
import 'package:okey_acar_mi/features/detection/presentation/widgets/scan_line.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

class _MockDetectionBloc extends MockBloc<DetectionEvent, DetectionState>
    implements DetectionBloc {}

/// The locale every assertion reads its strings from.
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

final DateTime _instant = DateTime.utc(2026, 6, 11, 9, 30);

final CapturePayload _payload = CapturePayload.still(
  imagePath: '/captures/rack_101_21.png',
  source: CaptureSource.photo,
  capturedAt: _instant,
);

final DetectionResult _result = DetectionResult(
  tiles: SeededDetections.rack101(),
  overallConfidence: 0.88,
  sourceImagePath: '/captures/rack_101_21.png',
  frameCount: 1,
  detectedAt: _instant,
);

/// A mid-run processing state: 7 of 21 tiles revealed while reading.
final DetectionState _midProcessing = DetectionState.processing(
  stage: DetectionStage.readingTiles,
  revealed: SeededDetections.rack101().take(7).toList(),
  totalTiles: 21,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const DetectionEvent.started());
  });

  late _MockDetectionBloc bloc;
  late GoRouter router;

  /// What the review route received via `state.extra`.
  Object? reviewExtra;

  setUp(() {
    bloc = _MockDetectionBloc();
    reviewExtra = null;
  });

  void stubState(
    DetectionState state, {
    List<DetectionState> emitAfter = const [],
  }) {
    whenListen(bloc, Stream.fromIterable(emitAfter), initialState: state);
  }

  /// `AnalyzingView` pushed on top of a base route (so `canPop` is true and
  /// pop escapes are observable), with a stub review route capturing `extra`.
  Widget harness({bool reduceMotion = false}) {
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
          path: AppRoutes.analyzing,
          builder: (context, state) {
            final view = BlocProvider<DetectionBloc>.value(
              value: bloc,
              child: AnalyzingView(payload: _payload),
            );
            if (!reduceMotion) return view;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: view,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.review,
          builder: (context, state) {
            reviewExtra = state.extra;
            return const Scaffold(body: Center(child: Text('review-stub')));
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

  /// Pumps the harness and pushes the analyzing route. Discrete pumps — not
  /// `pumpAndSettle` — because the processing state's scan line animates
  /// forever.
  Future<void> pumpAnalyzing(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(harness(reduceMotion: reduceMotion));
    await tester.pump();
    unawaited(router.push(AppRoutes.analyzing));
    await tester.pump();
    // The push transition is time-bounded; drive it to completion.
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  group('processing', () {
    testWidgets('renders the stage label, the tile counter, and the '
        'revealed rack', (tester) async {
      stubState(_midProcessing);
      await pumpAnalyzing(tester);

      check(
        find.text(_l10n.analyzingStageReadingTiles).evaluate(),
      ).length.equals(1);
      check(
        find.text(_l10n.analyzingTileProgress(7, 21)).evaluate(),
      ).length.equals(1);
      check(tester.widget<Rack>(find.byType(Rack)).tiles.length).equals(7);
      check(find.byType(ScanLine).evaluate()).length.equals(1);
      check(key('analyzing-cancel').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('the scan line sweeps while processing', (tester) async {
      stubState(_midProcessing);
      await pumpAnalyzing(tester);

      Alignment alignmentNow() =>
          tester
                  .widget<Align>(
                    find.descendant(
                      of: find.byType(ScanLine),
                      matching: find.byType(Align),
                    ),
                  )
                  .alignment
              as Alignment;

      check(tester.hasRunningAnimations).isTrue();
      final before = alignmentNow();
      await tester.pump(const Duration(milliseconds: 450));
      check(
        because: 'the sweep must move between frames',
        alignmentNow(),
      ).not((a) => a.equals(before));
    });

    testWidgets('reduce-motion pins the scan line static at mid-height', (
      tester,
    ) async {
      stubState(_midProcessing);
      await pumpAnalyzing(tester, reduceMotion: true);

      final align = tester.widget<Align>(
        find.descendant(
          of: find.byType(ScanLine),
          matching: find.byType(Align),
        ),
      );
      // Controller pinned at 0.5 → Alignment(0, -0.7 + 1.4 * 0.5) = center.
      check(align.alignment).equals(Alignment.center);
      check(tester.hasRunningAnimations).isFalse();

      // And it stays put.
      await tester.pump(const Duration(milliseconds: 450));
      final after = tester.widget<Align>(
        find.descendant(
          of: find.byType(ScanLine),
          matching: find.byType(Align),
        ),
      );
      check(after.alignment).equals(Alignment.center);
      check(tester.takeException()).isNull();
    });

    testWidgets('the cancel button pops back off the analyzing screen', (
      tester,
    ) async {
      stubState(_midProcessing);
      await pumpAnalyzing(tester);

      await tester.tap(key('analyzing-cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      check(find.text('base-stub').evaluate()).length.equals(1);
      check(
        find.byType(AnalyzingView, skipOffstage: false).evaluate(),
      ).isEmpty();
      check(tester.takeException()).isNull();
    });
  });

  group('failure: no tiles', () {
    setUp(
      () => stubState(
        const DetectionState.failure(failure: Failure.noTilesDetected()),
      ),
    );

    testWidgets('renders the tips plus Retake (primary) and Try again '
        '(secondary) — never a dead-end', (tester) async {
      await pumpAnalyzing(tester);

      check(
        find.text(_l10n.analyzingNoTilesTitle).evaluate(),
      ).length.equals(1);
      check(
        find.text(_l10n.analyzingNoTilesBody).evaluate(),
      ).length.equals(1);
      check(key('analyzing-retake').evaluate()).length.equals(1);
      check(key('analyzing-retry').evaluate()).length.equals(1);
      check(key('analyzing-back').evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('Try again dispatches retryRequested', (tester) async {
      await pumpAnalyzing(tester);

      await tester.tap(key('analyzing-retry'));

      verify(
        () => bloc.add(const DetectionEvent.retryRequested()),
      ).called(1);
    });

    testWidgets('Retake pops back toward the camera', (tester) async {
      await pumpAnalyzing(tester);

      await tester.tap(key('analyzing-retake'));
      await tester.pumpAndSettle();

      check(find.text('base-stub').evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });
  });

  group('failure: pipeline error', () {
    setUp(
      () => stubState(
        const DetectionState.failure(
          failure: Failure.detectionFailed('boom'),
        ),
      ),
    );

    testWidgets('renders the error copy plus Try again (primary) and Back '
        '(secondary)', (tester) async {
      await pumpAnalyzing(tester);

      check(
        find.text(_l10n.analyzingErrorTitle).evaluate(),
      ).length.equals(1);
      check(find.text(_l10n.analyzingErrorBody).evaluate()).length.equals(1);
      check(key('analyzing-retry').evaluate()).length.equals(1);
      check(key('analyzing-back').evaluate()).length.equals(1);
      check(key('analyzing-retake').evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('Try again dispatches retryRequested', (tester) async {
      await pumpAnalyzing(tester);

      await tester.tap(key('analyzing-retry'));

      verify(
        () => bloc.add(const DetectionEvent.retryRequested()),
      ).called(1);
    });
  });

  group('success hand-off', () {
    testWidgets('pushes review with the result as extra, keeping the '
        'analyzing page alive beneath it', (tester) async {
      stubState(
        DetectionState.processing(
          stage: DetectionStage.finalizing,
          revealed: SeededDetections.rack101(),
          totalTiles: 21,
        ),
        emitAfter: [DetectionState.success(result: _result)],
      );
      await pumpAnalyzing(tester);
      await tester.pumpAndSettle();

      check(find.text('review-stub').evaluate()).length.equals(1);
      check(reviewExtra).equals(_result);
      // The push/auto-pop contract: analyzing stays beneath review so the
      // camera's push-future remains pending until review pops.
      check(
        find.byType(AnalyzingView, skipOffstage: false).evaluate(),
      ).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('popping review auto-pops the analyzing page too', (
      tester,
    ) async {
      stubState(
        DetectionState.processing(
          stage: DetectionStage.finalizing,
          revealed: SeededDetections.rack101(),
          totalTiles: 21,
        ),
        emitAfter: [DetectionState.success(result: _result)],
      );
      await pumpAnalyzing(tester);
      await tester.pumpAndSettle();
      check(find.text('review-stub').evaluate()).length.equals(1);

      router.pop();
      await tester.pumpAndSettle();

      check(find.text('base-stub').evaluate()).length.equals(1);
      check(
        find.byType(AnalyzingView, skipOffstage: false).evaluate(),
      ).isEmpty();
      check(tester.takeException()).isNull();
    });
  });
}
