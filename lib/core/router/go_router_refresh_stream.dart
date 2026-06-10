import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Stream] (e.g. a bloc's state stream) to a [Listenable] for
/// `GoRouter.refreshListenable`, so redirects re-evaluate on every emission.
class GoRouterRefreshStream extends ChangeNotifier {
  /// Creates a [GoRouterRefreshStream] subscribed to [stream].
  ///
  /// [stream] is listened to directly — bloc state streams are already
  /// broadcast, and an `asBroadcastStream()` wrapper would leave a paused,
  /// buffering inner subscription alive after [dispose].
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
