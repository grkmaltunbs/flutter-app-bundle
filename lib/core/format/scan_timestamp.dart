import 'package:intl/intl.dart';

/// Formats a scan timestamp for the history list and the home last-scan
/// card, relative to [now].
///
/// Pure (no `BuildContext`): the caller supplies the localized
/// [todayLabel] / [yesterdayLabel] and the [localeName] for `intl`. Both
/// instants are converted to local time inside.
///
/// - Same calendar day: the bare time (`21:48`) when [todayLabel] is null
///   (history list), or `Bugün · 21:48` when provided (home card).
/// - Yesterday: `Dün · 21:48`.
/// - Older: an abbreviated month-day (`21 May` / `May 21`).
String formatScanTimestamp({
  required DateTime at,
  required DateTime now,
  required String localeName,
  required String yesterdayLabel,
  String? todayLabel,
}) {
  final local = at.toLocal();
  final localNow = now.toLocal();
  if (_sameDay(local, localNow)) {
    final time = DateFormat.Hm(localeName).format(local);
    return todayLabel == null ? time : '$todayLabel · $time';
  }
  if (_sameDay(local, localNow.subtract(const Duration(days: 1)))) {
    return '$yesterdayLabel · ${DateFormat.Hm(localeName).format(local)}';
  }
  return DateFormat.MMMd(localeName).format(local);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
