import 'app_user.dart';
import 'auth_repository.dart';

class LocalAuthRepository extends AuthRepository {
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _user = AppUser(id: 'local-user', email: email);
    notifyListeners();
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    _user = AppUser(id: 'local-user', email: email);
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _user = null;
    notifyListeners();
  }
}
