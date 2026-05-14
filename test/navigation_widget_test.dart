import 'package:care_nav/src/app.dart';
import 'package:care_nav/src/auth/app_user.dart';
import 'package:care_nav/src/auth/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guest users can search and start navigation', (tester) async {
    final auth = FakeAuthRepository();

    await tester.pumpWidget(CareNavApp(authRepository: auth));
    await tester.enterText(
      find.byKey(const ValueKey('destinationSearchField')),
      '약국',
    );
    await tester.pump();
    expect(find.byType(FlutterMap), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mapMarker-pharmacy')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -280));
    await tester.pumpAndSettle();

    expect(find.text('경로 안내'), findsOneWidget);
    expect(find.textContaining('약국'), findsWidgets);
    expect(find.byKey(const ValueKey('nextStepButton')), findsOneWidget);
  });
}

class FakeAuthRepository extends AuthRepository {
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _user = AppUser(id: 'fake-user', email: email);
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _user = null;
    notifyListeners();
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    _user = AppUser(id: 'fake-user', email: email);
    notifyListeners();
  }
}
