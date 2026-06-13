import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The installed app's version identity, read once at startup.
class AppInfo {
  /// Creates an [AppInfo] from a version and build number.
  const AppInfo({required this.version, required this.buildNumber});

  /// The marketing version (e.g. `1.0.0`).
  final String version;

  /// The build number (e.g. `1`).
  final String buildNumber;

  /// The display label, e.g. `1.0.0 (1)`.
  String get label => '$version ($buildNumber)';
}

/// DI module providing the [AppInfo] singleton (both environments).
@module
abstract class AppInfoModule {
  /// Reads the platform package info once; falls back to zeros where no
  /// platform channel exists (host `flutter test` only).
  @preResolve
  @lazySingleton
  Future<AppInfo> appInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppInfo(version: info.version, buildNumber: info.buildNumber);
    } on Exception {
      return const AppInfo(version: '0.0.0', buildNumber: '0');
    }
  }
}
