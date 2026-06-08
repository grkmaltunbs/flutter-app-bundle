part of 'template_bloc.dart';

/// Sealed UI state for [TemplateBloc].
///
/// One variant per screen state — never a single mutable state with nullable
/// fields.
@freezed
sealed class TemplateState with _$TemplateState {
  /// Nothing requested yet.
  const factory TemplateState.initial() = TemplateInitial;

  /// A fetch is in flight.
  const factory TemplateState.loading() = TemplateLoading;

  /// Items loaded successfully.
  const factory TemplateState.loaded(List<TemplateItem> items) = TemplateLoaded;

  /// The fetch failed.
  const factory TemplateState.error(Failure failure) = TemplateError;
}
