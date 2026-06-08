import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/di/injection.config.dart';

/// The application service locator.
final GetIt getIt = GetIt.instance;

/// Wires up all `@injectable`-annotated registrations for the given [env].
///
/// [env] must be one of the `AppEnv.name` values (`'demo'` or `'prod'`) so the
/// environment-scoped fakes/real impls resolve to a single registration each.
@InjectableInit()
Future<void> configureDependencies(String env) async =>
    getIt.init(environment: env);
