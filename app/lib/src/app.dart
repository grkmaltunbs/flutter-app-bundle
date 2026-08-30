import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Step, StepState;

import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';
import 'theme.dart';

/// The shell. One codebase, two roles: on macOS (and later Windows) it is
/// the **host** — it reads `plan/` from disk, spawns the user's own Claude
/// Code and mirrors everything to the relay project; on a phone it is the
/// **remote** — it reads the mirror and sends batches back.
bool get isHost => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

class KitApp extends StatelessWidget {
  const KitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K.A.T.Y.A',
      debugShowCheckedModeBanner: false,
      theme: kitTheme(KitTokens.light),
      darkTheme: kitTheme(KitTokens.dark),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.data == null) return const SignInScreen();
          return const HomeScreen();
        },
      ),
    );
  }
}
