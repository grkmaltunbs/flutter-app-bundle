import 'package:bloc_test/bloc_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/_template/data/fakes/fake_template_repository.dart';
import 'package:okey_acar_mi/features/_template/domain/entities/template_item.dart';
import 'package:okey_acar_mi/features/_template/domain/usecases/get_template_items.dart';
import 'package:okey_acar_mi/features/_template/presentation/blocs/template_bloc.dart';

class _MockGetTemplateItems extends Mock implements GetTemplateItems {}

/// The items the demo fake seeds. The happy-path bloc test asserts the bloc
/// surfaces exactly these — not just that "some" loaded state was emitted.
const _seededItems = <TemplateItem>[
  TemplateItem(id: 'demo-1', label: 'Seeded item one'),
  TemplateItem(id: 'demo-2', label: 'Seeded item two'),
];

void main() {
  group('TemplateBloc', () {
    test('initial state is TemplateState.initial', () {
      final useCase = GetTemplateItems(FakeTemplateRepository());
      final bloc = TemplateBloc(useCase);
      addTearDown(bloc.close);

      check(bloc.state).equals(const TemplateState.initial());
    });

    group('happy path (against the seeded demo fake)', () {
      blocTest<TemplateBloc, TemplateState>(
        'emits [loading, loaded(seed)] on TemplateItemsRequested',
        build: () => TemplateBloc(
          GetTemplateItems(FakeTemplateRepository()),
        ),
        act: (bloc) => bloc.add(const TemplateItemsRequested()),
        expect: () => const <TemplateState>[
          TemplateState.loading(),
          TemplateState.loaded(_seededItems),
        ],
      );
    });

    group('failure path', () {
      late _MockGetTemplateItems useCase;

      setUp(() => useCase = _MockGetTemplateItems());

      blocTest<TemplateBloc, TemplateState>(
        'maps a thrown Failure into [loading, error]',
        build: () {
          when(useCase.call).thenThrow(const Failure.network());
          return TemplateBloc(useCase);
        },
        act: (bloc) => bloc.add(const TemplateItemsRequested()),
        expect: () => const <TemplateState>[
          TemplateState.loading(),
          TemplateState.error(NetworkFailure()),
        ],
      );

      blocTest<TemplateBloc, TemplateState>(
        'wraps an arbitrary error into an UnexpectedFailure',
        build: () {
          when(useCase.call).thenThrow(Exception('boom'));
          return TemplateBloc(useCase);
        },
        act: (bloc) => bloc.add(const TemplateItemsRequested()),
        expect: () => <TemplateState>[
          const TemplateState.loading(),
          TemplateState.error(Failure.unexpected(Exception('boom').toString())),
        ],
      );
    });
  });
}
