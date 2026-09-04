import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

typedef CommandRunner = Future<ProcessResult> Function(String executable, List<String> args);

/// Starts the host at login and brings it back after a crash: a
/// LaunchAgent at `~/Library/LaunchAgents/dev.flutterkit.kitApp.plist`
/// that runs this app's binary with RunAtLoad, and KeepAlive only on an
/// unclean exit — a Quit stays quit. It is not bootstrapped on enable,
/// which would start a second copy beside this one; it takes effect at
/// the next login, which is what the switch says.
class LoginItem extends ChangeNotifier {
  LoginItem({String? home, String? executable, CommandRunner? run})
      : home = home ?? Platform.environment['HOME'] ?? '',
        executable = executable ?? Platform.resolvedExecutable,
        _run = run ?? ((e, a) => Process.run(e, a));

  static const label = 'dev.flutterkit.kitApp';

  final String home;
  final String executable;
  final CommandRunner _run;
  String? error;

  File get plist => File(p.join(home, 'Library', 'LaunchAgents', '$label.plist'));
  String get logPath => p.join(home, '.flutter_kit', 'host.log');
  bool get enabled => plist.existsSync();

  static String plistFor({required String executable, required String logPath}) => '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>${_xml(executable)}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>StandardOutPath</key>
  <string>${_xml(logPath)}</string>
  <key>StandardErrorPath</key>
  <string>${_xml(logPath)}</string>
</dict>
</plist>
''';

  static String _xml(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  /// Writes the agent. Returns false and sets [error] when it could not.
  Future<bool> enable() async {
    try {
      plist.parent.createSync(recursive: true);
      plist.writeAsStringSync(plistFor(executable: executable, logPath: logPath));
      // Harmless when it is not loaded yet; undoes an earlier `disable`.
      await _launchctl(['enable', 'gui/${await _uid()}/$label']);
      error = null;
      notifyListeners();
      return true;
    } on Object catch (e) {
      error = 'Could not write the login item: $e';
      notifyListeners();
      return false;
    }
  }

  /// Removes the agent, and unloads it if a login had loaded it — the
  /// running copy is left alone.
  Future<bool> disable() async {
    try {
      await _launchctl(['bootout', 'gui/${await _uid()}/$label']);
      if (plist.existsSync()) plist.deleteSync();
      error = null;
      notifyListeners();
      return true;
    } on Object catch (e) {
      error = 'Could not remove the login item: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _launchctl(List<String> args) async {
    try {
      await _run('launchctl', args);
    } on Object {
      // launchctl missing or refusing is not a reason to fail the switch.
    }
  }

  Future<String> _uid() async {
    try {
      final r = await _run('id', ['-u']);
      final s = (r.stdout as String).trim();
      if (s.isNotEmpty) return s;
    } on Object {
      // fall through
    }
    return '501';
  }

  String get status {
    if (error != null) return error!;
    return enabled ? 'On — launchd starts $executable at login and brings it back after a crash. Off takes effect at once.' : 'Off — after a reboot the phone waits until someone opens the app. On takes effect at the next login.';
  }
}
