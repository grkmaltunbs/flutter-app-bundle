import 'package:json_annotation/json_annotation.dart';
import 'package:okey_acar_mi/features/_template/domain/entities/template_item.dart';

part 'template_item_dto.g.dart';

/// JSON-serializable data-transfer object for [TemplateItem].
///
/// Owns serialization so the domain entity stays free of `json_serializable`.
@JsonSerializable()
class TemplateItemDto {
  /// Creates a [TemplateItemDto].
  const TemplateItemDto({required this.id, required this.label});

  /// Builds a DTO from a domain [entity].
  TemplateItemDto.fromEntity(TemplateItem entity)
    : id = entity.id,
      label = entity.label;

  /// Builds a DTO from decoded JSON.
  factory TemplateItemDto.fromJson(Map<String, dynamic> json) =>
      _$TemplateItemDtoFromJson(json);

  /// The stable identifier.
  final String id;

  /// The human-readable label.
  final String label;

  /// Encodes this DTO to JSON.
  Map<String, dynamic> toJson() => _$TemplateItemDtoToJson(this);

  /// Maps to the domain entity.
  TemplateItem toEntity() => TemplateItem(id: id, label: label);
}
