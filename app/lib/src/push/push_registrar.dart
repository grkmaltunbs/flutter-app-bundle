import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Phone only. Puts this phone on the list the Mac pushes to: asks the
/// system for permission (Android 13 and up prompt), takes the FCM token,
/// writes it under `devices/{token}`, and rewrites it when it changes.
///
/// The platform calls are injectable so a test runs it without Firebase
/// Messaging.
class PushRegistrar extends ChangeNotifier {
  PushRegistrar(
    this.db, {
    Future<bool> Function()? requestPermission,
    Future<String?> Function()? getToken,
    Stream<String>? tokenRefresh,
    String? Function()? uid,
    String? platform,
    String? deviceName,
  })  : _requestPermission = requestPermission ?? _askSystem,
        _getToken = getToken ?? (() => FirebaseMessaging.instance.getToken()),
        _tokenRefresh = tokenRefresh ?? FirebaseMessaging.instance.onTokenRefresh,
        _uid = uid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        platform = platform ?? Platform.operatingSystem,
        deviceName = deviceName ?? '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.trim();

  final FirebaseFirestore db;
  final Future<bool> Function() _requestPermission;
  final Future<String?> Function() _getToken;
  final Stream<String> _tokenRefresh;
  final String? Function() _uid;
  final String platform;
  final String deviceName;
  StreamSubscription<String>? _refresh;

  String? token;
  bool allowed = false;
  String status = 'Notifications: not set up yet';
  String? error;

  bool get registered => token != null && allowed;

  /// Asks, registers, and keeps registering. Safe to call again — it
  /// re-asks the system and rewrites the row.
  Future<void> register() async {
    try {
      allowed = await _requestPermission();
      if (!allowed) {
        status = 'Notifications are off — allow them for K.A.T.Y.A in the phone\'s settings to hear when Claude needs you';
        error = null;
        notifyListeners();
        return;
      }
      final t = await _getToken();
      if (t == null || t.isEmpty) throw StateError('no token from Firebase Messaging');
      await _write(t);
      _refresh ??= _tokenRefresh.listen((t) => _write(t).catchError(_fail));
      status = 'Notifications on — this phone hears when Claude asks, needs a sign-in, or hits a problem';
      error = null;
    } on Object catch (e) {
      _fail(e);
    }
    notifyListeners();
  }

  Future<void> _write(String t) async {
    final ref = db.collection('devices').doc(t);
    final exists = (await ref.get()).exists;
    await ref.set({
      'platform': platform,
      'name': deviceName,
      if (_uid() != null) 'uid': _uid(),
      'seenAt': FieldValue.serverTimestamp(),
      if (!exists) 'registeredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    token = t;
    notifyListeners();
  }

  void _fail(Object e) {
    error = e.toString();
    status = 'Notifications could not be set up: $e';
    notifyListeners();
  }

  static Future<bool> _askSystem() async {
    final s = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    return s.authorizationStatus == AuthorizationStatus.authorized || s.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }
}

/// What a tapped notification opens: the project, and which ask if any.
class PushTap {
  const PushTap({required this.slug, required this.kind, this.requestId});
  final String slug;
  final String kind;
  final String? requestId;

  /// Null when the message carries no project — nothing to open.
  static PushTap? from(Map<String, Object?> data) {
    final slug = (data['slug'] ?? '').toString();
    if (slug.isEmpty) return null;
    final rid = data['requestId']?.toString();
    return PushTap(slug: slug, kind: (data['kind'] ?? '').toString(), requestId: rid == null || rid.isEmpty ? null : rid);
  }
}
