import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/_template/domain/entities/template_item.dart';
import 'package:okey_acar_mi/features/_template/domain/repositories/template_repository.dart';

/// The states a demo fake can be driven into, so every screen state
/// (populated / empty / error) is reachable on a simulator without a mock.
///
/// This is the reference pattern every feature fake follows (CLAUDE.md:
/// "Fakes can simulate failures … so error/edge paths are testable").
enum FakeRepoMode {
  /// Returns the seeded items.
  populated,

  /// Returns an empty list.
  empty,

  /// Throws, exercising the repository's error path.
  error,
}

/// In-memory, seeded [TemplateRepository] for the demo flavor.
///
/// Deterministic and offline — the pattern every feature fake follows. Flip
/// [mode] (it is a `demo`-scoped singleton, so tests resolve it from the DI
/// container and set the mode) to drive the empty and error states.
@Environment('demo')
@LazySingleton(as: TemplateRepository)
class FakeTemplateRepository implements TemplateRepository {
  /// Creates a [FakeTemplateRepository] in the [FakeRepoMode.populated] state.
  FakeTemplateRepository();

  /// Controls what [getItems] returns. Defaults to [FakeRepoMode.populated].
  FakeRepoMode mode = FakeRepoMode.populated;

  static const List<TemplateItem> _seed = <TemplateItem>[
    TemplateItem(id: 'demo-1', label: 'Seeded item one'),
    TemplateItem(id: 'demo-2', label: 'Seeded item two'),
  ];

  @override
  Future<List<TemplateItem>> getItems() async => switch (mode) {
    FakeRepoMode.populated => _seed,
    FakeRepoMode.empty => const <TemplateItem>[],
    FakeRepoMode.error => throw Exception(
      'FakeTemplateRepository: forced demo failure',
    ),
  };
}
