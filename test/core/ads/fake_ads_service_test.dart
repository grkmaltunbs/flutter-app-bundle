import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/ads/ad_placement.dart';
import 'package:okey_acar_mi/core/ads/fakes/fake_ads_service.dart';

void main() {
  late FakeAdsService service;

  setUp(() => service = FakeAdsService());

  /// Drives one rewarded show and records which terminal callbacks fired.
  Future<({bool rewarded, bool dismissed, bool failed})> show() async {
    var rewarded = false;
    var dismissed = false;
    var failed = false;
    await service.showRewarded(
      onReward: () => rewarded = true,
      onDismissedWithoutReward: () => dismissed = true,
      onFailed: (_) => failed = true,
    );
    return (rewarded: rewarded, dismissed: dismissed, failed: failed);
  }

  group('FakeAdsService', () {
    test('isInitialized is always true', () {
      check(service.isInitialized).isTrue();
    });

    test('createBanner returns a non-throwing handle', () {
      final handle = service.createBanner(AdPlacement.result);
      check(handle).isNotNull();
      // Disposing the demo handle is a no-op and must not throw.
      handle.dispose();
    });

    test('showRewarded grants the reward by default (no failure)', () async {
      final r = await show();
      check(r.rewarded).isTrue();
      check(r.failed).isFalse();
    });

    test('failNextRewarded → onFailed only, no reward (auto-clears)', () async {
      service.failNextRewarded = true;
      final first = await show();
      check(first.rewarded).isFalse();
      check(first.failed).isTrue();

      // Auto-cleared: the next show grants again.
      final second = await show();
      check(second.rewarded).isTrue();
      check(second.failed).isFalse();
    });

    test('dismissNextWithoutReward → onDismissedWithoutReward only, no reward '
        '(auto-clears)', () async {
      service.dismissNextWithoutReward = true;
      final first = await show();
      check(first.rewarded).isFalse();
      check(first.dismissed).isTrue();
      check(first.failed).isFalse();

      final second = await show();
      check(second.rewarded).isTrue();
    });

    test('reset clears both toggles', () async {
      service
        ..failNextRewarded = true
        ..dismissNextWithoutReward = true
        ..reset();
      check(service.failNextRewarded).isFalse();
      check(service.dismissNextWithoutReward).isFalse();
      check((await show()).rewarded).isTrue();
    });
  });
}
