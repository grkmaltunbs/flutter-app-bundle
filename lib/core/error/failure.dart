import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// A sealed, typed application error.
///
/// Repository implementations map infrastructure errors (exceptions, platform
/// errors) into one of these variants so the domain and presentation layers
/// never see raw infrastructure types.
@freezed
sealed class Failure with _$Failure {
  /// A connectivity or transport-level failure.
  const factory Failure.network() = NetworkFailure;

  /// An unexpected, unclassified failure carrying a diagnostic [message].
  const factory Failure.unexpected(String message) = UnexpectedFailure;

  /// A requested resource could not be found.
  const factory Failure.notFound() = NotFoundFailure;
}
