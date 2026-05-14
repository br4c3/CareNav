import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import 'auth_form.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CareNav')),
      body: AuthForm(authRepository: authRepository, mode: AuthFormMode.signUp),
    );
  }
}
