import 'package:flutter/material.dart';

import 'auth/auth_repository.dart';
import 'routing/app_router.dart';

class CareNavApp extends StatelessWidget {
  const CareNavApp({
    required this.authRepository,
    this.initialLocation,
    super.key,
  });

  final AuthRepository authRepository;
  final String? initialLocation;

  @override
  Widget build(BuildContext context) {
    final router = createAppRouter(
      authRepository,
      initialLocation: initialLocation,
    );

    return MaterialApp.router(
      title: 'CareNav',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF236C63)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
