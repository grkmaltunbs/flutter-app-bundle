import 'dart:convert';
import 'dart:io';

import 'package:flutter_kit/kit.dart';
import 'package:path/path.dart' as p;

/// What the host knows about the user's Claude Code install without
/// running it: where the binary is, which folders are trusted, and the
/// pointer Remote Control leaves behind.
class ClaudeCli {
  static String get home => Platform.environment['HOME'] ?? '';

  static String? _binary;
  static String? _shellPath;
  static String? _version;

  /// `claude --version`, the number only, once.
  static Future<String?> version() async {
    if (_version != null) return _version;
    final bin = await findBinary();
    if (bin == null) return null;
    try {
      final r = await Process.run(bin, ['--version']).timeout(const Duration(seconds: 15));
      final out = (r.stdout as String).trim();
      return _version = out.isEmpty ? null : out.split(' ').first;
    } on Object {
      return null;
    }
  }

  /// A GUI app inherits a bare PATH; the user's shell has the real one
  /// (`~/.local/bin` for claude, the Flutter SDK for `dart` — which the
  /// hooks need). Asked once, through a login shell.
  static Future<String> shellPath() async {
    if (_shellPath != null) return _shellPath!;
    var path = Platform.environment['PATH'] ?? '';
    try {
      final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
      final r = await Process.run(shell, ['-lic', 'echo __PATH__\$PATH']).timeout(const Duration(seconds: 8));
      final out = (r.stdout as String).split('\n').lastWhere((l) => l.startsWith('__PATH__'), orElse: () => '');
      if (out.isNotEmpty) path = out.substring('__PATH__'.length).trim();
    } on Object {
      // Fall back to the inherited PATH plus the usual suspects.
    }
    final extra = [p.join(home, '.local', 'bin'), '/opt/homebrew/bin', '/usr/local/bin'];
    for (final e in extra) {
      if (!path.split(':').contains(e)) path = '$e:$path';
    }
    return _shellPath = path;
  }

  static Future<String?> findBinary() async {
    if (_binary != null) return _binary;
    final path = await shellPath();
    for (final dir in path.split(':')) {
      final f = File(p.join(dir, 'claude'));
      if (f.existsSync()) return _binary = f.path;
    }
    return null;
  }

  /// Remote Control refuses a folder until `claude` has been run there once
  /// and the trust dialog accepted. That fact lives in `~/.claude.json`.
  static bool isTrusted(String dir) {
    try {
      final m = jsonDecode(File(p.join(home, '.claude.json')).readAsStringSync()) as Map;
      final projects = m['projects'] as Map? ?? const {};
      final entry = projects[dir] as Map? ?? projects[p.normalize(dir)] as Map?;
      return entry?['hasTrustDialogAccepted'] == true;
    } on Object {
      return false;
    }
  }

  static String projectStateDir(String dir) => p.join(home, '.claude', 'projects', claudeProjectSlug(dir));

  static BridgePointer? readPointer(String dir) {
    try {
      final f = File(p.join(projectStateDir(dir), 'bridge-pointer.json'));
      if (!f.existsSync()) return null;
      final m = jsonDecode(f.readAsStringSync()) as Map;
      return BridgePointer(
        sessionId: (m['sessionId'] ?? '').toString(),
        environmentId: (m['environmentId'] ?? '').toString(),
        pid: (m['pid'] as num?)?.toInt(),
        procStart: m['procStart']?.toString(),
      );
    } on Object {
      return null;
    }
  }

  /// True when a hook command that spools for this app reaches the project:
  /// either written into a settings file (`kit.sh hook` / `kit hook`) or via
  /// the flutter-kit plugin, whose hooks.json carries it.
  static bool hooksInstalled(String dir) {
    for (final name in const ['settings.json', 'settings.local.json']) {
      final f = File(p.join(dir, '.claude', name));
      if (!f.existsSync()) continue;
      final text = f.readAsStringSync();
      if (text.contains('kit.sh" hook') || text.contains('kit.sh hook') || text.contains('kit hook')) return true;
      try {
        final m = jsonDecode(text) as Map;
        final plugins = m['enabledPlugins'] as Map? ?? const {};
        for (final e in plugins.entries) {
          if (e.key.toString().startsWith('flutter-kit@') && e.value == true) return true;
        }
      } on Object {
        // Not JSON we can read — fall through to the other file.
      }
    }
    return false;
  }

  static bool processAlive(int? pid) {
    if (pid == null) return false;
    try {
      return Process.runSync('kill', ['-0', '$pid']).exitCode == 0;
    } on Object {
      return false;
    }
  }
}

class BridgePointer {
  BridgePointer({required this.sessionId, required this.environmentId, this.pid, this.procStart});
  final String sessionId;
  final String environmentId;
  final int? pid;
  final String? procStart;

  String get sessionUrl => 'https://claude.ai/code/$sessionId';
  String get environmentUrl => 'https://claude.ai/code?environment=$environmentId';
}
