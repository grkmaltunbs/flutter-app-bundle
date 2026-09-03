import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/push/local_notices.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // An Android phone draws the Mac's data messages itself — app in the
  // background or closed — so Allow and Deny sit on the notification.
  if (Platform.isAndroid) FirebaseMessaging.onBackgroundMessage(kitBackgroundMessage);
  runApp(const KitApp());
}
