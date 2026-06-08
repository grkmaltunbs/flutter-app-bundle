part of 'template_bloc.dart';

/// Intent events for `TemplateBloc` (past-tense, no `BuildContext`).
sealed class TemplateEvent {
  const TemplateEvent();
}

/// The user (or page init) requested the template items.
class TemplateItemsRequested extends TemplateEvent {
  /// Creates a [TemplateItemsRequested].
  const TemplateItemsRequested();
}
