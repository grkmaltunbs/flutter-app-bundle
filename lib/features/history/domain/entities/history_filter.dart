/// The history list's verdict filter.
enum HistoryFilter {
  /// Every scan.
  all,

  /// Scans whose hand opened (101) or was winning (okey, tilesToWin == 0).
  opened,

  /// Scans whose hand did not open / was not yet winning.
  closed,
}
