import 'package:flutter_driver/driver_extension.dart';
import 'package:okey_acar_mi/bootstrap.dart';

/// QA entrypoint: boots the regular app (demo flavor by default) with the
/// Flutter Driver extension enabled so MCP tooling can drive the UI.
///
/// Never shipped — `lib/main.dart` stays the production entrypoint.
Future<void> main() async {
  enableFlutterDriverExtension();
  await bootstrap();
}
