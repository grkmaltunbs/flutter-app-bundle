import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/ads/ad_placement.dart';
import 'package:okey_acar_mi/core/ads/presentation/ad_banner.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/payments/data/fakes/fake_purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/domain/repositories/purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  // Demo DI: AdBanner resolves getIt<AdsService> for its banner handle.
  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  FakePurchaseRepository fakePurchases() =>
      getIt<PurchaseRepository>() as FakePurchaseRepository;

  Future<void> pumpBanner(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('tr'), Locale('en')],
        home: BlocProvider<SubscriptionBloc>(
          create: (_) =>
              getIt<SubscriptionBloc>()..add(const SubscriptionEvent.started()),
          child: const Scaffold(
            body: AdBanner(placement: AdPlacement.result),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AdBanner', () {
    testWidgets('free user: renders the demo placeholder, never throws', (
      tester,
    ) async {
      await pumpBanner(tester);

      check(find.text(_l10n.adPlaceholderLabel).evaluate()).length.equals(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('premium user: collapses to a zero-size box (no placeholder)', (
      tester,
    ) async {
      fakePurchases().setMode(FakePurchaseMode.premium);
      await pumpBanner(tester);

      check(find.text(_l10n.adPlaceholderLabel).evaluate()).isEmpty();
      // The banner self-hides entirely for premium.
      check(
        find
            .descendant(
              of: find.byType(AdBanner),
              matching: find.byType(SizedBox),
            )
            .evaluate(),
      ).isNotEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('hides live when the entitlement flips to premium', (
      tester,
    ) async {
      await pumpBanner(tester);
      check(find.text(_l10n.adPlaceholderLabel).evaluate()).length.equals(1);

      fakePurchases().setMode(FakePurchaseMode.premium);
      await tester.pumpAndSettle();

      check(find.text(_l10n.adPlaceholderLabel).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });
}
