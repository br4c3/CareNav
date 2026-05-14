import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'app_user.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository extends AuthRepository {
  FirebaseAuthRepository(this._firebaseAuth) {
    _user = _firebaseAuth.currentUser?.toAppUser();
    _subscription = _firebaseAuth.authStateChanges().listen((user) {
      _user = user?.toAppUser();
      notifyListeners();
    });
  }

  final FirebaseAuth _firebaseAuth;
  late final StreamSubscription<User?> _subscription;
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> signIn({required String email, required String password}) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signUp({required String email, required String password}) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

extension on User {
  AppUser toAppUser() {
    return AppUser(id: uid, email: email);
  }
}
