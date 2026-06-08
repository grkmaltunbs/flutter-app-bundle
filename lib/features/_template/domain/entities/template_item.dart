import 'package:freezed_annotation/freezed_annotation.dart';

part 'template_item.freezed.dart';

/// A minimal domain entity for the reference `_template` feature.
///
/// Pure Dart: no Flutter, Firebase, or data-layer imports.
@freezed
abstract class TemplateItem with _$TemplateItem {
  /// Creates a [TemplateItem].
  const factory TemplateItem({
    required String id,
    required String label,
  }) = _TemplateItem;
}
