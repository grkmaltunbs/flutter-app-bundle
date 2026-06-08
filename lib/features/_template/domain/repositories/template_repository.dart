import 'package:okey_acar_mi/features/_template/domain/entities/template_item.dart';

/// Read access to [TemplateItem]s.
///
/// Implemented by a real (`prod`) impl and an in-memory seeded fake (`demo`).
abstract class TemplateRepository {
  /// Returns all available template items.
  Future<List<TemplateItem>> getItems();
}
