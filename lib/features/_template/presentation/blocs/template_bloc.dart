import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/error/error_mapper.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/features/_template/domain/entities/template_item.dart';
import 'package:okey_acar_mi/features/_template/domain/usecases/get_template_items.dart';

part 'template_bloc.freezed.dart';
part 'template_event.dart';
part 'template_state.dart';

/// Reference [Bloc] for the `_template` feature.
///
/// No Flutter imports beyond `flutter_bloc`; dependencies are constructor
/// injected. Holds no subscriptions, so [close] is not overridden.
@injectable
class TemplateBloc extends Bloc<TemplateEvent, TemplateState> {
  /// Creates a [TemplateBloc].
  TemplateBloc(this._getTemplateItems) : super(const TemplateState.initial()) {
    on<TemplateItemsRequested>(_onItemsRequested);
  }

  final GetTemplateItems _getTemplateItems;

  Future<void> _onItemsRequested(
    TemplateItemsRequested event,
    Emitter<TemplateState> emit,
  ) async {
    emit(const TemplateState.loading());
    try {
      final items = await _getTemplateItems();
      emit(TemplateState.loaded(items));
    } on Object catch (error) {
      emit(TemplateState.error(mapToFailure(error)));
    }
  }
}
