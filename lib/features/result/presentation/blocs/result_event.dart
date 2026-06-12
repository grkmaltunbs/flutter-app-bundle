part of 'result_bloc.dart';

/// The result body layout the user can toggle between.
enum ResultLayout {
  /// The arranged two-row rack with group rings and a legend.
  rack,

  /// One card per meld/pair plus a leftover card.
  list,
}

/// Intent events for [ResultBloc] (past-tense, no `BuildContext`).
@freezed
sealed class ResultEvent with _$ResultEvent {
  /// A solve was requested: fired once on creation, and again by the
  /// failure view's retry action.
  const factory ResultEvent.solveRequested() = ResultSolveRequested;

  /// The user toggled the body layout (rack ⇄ list).
  const factory ResultEvent.layoutToggled(ResultLayout layout) =
      ResultLayoutToggled;

  /// The detail-unlock was granted (fired directly by the locked CTA for
  /// now).
  // TODO(step-11): route the grant through the rewarded-ad /
  // SubscriptionBloc gate instead of firing it directly from the CTA.
  const factory ResultEvent.detailUnlockGranted() = ResultDetailUnlockGranted;
}
