import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/core/db/app_database.dart';
import 'package:okey_acar_mi/core/env/app_env.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Closes the [AppDatabase] when the DI container resets (`getIt.reset()`).
FutureOr<void> disposeAppDatabase(AppDatabase instance) => instance.close();

/// DI module providing the single [AppDatabase], shared by both environments.
///
/// The executor is a [LazyDatabase], so the file is only opened (in a
/// background isolate) on the first query. The demo flavor writes to its own
/// file so seeded/demo state never pollutes the real database.
///
/// Under `flutter test` (host unit/widget tests) the connection is an
/// in-memory database instead: `getApplicationDocumentsDirectory()` has no
/// platform handler there, and drift's background-isolate executor cannot
/// settle inside FakeAsync widget tests. The test connection also enables
/// `closeStreamsSynchronously`: drift's default keeps a closed query stream
/// cached for one event-loop turn via a `Timer.run`, which (a) trips
/// flutter_test's pending-timers invariant when a widget tree holding drift
/// streams is disposed at test end, and (b) deadlocks `Database.close()` in
/// `getIt.reset()` teardowns — the timer was created in the test's (now
/// dead) FakeAsync zone, so the close's pending-timer wait never resolves.
/// On-device integration tests exercise the real file with default stream
/// caching — the host check requires a desktop OS, so a `FLUTTER_TEST`
/// variable leaking into a simulator/emulator process can never swap the
/// device database out for an in-memory one.
@module
abstract class DbModule {
  /// The application database singleton.
  @LazySingleton(dispose: disposeAppDatabase)
  AppDatabase get appDatabase => AppDatabase(_openConnection());

  static bool get _isHostTest =>
      Platform.environment['FLUTTER_TEST'] == 'true' &&
      (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

  static QueryExecutor _openConnection() {
    if (_isHostTest) {
      return DatabaseConnection(
        LazyDatabase(() async => NativeDatabase.memory()),
        closeStreamsSynchronously: true,
      );
    }
    return LazyDatabase(() async {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = AppEnv.current == AppEnv.demo
          ? 'okey_demo.sqlite'
          : 'okey.sqlite';
      return NativeDatabase.createInBackground(
        File(p.join(directory.path, fileName)),
      );
    });
  }
}
