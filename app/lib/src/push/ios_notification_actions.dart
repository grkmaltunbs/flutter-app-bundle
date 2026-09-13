import 'package:flutter/services.dart';

/// APNs approval buttons arrive before Dart on a cold launch. The native
/// delegate keeps them until the signed-in phone listener is ready.
class IosNotificationActions {
  IosNotificationActions({required this.answer, MethodChannel? channel})
      : channel = channel ?? const MethodChannel('dev.flutterkit.kitApp/notification_actions');
  final Future<void> Function(Map<String, Object?> data, String action) answer;
  final MethodChannel channel;

  Future<void> start() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'action') await _handle(call.arguments);
    });
    final pending = await channel.invokeListMethod<Object?>('ready');
    Object? firstError;
    StackTrace? firstStack;
    for (final event in pending ?? const []) {
      try {
        await _handle(event);
      } on Object catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  Future<void> _handle(Object? raw) async {
    if (raw is! Map || raw['data'] is! Map) return;
    final data = Map<String, Object?>.from(raw['data'] as Map);
    final action = raw['actionId']?.toString();
    if (action == null || action.isEmpty) return;
    // The answer callback also draws a visible failure when the relay refuses
    // or cannot be reached. Only dismiss the original once that work completes.
    await answer(data, action);
    final id = raw['notificationId']?.toString();
    if (id != null) await channel.invokeMethod<void>('handled', id);
  }

  Future<void> withdraw(String requestId) => channel.invokeMethod<void>('withdraw', requestId);
}
