import 'package:go_router/go_router.dart';

import '../auth/auth_repository.dart';
import '../features/auth/login_page.dart';
import '../features/auth/signup_page.dart';
import '../features/home/home_page.dart';
import 'app_routes.dart';

GoRouter createAppRouter(
  AuthRepository authRepository, {
  String? initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation ?? AppRoutes.home,
    refreshListenable: authRepository,
    redirect: (context, state) {
      final isSignedIn = authRepository.isSignedIn;
      final path = state.uri.path;
      final isAuthRoute = path == AppRoutes.login || path == AppRoutes.signUp;

      if (isSignedIn && isAuthRoute) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginPage(authRepository: authRepository),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => SignUpPage(authRepository: authRepository),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => HomePage(authRepository: authRepository),
      ),
    ],
  );
}
