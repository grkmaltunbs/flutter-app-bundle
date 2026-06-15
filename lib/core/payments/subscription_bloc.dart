import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/entitlement.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_offering.dart';
import 'package:okey_acar_mi/core/payments/domain/entities/subscription_package.dart';
import 'package:okey_acar_mi/core/payments/domain/repositories/purchase_repository.dart';
import 'package:okey_acar_mi/core/payments/purchase_failure.dart';

part 'subscription_bloc.freezed.dart';
part 'subscription_event.dart';
part 'subscription_state.dart';

/// App-scoped subscription bloc: the single gate for the `premium` entitlement.
///
/// Mirrors the repository's [PurchaseRepository.entitlementStream] into
/// [SubscriptionState.entitlement] (so ad removal / unlocks update live), and
/// drives the paywall's purchase/restore/offering flows via the transient
/// [SubscriptionFlow]. Every paid feature reads entitlement from here — never
/// the purchase SDK directly. Holds a stream subscription, so [close] is
/// overridden.
@lazySingleton
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  /// Creates a [SubscriptionBloc] and subscribes to entitlement changes.
  SubscriptionBloc(this._repository)
    : super(const SubscriptionState(entitlement: Entitlement.free)) {
    on<SubscriptionStarted>(_onStarted);
    on<SubscriptionRefreshRequested>(_onRefreshRequested);
    on<SubscriptionOfferingsRequested>(_onOfferingsRequested);
    on<SubscriptionPurchaseRequested>(_onPurchaseRequested);
    on<SubscriptionRestoreRequested>(_onRestoreRequested);
    on<SubscriptionEntitlementChanged>(_onEntitlementChanged);

    _subscription = _repository.entitlementStream.listen(
      (entitlement) => add(SubscriptionEvent.entitlementChanged(entitlement)),
    );
  }

  final PurchaseRepository _repository;
  StreamSubscription<Entitlement>? _subscription;

  Future<void> _onStarted(
    SubscriptionStarted event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      final entitlement = await _repository.currentEntitlement();
      emit(state.copyWith(entitlement: entitlement));
    } on Object {
      // A failed initial read keeps the free default; the stream still drives
      // later updates.
    }
  }

  Future<void> _onRefreshRequested(
    SubscriptionRefreshRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      final entitlement = await _repository.currentEntitlement();
      emit(state.copyWith(entitlement: entitlement));
    } on Object {
      // Resume-time refresh is best-effort; the stream remains the source.
    }
  }

  Future<void> _onOfferingsRequested(
    SubscriptionOfferingsRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(flow: const SubscriptionFlow.offeringsLoading()));
    try {
      final offering = await _repository.offerings();
      emit(
        state.copyWith(
          offering: offering,
          flow: const SubscriptionFlow.idle(),
        ),
      );
    } on PurchaseNetwork {
      emit(state.copyWith(flow: const SubscriptionFlow.offline()));
    } on PurchaseFailure catch (failure) {
      emit(state.copyWith(flow: SubscriptionFlow.error(failure)));
    } on Object {
      emit(
        state.copyWith(
          flow: const SubscriptionFlow.error(PurchaseFailure.unknown()),
        ),
      );
    }
  }

  Future<void> _onPurchaseRequested(
    SubscriptionPurchaseRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(flow: const SubscriptionFlow.purchasing()));
    try {
      final entitlement = await _repository.purchase(event.package);
      // The entitlement also arrives via the stream; set it here too so the
      // success state is consistent even if the stream lags.
      emit(
        state.copyWith(
          entitlement: entitlement,
          flow: const SubscriptionFlow.purchaseSucceeded(),
        ),
      );
    } on PurchaseCancelled {
      // User dismissal is not an error: return to idle silently.
      emit(state.copyWith(flow: const SubscriptionFlow.idle()));
    } on PurchaseNetwork {
      emit(state.copyWith(flow: const SubscriptionFlow.offline()));
    } on PurchaseFailure catch (failure) {
      emit(state.copyWith(flow: SubscriptionFlow.error(failure)));
    } on Object {
      emit(
        state.copyWith(
          flow: const SubscriptionFlow.error(PurchaseFailure.unknown()),
        ),
      );
    }
  }

  Future<void> _onRestoreRequested(
    SubscriptionRestoreRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(flow: const SubscriptionFlow.restoring()));
    try {
      final entitlement = await _repository.restore();
      emit(
        state.copyWith(
          entitlement: entitlement,
          flow: const SubscriptionFlow.restoreSucceeded(),
        ),
      );
    } on PurchaseNetwork {
      emit(state.copyWith(flow: const SubscriptionFlow.offline()));
    } on PurchaseFailure catch (failure) {
      emit(state.copyWith(flow: SubscriptionFlow.error(failure)));
    } on Object {
      emit(
        state.copyWith(
          flow: const SubscriptionFlow.error(PurchaseFailure.unknown()),
        ),
      );
    }
  }

  void _onEntitlementChanged(
    SubscriptionEntitlementChanged event,
    Emitter<SubscriptionState> emit,
  ) {
    // A stream update reflects the owned entitlement; leave the transient flow
    // as-is so an in-flight purchase/restore success indicator survives.
    emit(state.copyWith(entitlement: event.entitlement));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
