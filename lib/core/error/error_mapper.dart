import 'package:okey_acar_mi/core/error/failure.dart';

/// Maps an arbitrary thrown [error] into a typed [Failure].
///
/// Stub for Step 0: feature repositories will extend this with infrastructure
/// specific mappings (Firebase, network, platform exceptions) as those layers
/// land. Anything unrecognized becomes [Failure.unexpected].
Failure mapToFailure(Object error) {
  if (error is Failure) return error;
  return Failure.unexpected(error.toString());
}
