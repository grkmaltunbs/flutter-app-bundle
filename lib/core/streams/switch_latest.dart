import 'dart:async';

/// Maps each event of [outer] to an inner stream via [inner] and emits the
/// events of the **latest** inner stream only (a minimal `switchMap`, no
/// rxdart).
///
/// On every [outer] event the previous inner subscription is cancelled before
/// the new inner stream is subscribed, so stale inner events can never leak
/// past a switch. Errors from either stream are forwarded. The result closes
/// once [outer] is done **and** the last inner stream is done. Pausing the
/// result pauses both subscriptions; cancelling cancels both.
Stream<R> switchLatest<T, R>(
  Stream<T> outer,
  Stream<R> Function(T value) inner,
) {
  late final StreamController<R> controller;
  StreamSubscription<T>? outerSubscription;
  StreamSubscription<R>? innerSubscription;
  var outerDone = false;

  void maybeClose() {
    if (outerDone && innerSubscription == null && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  void onOuterEvent(T value) {
    final previous = innerSubscription;
    innerSubscription = null;
    // Fire-and-forget: the old inner stream is stale; nothing depends on the
    // completion of its cancel.
    unawaited(previous?.cancel());

    late final StreamSubscription<R> subscription;
    subscription = inner(value).listen(
      controller.add,
      onError: controller.addError,
      onDone: () {
        // Only the *current* inner stream's completion matters; a stale
        // onDone racing a switch must not clear the new subscription.
        if (identical(innerSubscription, subscription)) {
          innerSubscription = null;
          maybeClose();
        }
      },
    );
    innerSubscription = subscription;
    if (controller.isPaused) subscription.pause();
  }

  controller = StreamController<R>(
    onListen: () {
      outerSubscription = outer.listen(
        onOuterEvent,
        onError: controller.addError,
        onDone: () {
          outerDone = true;
          maybeClose();
        },
      );
    },
    onPause: () {
      outerSubscription?.pause();
      innerSubscription?.pause();
    },
    onResume: () {
      outerSubscription?.resume();
      innerSubscription?.resume();
    },
    onCancel: () async {
      await innerSubscription?.cancel();
      await outerSubscription?.cancel();
      innerSubscription = null;
      outerSubscription = null;
    },
  );
  return controller.stream;
}
