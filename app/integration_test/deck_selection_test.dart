// Exercise the same selection gestures against the native Flutter runtime.
// The Deck fixture has no backend or engine connection.
import 'package:integration_test/integration_test.dart';

import '../test/deck_selection_test.dart' as selection;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  selection.main();
}
