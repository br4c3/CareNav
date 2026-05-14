import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/auth/auth_repository.dart';
import 'src/auth/firebase_auth_repository.dart';
import 'src/auth/local_auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authRepository = await _createAuthRepository();

  runApp(CareNavApp(authRepository: authRepository));
}

Future<AuthRepository> _createAuthRepository() async {
  try {
    await Firebase.initializeApp();
    return FirebaseAuthRepository(FirebaseAuth.instance);
  } catch (_) {
    return LocalAuthRepository();
  }
}
