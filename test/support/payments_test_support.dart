import 'package:okey_acar_mi/core/payments/data/fakes/fake_purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/subscription_bloc.dart';
import 'package:okey_acar_mi/core/time/clock.dart';

/// Builds a [SubscriptionBloc] over a fresh [FakePurchaseRepository] seeded to
/// [mode], started (so the initial entitlement is read).
///
/// Used by widget harnesses that need a real, controllable subscription bloc
/// without bringing up the whole demo DI container. The caller owns closing
/// the bloc (`addTearDown(bloc.close)`).
SubscriptionBloc buildSubscriptionBloc({
  FakePurchaseMode mode = FakePurchaseMode.free,
}) {
  final repository = FakePurchaseRepository(const FakeClock())..setMode(mode);
  return SubscriptionBloc(repository)..add(const SubscriptionEvent.started());
}
