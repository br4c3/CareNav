import 'package:care_nav/src/app.dart';
import 'package:care_nav/src/auth/app_user.dart';
import 'package:care_nav/src/auth/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth navigation', () {
    testWidgets('signed out users can start on home as guests', (tester) async {
      final auth = FakeAuthRepository();

      await tester.pumpWidget(CareNavApp(authRepository: auth));

      expect(find.text('홈'), findsOneWidget);
      expect(find.textContaining('게스트'), findsOneWidget);
      expect(find.byKey(const ValueKey('signOutButton')), findsNothing);
      expect(find.byKey(const ValueKey('goToLoginButton')), findsOneWidget);
    });

    testWidgets('signed in users start on home', (tester) async {
      final auth = FakeAuthRepository.signedIn();

      await tester.pumpWidget(CareNavApp(authRepository: auth));

      expect(find.text('홈'), findsOneWidget);
      expect(find.textContaining('user@example.com'), findsOneWidget);
    });

    testWidgets('login signs in and redirects home', (tester) async {
      final auth = FakeAuthRepository();

      await tester.pumpWidget(
        CareNavApp(authRepository: auth, initialLocation: '/login'),
      );
      await tester.enterText(
        find.byKey(const ValueKey('emailField')),
        'tester@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('passwordField')),
        'password123',
      );
      await tester.tap(find.byKey(const ValueKey('loginButton')));
      await tester.pumpAndSettle();

      expect(auth.lastSignInEmail, 'tester@example.com');
      expect(find.text('홈'), findsOneWidget);
      expect(find.textContaining('tester@example.com'), findsOneWidget);
    });

    testWidgets('login page can navigate to sign up', (tester) async {
      final auth = FakeAuthRepository();

      await tester.pumpWidget(
        CareNavApp(authRepository: auth, initialLocation: '/login'),
      );
      await tester.tap(find.text('계정 만들기'));
      await tester.pumpAndSettle();

      expect(find.text('회원가입'), findsWidgets);
    });

    testWidgets('sign up creates an account and redirects home', (
      tester,
    ) async {
      final auth = FakeAuthRepository();

      await tester.pumpWidget(
        CareNavApp(authRepository: auth, initialLocation: '/login'),
      );
      await tester.tap(find.text('계정 만들기'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('emailField')),
        'new@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('passwordField')),
        'password123',
      );
      await tester.tap(find.byKey(const ValueKey('signUpButton')));
      await tester.pumpAndSettle();

      expect(auth.lastSignUpEmail, 'new@example.com');
      expect(find.text('홈'), findsOneWidget);
      expect(find.textContaining('new@example.com'), findsOneWidget);
    });

    testWidgets('sign out returns to guest home', (tester) async {
      final auth = FakeAuthRepository.signedIn();

      await tester.pumpWidget(CareNavApp(authRepository: auth));
      await tester.tap(find.byKey(const ValueKey('signOutButton')));
      await tester.pumpAndSettle();

      expect(find.text('홈'), findsOneWidget);
      expect(find.textContaining('게스트'), findsOneWidget);
      expect(find.byKey(const ValueKey('goToLoginButton')), findsOneWidget);
    });
  });
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({AppUser? initialUser}) : _user = initialUser;

  FakeAuthRepository.signedIn()
    : _user = const AppUser(id: 'user-1', email: 'user@example.com');

  AppUser? _user;
  String? lastSignInEmail;
  String? lastSignUpEmail;

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> signIn({required String email, required String password}) async {
    lastSignInEmail = email;
    _user = AppUser(id: 'signed-in-user', email: email);
    notifyListeners();
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    lastSignUpEmail = email;
    _user = AppUser(id: 'new-user', email: email);
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _user = null;
    notifyListeners();
  }
}
