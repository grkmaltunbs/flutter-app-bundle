import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:okey_acar_mi/core/format/scan_timestamp.dart';

/// All fixtures are constructed as **local** DateTimes so the function's
/// internal `toLocal()` is the identity and the assertions are independent
/// of the host timezone.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr');
    await initializeDateFormatting('en');
  });

  String tr(DateTime at, DateTime now, {String? todayLabel}) =>
      formatScanTimestamp(
        at: at,
        now: now,
        localeName: 'tr',
        todayLabel: todayLabel,
        yesterdayLabel: 'Dün',
      );

  String en(DateTime at, DateTime now, {String? todayLabel}) =>
      formatScanTimestamp(
        at: at,
        now: now,
        localeName: 'en',
        todayLabel: todayLabel,
        yesterdayLabel: 'Yesterday',
      );

  group('same calendar day', () {
    final now = DateTime(2026, 5, 22, 23);
    final at = DateTime(2026, 5, 22, 21, 48);

    test('without todayLabel renders the bare HH:mm (history list)', () {
      check(tr(at, now)).equals('21:48');
      check(en(at, now)).equals('21:48');
    });

    test('with todayLabel renders "<label> · HH:mm" (home card)', () {
      check(tr(at, now, todayLabel: 'Bugün')).equals('Bugün · 21:48');
      check(en(at, now, todayLabel: 'Today')).equals('Today · 21:48');
    });

    test('midnight today is still today, zero-padded', () {
      final midnight = DateTime(2026, 5, 22);
      check(tr(midnight, now)).equals('00:00');
    });

    test('single-digit hour and minute are zero-padded', () {
      check(tr(DateTime(2026, 5, 22, 9, 5), now)).equals('09:05');
    });
  });

  group('yesterday', () {
    test('renders "<yesterdayLabel> · HH:mm" in both locales', () {
      final now = DateTime(2026, 5, 22, 8);
      final at = DateTime(2026, 5, 21, 21, 48);
      check(tr(at, now)).equals('Dün · 21:48');
      check(en(at, now)).equals('Yesterday · 21:48');
    });

    test('23:59 yesterday is yesterday; 00:00 today is today', () {
      final now = DateTime(2026, 5, 22, 12);
      check(
        tr(DateTime(2026, 5, 21, 23, 59), now),
      ).equals('Dün · 23:59');
      check(tr(DateTime(2026, 5, 22), now)).equals('00:00');
    });

    test('survives a month boundary: May 31 is yesterday on June 1', () {
      final now = DateTime(2026, 6, 1, 10);
      final at = DateTime(2026, 5, 31, 22, 10);
      check(tr(at, now)).equals('Dün · 22:10');
      check(en(at, now)).equals('Yesterday · 22:10');
    });

    test('survives a year boundary: Dec 31 is yesterday on Jan 1', () {
      final now = DateTime(2026, 1, 1, 7);
      final at = DateTime(2025, 12, 31, 23, 59);
      check(tr(at, now)).equals('Dün · 23:59');
    });

    test('the todayLabel does not leak into the yesterday format', () {
      final now = DateTime(2026, 5, 22, 8);
      final at = DateTime(2026, 5, 21, 21, 48);
      check(tr(at, now, todayLabel: 'Bugün')).equals('Dün · 21:48');
    });
  });

  group('older than yesterday', () {
    test('renders the localized abbreviated month-day: "21 May" (tr) vs '
        '"May 21" (en)', () {
      final now = DateTime(2026, 6, 12, 10);
      final at = DateTime(2026, 5, 21, 21, 48);
      check(tr(at, now)).equals('21 May');
      check(en(at, now)).equals('May 21');
    });

    test('two days back across a month edge is MMMd, not yesterday', () {
      final now = DateTime(2026, 6, 1, 10);
      final at = DateTime(2026, 5, 30, 9);
      check(tr(at, now)).equals('30 May');
      check(en(at, now)).equals('May 30');
    });

    test("a different month uses that month's localized abbreviation", () {
      final now = DateTime(2026, 6, 12, 10);
      final at = DateTime(2026, 2, 3, 9);
      check(tr(at, now)).equals('3 Şub');
      check(en(at, now)).equals('Feb 3');
    });

    test('same day-of-month a year earlier is MMMd, never "today"', () {
      final now = DateTime(2026, 5, 22, 10);
      final at = DateTime(2025, 5, 22, 10);
      check(tr(at, now)).equals('22 May');
    });
  });
}
