import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/widgets/home_stub_page.dart';

/// Declarative application router.
///
/// Step 0 exposes a single `/` route to the [HomeStubPage]. Routes for splash,
/// auth, camera, review, result, history, settings, and paywall arrive in
/// Step 2.
@lazySingleton
class AppRouter {
  /// The [GoRouter] configuration consumed by `MaterialApp.router`.
  final GoRouter config = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeStubPage(),
      ),
    ],
  );
}
