import 'package:flutter/foundation.dart';

import 'app_user.dart';

abstract class AuthRepository extends ChangeNotifier {
  AppUser? get currentUser;

  bool get isSignedIn => currentUser != null;

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({required String email, required String password});

  Future<void> signOut();
}
