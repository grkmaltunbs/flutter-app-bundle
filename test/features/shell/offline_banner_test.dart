import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/network/connectivity_service.dart';
import 'package:okey_acar_mi/core/widgets/offline_banner.dart';
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/home/presentation/pages/home_page.dart';

/// The shell-level offline banner, driven through the real [App] against the
/// demo fakes: appearance/clearing on connectivity changes, stacking under
/// the session-expired banner (single top-inset owner), and the resume-time
/// re-probe of a transport change the stream never delivered.
void main() {
  group('Shell offline banner (demo flavor)', () {
    setUp(() async => configureDependencies('demo'));
    tearDown(() async => getIt.reset());

    FakeConnectivityService fakeConnectivity() =>
        getIt<ConnectivityService>() as FakeConnectivityService;
    FakeAuthRepository fakeAuth() =>
        getIt<AuthRepository>() as FakeAuthRepository;

    final banner = find.byKey(const ValueKey('offline-banner'));
    final sessionBanner = find.byKey(const ValueKey('session-expired-banner'));

    Future<void> goHomeAsGuest(WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('splash-guest')));
      await tester.pumpAndSettle();
      check(find.byType(HomePage).evaluate()).length.equals(1);
    }

    bool bannerOwnsInset(WidgetTester tester) =>
        tester.widget<OfflineBanner>(find.byType(OfflineBanner)).applyTopInset;

    /// Walks the real lifecycle stepwise down to paused and back to resumed
    /// (never pumping while paused), then settles the resume-triggered work.
    Future<void> backgroundAndResume(WidgetTester tester) async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('appears when connectivity drops and clears when restored', (
      tester,
    ) async {
      await goHomeAsGuest(tester);
      check(banner.evaluate()).isEmpty();

      fakeConnectivity().setOnline(online: false);
      await tester.pumpAndSettle();
      check(banner.evaluate()).length.equals(1);
      // Alone, the offline banner owns the status-bar inset.
      check(bannerOwnsInset(tester)).isTrue();

      fakeConnectivity().setOnline(online: true);
      await tester.pumpAndSettle();
      check(banner.evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('stacks below the session-expired banner with exactly one '
        'top-inset owner; dismissal hands the inset over', (tester) async {
      fakeAuth().mode = FakeAuthMode.sessionExpired;
      await goHomeAsGuest(tester);
      check(sessionBanner.evaluate()).length.equals(1);

      fakeConnectivity().setOnline(online: false);
      await tester.pumpAndSettle();

      // Both banners visible: session-expired on top, offline below it, and
      // only the topmost applies the inset.
      check(sessionBanner.evaluate()).length.equals(1);
      check(banner.evaluate()).length.equals(1);
      check(
        tester.getTopLeft(banner).dy,
      ).isGreaterThan(tester.getTopLeft(sessionBanner).dy);
      check(bannerOwnsInset(tester)).isFalse();

      // Dismissing the session banner promotes the offline banner to the
      // topmost slot — it must now own the inset.
      await tester.tap(
        find.descendant(of: sessionBanner, matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
      check(sessionBanner.evaluate()).isEmpty();
      check(banner.evaluate()).length.equals(1);
      check(bannerOwnsInset(tester)).isTrue();
      check(tester.takeException()).isNull();
    });

    testWidgets('an app resume re-probes a transport change the stream '
        'missed', (tester) async {
      await goHomeAsGuest(tester);
      check(banner.evaluate()).isEmpty();

      // The transport dropped while backgrounded: no stream event reaches
      // the cubit, so nothing changes yet…
      fakeConnectivity().setOnlineSilently(online: false);
      await tester.pumpAndSettle();
      check(banner.evaluate()).isEmpty();

      // …until the resume-time refresh probes it.
      await backgroundAndResume(tester);
      check(banner.evaluate()).length.equals(1);

      // And the mirror: back online while backgrounded → resume clears it.
      fakeConnectivity().setOnlineSilently(online: true);
      await backgroundAndResume(tester);
      check(banner.evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });
}
