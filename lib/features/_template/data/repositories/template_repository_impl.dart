import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/_template/data/dtos/template_item_dto.dart';
import 'package:okey_acar_mi/features/_template/domain/entities/template_item.dart';
import 'package:okey_acar_mi/features/_template/domain/repositories/template_repository.dart';

/// Production [TemplateRepository].
///
/// Stub for Step 0 — returns DTO-mapped data to prove the prod wiring path. A
/// real data source (Firestore/network) is wired in when this pattern is copied
/// for an actual feature.
@Environment('prod')
@LazySingleton(as: TemplateRepository)
class TemplateRepositoryImpl implements TemplateRepository {
  /// Creates a [TemplateRepositoryImpl].
  const TemplateRepositoryImpl();

  static const List<TemplateItemDto> _source = <TemplateItemDto>[
    TemplateItemDto(id: 'prod-1', label: 'Production item'),
  ];

  @override
  Future<List<TemplateItem>> getItems() async =>
      _source.map((dto) => dto.toEntity()).toList(growable: false);
}
