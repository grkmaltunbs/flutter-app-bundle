import 'package:flutter/material.dart';
import 'package:okey_acar_mi/features/_template/domain/entities/template_item.dart';

/// Renders a single [TemplateItem] as a list row.
///
/// Placeholder presentation widget for the reference feature.
class TemplateItemTile extends StatelessWidget {
  /// Creates a [TemplateItemTile] for [item].
  const TemplateItemTile({required this.item, super.key});

  /// The item to display.
  final TemplateItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.label),
      subtitle: Text(item.id),
    );
  }
}
