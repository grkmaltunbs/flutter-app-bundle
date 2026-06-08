import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Application-wide structured logger.
///
/// Thin wrapper around [Talker] so the rest of the codebase depends on a small,
/// stable surface rather than the logging package directly. Registered once,
/// independent of the environment flavor.
@lazySingleton
class AppLogger {
  /// Creates an [AppLogger] with a default [Talker] instance.
  AppLogger() : _talker = TalkerFlutter.init();

  final Talker _talker;

  /// The underlying [Talker], exposed for UI screens (e.g. a log viewer).
  Talker get talker => _talker;

  /// Logs an informational [message].
  void info(String message) => _talker.info(message);

  /// Logs a debug [message].
  void debug(String message) => _talker.debug(message);

  /// Logs a warning [message].
  void warning(String message) => _talker.warning(message);

  /// Logs an [error] with an optional [message] and [stackTrace].
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _talker.error(message, error, stackTrace);

  /// Logs an uncaught [error] captured at the zone boundary.
  void handle(Object error, [StackTrace? stackTrace, String? message]) =>
      _talker.handle(error, stackTrace, message);
}
