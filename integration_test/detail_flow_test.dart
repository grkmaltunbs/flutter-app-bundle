import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/ads/ads_service.dart';
import 'package:okey_acar_mi/core/ads/fakes/fake_ads_service.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/payments/data/fakes/fake_purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/domain/repositories/purchase_repository.dart';
import 'package:okey_acar_mi/features/capture/data/fakes/fake_capture_service.dart';
import 'package:okey_acar_mi/features/capture/presentation/pages/camera_page.dart';
import 'package:okey_acar_mi/features/detection/data/fakes/fake_tile_detector.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';
import 'package:okey_acar_mi/features/result/presentation/pages/result_page.dart';
import 'package:okey_acar_mi/features/review/presentation/pages/review_page.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

FakeCaptureService fakeCapture() => getIt<FakeCaptureService>();
FakeTileDetector fakeDetector() => getIt<FakeTileDetector>();
FakeAdsService fakeAds() => getIt<AdsService>() as FakeAdsService;
FakePurchaseRepository fakePurchases() =>
    getIt<PurchaseRepository>() as FakePurchaseRepository;

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

AppLocalizations resultL10n(WidgetTester tester) =>
    tester.element(find.byType(ResultView)).l10n;

/// Splash → guest → capture the seeded rack → review → indicator → result.
Future<void> goToResult(WidgetTester tester) async {
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
  await tapKey(tester, 'splash-guest');
  check(find.byType(HomePage).evaluate()).length.equals(1);

  final cta = find.byIcon(Icons.photo_camera_outlined);
  await tester.ensureVisible(cta);
  await tester.pumpAndSettle();
  await tester.tap(cta);
  await tester.pumpAndSettle();
  check(find.byType(CameraView).evaluate()).length.equals(1);

  await tapKey(tester, 'camera-shutter');
  check(find.byType(ReviewPage).evaluate()).length.equals(1);

  // Indicator yellow 13 → calculate.
  await tapKey(tester, 'review-pick-indicator');
  final sheet = find.byKey(const ValueKey('indicator-sheet'));
  await tester.tap(
    find.descendant(of: sheet, matching: find.byType(InkWell)).at(2),
  );
  await tester.pumpAndSettle();
  final numberChip = find.descendant(of: sheet, matching: find.text('13'));
  await tester.ensureVisible(numberChip);
  await tester.pumpAndSettle();
  await tester.tap(numberChip);
  await tester.pumpAndSettle();
  await tapKey(tester, 'indicator-confirm');
  await tapKey(tester, 'review-calculate');
  check(find.byType(ResultView).evaluate()).length.equals(1);
}

/// End-to-end "NEDEN BÖYLE?" detail-unlock flow on the demo flavor. Run with:
///
/// ```bash
/// flutter test integration_test/detail_flow_test.dart \
///   --dart-define=APP_ENV=demo -d <device>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Detail-unlock flow end-to-end (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async {
      fakeCapture().reset();
      fakeDetector().reset();
      fakeAds().reset();
      fakePurchases().reset();
      await getIt.reset();
    });

    testWidgets('free: open detail → watch rewarded ad (grants) → reasoning '
        'revealed', (tester) async {
      await goToResult(tester);
      final l10n = resultL10n(tester);

      // Locked for a free user.
      check(find.text(l10n.resultWhyThis).evaluate()).isEmpty();
      check(
        find.byKey(const ValueKey('result-detail-unlock')).evaluate(),
      ).length.equals(1);

      // Unlock CTA → sheet → watch ad → reward granted → reasoning revealed.
      await tapKey(tester, 'result-detail-unlock');
      await tapKey(tester, 'detail-unlock-watch-ad');
      await pumpUntilFound(tester, find.text(l10n.resultWhyThis));
      check(find.text(l10n.resultWhyThis).evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('result-detail-unlock')).evaluate(),
      ).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('free: an ad that fails to load keeps the reasoning locked', (
      tester,
    ) async {
      fakeAds().failNextRewarded = true;
      await goToResult(tester);
      final l10n = resultL10n(tester);

      await tapKey(tester, 'result-detail-unlock');
      await tapKey(tester, 'detail-unlock-watch-ad');
      await tester.pumpAndSettle();

      // Still locked; the failure SnackBar surfaced.
      check(find.text(l10n.resultWhyThis).evaluate()).isEmpty();
      check(
        find.byKey(const ValueKey('result-detail-unlock')).evaluate(),
      ).length.equals(1);
      check(find.text(l10n.detailUnlockAdFailed).evaluate()).length.equals(1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      check(tester.takeException()).isNull();
    });

    testWidgets('premium: reasoning is shown immediately, no unlock CTA', (
      tester,
    ) async {
      fakePurchases().setMode(FakePurchaseMode.premium);
      await goToResult(tester);
      final l10n = resultL10n(tester);

      check(find.text(l10n.resultWhyThis).evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('result-detail-unlock')).evaluate(),
      ).isEmpty();
      check(tester.takeException()).isNull();
    });
  });
}
