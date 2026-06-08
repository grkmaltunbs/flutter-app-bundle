import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/_template/domain/entities/template_item.dart';
import 'package:okey_acar_mi/features/_template/domain/repositories/template_repository.dart';

/// Fetches the list of [TemplateItem]s.
///
/// A trivial use case demonstrating constructor injection of a repository.
@injectable
class GetTemplateItems {
  /// Creates a [GetTemplateItems] backed by [_repository].
  const GetTemplateItems(this._repository);

  final TemplateRepository _repository;

  /// Executes the use case.
  Future<List<TemplateItem>> call() => _repository.getItems();
}
