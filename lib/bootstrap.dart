import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okey_acar_mi/app.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/env/app_env.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/firebase_options.dart';

/// Performs all pre-`runApp` initialization and starts the app.
///
/// Everything runs inside a single [runZonedGuarded] zone — including
/// `WidgetsFlutterBinding.ensureInitialized()` — so the binding is initialized
/// in the same zone that later calls [runApp]. Initializing the binding in a
/// different zone than `runApp` trips a framework "Zone mismatch" assertion and
/// makes zone-scoped config (the uncaught-error handler) apply inconsistently.
///
/// Order: enter the guarded zone, bind the engine, resolve the flavor,
/// (prod only) init Firebase, configure DI, install error forwarding, run.
Future<void> bootstrap() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Portrait-locked app-wide (D6): the capture flow's viewfinder, the
      // 2-row rack layouts, and every screen in the spec assume portrait.
      await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp],
      );

      // All three families ship as assets (assets/google_fonts/), so font
      // fetching is forbidden outright: rendering must be identical offline.
      GoogleFonts.config.allowRuntimeFetching = false;
      LicenseRegistry.addLicense(() async* {
        for (final family in ['Geist', 'GeistMono', 'InstrumentSerif']) {
          final license = await rootBundle.loadString(
            'assets/google_fonts/OFL-$family.txt',
          );
          yield LicenseEntryWithLineBreaks(['google_fonts'], license);
        }
      });

      final env = AppEnv.current;

      // Demo never touches Firebase: no config exists for it. Only prod
      // attempts initialization. The guard keeps boot itself alive, but the
      // failure is not silent: AuthBloc is created eagerly at startup, so a
      // failed init surfaces as soon as auth is first resolved.
      if (env == AppEnv.prod) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } on Object catch (error, stackTrace) {
          debugPrint('Firebase.initializeApp failed: $error\n$stackTrace');
        }
      }

      await configureDependencies(env.name);

      final logger = getIt<AppLogger>();
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        logger.handle(
          details.exception,
          details.stack,
          details.summary.toString(),
        );
        previousOnError?.call(details);
      };

      runApp(const App());
    },
    _handleUncaughtZoneError,
  );
}

/// Forwards uncaught async errors to the [AppLogger] once DI is ready, falling
/// back to [debugPrint] if the failure occurred before the logger registered.
void _handleUncaughtZoneError(Object error, StackTrace stack) {
  if (getIt.isRegistered<AppLogger>()) {
    getIt<AppLogger>().handle(error, stack);
  } else {
    debugPrint('Uncaught zone error before logger init: $error\n$stack');
  }
}
