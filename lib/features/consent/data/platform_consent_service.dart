import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as ump;
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/consent/domain/entities/consent_status.dart';
import 'package:okey_acar_mi/features/consent/domain/repositories/consent_service.dart';

/// Production [ConsentService]: AdMob UMP consent form + (iOS) ATT.
///
/// Degrades to non-personalized on ANY failure — it never throws — so a UMP or
/// ATT hiccup can't block boot or ads. Treats restricted / not-supported ATT
/// (simulator) as a clean no-op. Idempotent via an in-memory [_asked] flag:
/// UMP itself caches consent across sessions, so an in-memory guard within a
/// session is sufficient.
@Environment('prod')
@LazySingleton(as: ConsentService)
class PlatformConsentService implements ConsentService {
  /// Creates a [PlatformConsentService].
  PlatformConsentService(this._logger);

  final AppLogger _logger;

  bool _asked = false;
  ConsentStatus _status = const ConsentStatus(
    // Default to non-personalized until consent resolves.
    personalizedAds: false,
    analytics: false,
    att: AttStatus.notDetermined,
  );

  @override
  ConsentStatus get status => _status;

  @override
  bool get personalizedAdsAllowed => _status.personalizedAds;

  @override
  Future<void> ensureRequested() async {
    if (_asked) return;
    _asked = true;

    final umpObtained = await _runUmp();
    final att = await _runAtt();

    // Personalized ads require BOTH UMP consent (where required) and, on iOS,
    // ATT authorization.
    final attOk = att == AttStatus.authorized || att == AttStatus.unavailable;
    final personalized = umpObtained && attOk;
    _status = ConsentStatus(
      personalizedAds: personalized,
      analytics: personalized,
      att: att,
    );
  }

  /// Runs the UMP flow. Returns true when consent is obtained/not-required.
  Future<bool> _runUmp() async {
    try {
      final params = ump.ConsentRequestParameters();
      final completer = Completer<bool>();
      void finish({required bool obtained}) {
        if (!completer.isCompleted) completer.complete(obtained);
      }

      ump.ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            await ump.ConsentForm.loadAndShowConsentFormIfRequired((error) {
              if (error != null) {
                _logger.handle(error, StackTrace.current, 'UMP form error');
              }
            });
            final status = await ump.ConsentInformation.instance
                .getConsentStatus();
            finish(
              obtained:
                  status == ump.ConsentStatus.obtained ||
                  status == ump.ConsentStatus.notRequired,
            );
          } on Object catch (error, stackTrace) {
            _logger.handle(error, stackTrace, 'UMP form load failed');
            finish(obtained: false);
          }
        },
        (error) {
          _logger.handle(error, StackTrace.current, 'UMP info update failed');
          finish(obtained: false);
        },
      );
      return completer.future;
    } on Object catch (error, stackTrace) {
      _logger.handle(error, stackTrace, 'UMP request failed');
      return false;
    }
  }

  /// Runs the iOS ATT prompt. Returns [AttStatus.unavailable] off-iOS or when
  /// ATT cannot be shown (restricted / simulator).
  Future<AttStatus> _runAtt() async {
    if (!Platform.isIOS) return AttStatus.unavailable;
    try {
      final current = await AppTrackingTransparency.trackingAuthorizationStatus;
      final resolved = current == TrackingStatus.notDetermined
          ? await AppTrackingTransparency.requestTrackingAuthorization()
          : current;
      return switch (resolved) {
        TrackingStatus.authorized => AttStatus.authorized,
        TrackingStatus.denied => AttStatus.denied,
        TrackingStatus.notDetermined => AttStatus.notDetermined,
        TrackingStatus.restricted ||
        TrackingStatus.notSupported => AttStatus.unavailable,
      };
    } on Object catch (error, stackTrace) {
      _logger.handle(error, stackTrace, 'ATT request failed');
      return AttStatus.unavailable;
    }
  }
}
