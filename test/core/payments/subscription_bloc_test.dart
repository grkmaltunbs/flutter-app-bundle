import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/payments/data/fakes/fake_purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/entitlement.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_offering.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';
import 'package:okey_acar_mi/core/payments/purchase_failure.dart';
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';
import 'package:okey_acar_mi/core/time/clock.dart';

/// The monthly package the seeded fake offering exposes; the purchase tests
/// dispatch a purchase for it.
const _monthly = SubscriptionPackage(
  id: r'$rc_monthly',
  period: SubscriptionPeriod.monthly,
  priceString: '₺29,99/ay',
  hasTrial: true,
  trialDays: 7,
);

void main() {
  late FakePurchaseRepository repository;

  setUp(() => repository = FakePurchaseRepository(const FakeClock()));
  tearDown(() => repository.dispose());

  SubscriptionBloc build() => SubscriptionBloc(repository);

  /// The premium entitlement the fake seeds at the clock instant.
  Entitlement premiumAt() => Entitlement(
    isPremium: true,
    willRenew: true,
    expiresAt: FakeClock.seed.add(const Duration(days: 30)),
  );

  group('SubscriptionBloc', () {
    test('initial state is the free entitlement, idle flow, no offering', () {
      final bloc = build();
      addTearDown(bloc.close);

      check(bloc.state.entitlement).equals(Entitlement.free);
      check(bloc.state.offering).isNull();
      check(bloc.state.flow).equals(const SubscriptionFlow.idle());
      check(bloc.state.isPremium).isFalse();
    });

    group('started', () {
      blocTest<SubscriptionBloc, SubscriptionState>(
        'reads the current (free) entitlement and stays free',
        build: build,
        act: (bloc) => bloc.add(const SubscriptionEvent.started()),
        expect: () => const <SubscriptionState>[
          SubscriptionState(entitlement: Entitlement.free),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'on a premium-seeded repo, started surfaces premium',
        setUp: () => repository.setMode(FakePurchaseMode.premium),
        build: build,
        act: (bloc) => bloc.add(const SubscriptionEvent.started()),
        verify: (bloc) {
          check(bloc.state.isPremium).isTrue();
          check(bloc.state.entitlement.willRenew).isTrue();
        },
      );
    });

    group('entitlement stream', () {
      blocTest<SubscriptionBloc, SubscriptionState>(
        'a stream emission of premium flips isPremium true without touching '
        'the transient flow',
        build: build,
        act: (bloc) => repository.setMode(FakePurchaseMode.premium),
        wait: const Duration(milliseconds: 10),
        verify: (bloc) {
          check(bloc.state.isPremium).isTrue();
          check(bloc.state.flow).equals(const SubscriptionFlow.idle());
        },
      );
    });

    group('offeringsRequested', () {
      blocTest<SubscriptionBloc, SubscriptionState>(
        'transitions offeringsLoading → idle with the seeded offering set',
        build: build,
        act: (bloc) => bloc.add(const SubscriptionEvent.offeringsRequested()),
        expect: () => const <SubscriptionState>[
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.offeringsLoading(),
          ),
          SubscriptionState(
            entitlement: Entitlement.free,
            offering: SubscriptionOffering(monthly: _monthly, annual: _annual),
          ),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'offline → loading then the offline flow (no offering)',
        setUp: () => repository.offline = true,
        build: build,
        act: (bloc) => bloc.add(const SubscriptionEvent.offeringsRequested()),
        expect: () => const <SubscriptionState>[
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.offeringsLoading(),
          ),
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.offline(),
          ),
        ],
      );
    });

    group('purchaseRequested', () {
      blocTest<SubscriptionBloc, SubscriptionState>(
        'happy path: emits purchasing, then settles on purchaseSucceeded + '
        'premium (the fake also re-delivers premium via the stream)',
        build: build,
        act: (bloc) =>
            bloc.add(const SubscriptionEvent.purchaseRequested(_monthly)),
        wait: const Duration(milliseconds: 10),
        verify: (bloc) {
          check(bloc.state.flow)
              .equals(const SubscriptionFlow.purchaseSucceeded());
          check(bloc.state.entitlement).equals(premiumAt());
          check(bloc.state.isPremium).isTrue();
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'happy path: the first transient state is the purchasing flow',
        build: build,
        act: (bloc) =>
            bloc.add(const SubscriptionEvent.purchaseRequested(_monthly)),
        wait: const Duration(milliseconds: 10),
        verify: (bloc) {},
        expect: () => containsAllInOrder(<SubscriptionState>[
          const SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.purchasing(),
          ),
          SubscriptionState(
            entitlement: premiumAt(),
            flow: const SubscriptionFlow.purchaseSucceeded(),
          ),
        ]),
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'cancelled: purchasing → idle, no error, entitlement unchanged',
        // The user dismissing the sheet is not an error: the bloc maps
        // PurchaseCancelled to a silent return to idle.
        setUp: () =>
            repository.failNextPurchaseWith = const PurchaseFailure.cancelled(),
        build: build,
        act: (bloc) =>
            bloc.add(const SubscriptionEvent.purchaseRequested(_monthly)),
        expect: () => const <SubscriptionState>[
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.purchasing(),
          ),
          SubscriptionState(entitlement: Entitlement.free),
        ],
        verify: (bloc) => check(bloc.state.isPremium).isFalse(),
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'paymentFailed: purchasing → error(failure), entitlement unchanged',
        setUp: () => repository.failNextPurchase = true,
        build: build,
        act: (bloc) =>
            bloc.add(const SubscriptionEvent.purchaseRequested(_monthly)),
        expect: () => const <SubscriptionState>[
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.purchasing(),
          ),
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.error(
              PurchaseFailure.paymentFailed('fake payment failure'),
            ),
          ),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'pending: purchasing → error(pending)',
        setUp: () =>
            repository.failNextPurchaseWith = const PurchaseFailure.pending(),
        build: build,
        act: (bloc) =>
            bloc.add(const SubscriptionEvent.purchaseRequested(_monthly)),
        expect: () => const <SubscriptionState>[
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.purchasing(),
          ),
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.error(PurchaseFailure.pending()),
          ),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'offline during purchase → purchasing then offline flow',
        setUp: () => repository.offline = true,
        build: build,
        act: (bloc) =>
            bloc.add(const SubscriptionEvent.purchaseRequested(_monthly)),
        expect: () => const <SubscriptionState>[
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.purchasing(),
          ),
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.offline(),
          ),
        ],
      );
    });

    group('restoreRequested', () {
      blocTest<SubscriptionBloc, SubscriptionState>(
        'happy path: restoring → restoreSucceeded; premium-seeded restores '
        'premium',
        setUp: () => repository.setMode(FakePurchaseMode.premium),
        build: build,
        act: (bloc) => bloc.add(const SubscriptionEvent.restoreRequested()),
        verify: (bloc) {
          check(bloc.state.flow)
              .equals(const SubscriptionFlow.restoreSucceeded());
          check(bloc.state.isPremium).isTrue();
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'nothing to restore: restoring → error(restoreNothing)',
        setUp: () => repository.nothingToRestore = true,
        build: build,
        act: (bloc) => bloc.add(const SubscriptionEvent.restoreRequested()),
        expect: () => const <SubscriptionState>[
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.restoring(),
          ),
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.error(PurchaseFailure.restoreNothing()),
          ),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'offline during restore → restoring then offline flow',
        setUp: () => repository.offline = true,
        build: build,
        act: (bloc) => bloc.add(const SubscriptionEvent.restoreRequested()),
        expect: () => const <SubscriptionState>[
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.restoring(),
          ),
          SubscriptionState(
            entitlement: Entitlement.free,
            flow: SubscriptionFlow.offline(),
          ),
        ],
      );
    });

    group('refreshRequested', () {
      blocTest<SubscriptionBloc, SubscriptionState>(
        're-reads the entitlement: an expired-seeded repo flips isPremium '
        'false',
        setUp: () => repository.setMode(FakePurchaseMode.expired),
        build: build,
        act: (bloc) => bloc.add(const SubscriptionEvent.refreshRequested()),
        verify: (bloc) {
          check(bloc.state.isPremium).isFalse();
          check(bloc.state.entitlement.expiresAt).isNotNull();
        },
      );
    });

    test('close cancels the subscription: a later stream change does not emit '
        'after close', () async {
      final bloc = build();
      final emitted = <SubscriptionState>[];
      final sub = bloc.stream.listen(emitted.add);

      await bloc.close();
      // A post-close repository change must not drive an emission.
      repository.setMode(FakePurchaseMode.premium);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      check(emitted.where((s) => s.isPremium)).isEmpty();
      await sub.cancel();
    });
  });
}

const _annual = SubscriptionPackage(
  id: r'$rc_annual',
  period: SubscriptionPeriod.annual,
  priceString: '₺199,99/yıl',
  hasTrial: true,
  trialDays: 7,
);
