import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_repository.dart';
import '../../routing/app_routes.dart';

enum AuthFormMode { login, signUp }

class AuthForm extends StatefulWidget {
  const AuthForm({required this.authRepository, required this.mode, super.key});

  final AuthRepository authRepository;
  final AuthFormMode mode;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSubmitting = false;
  String? _error;

  bool get _isLogin => widget.mode == AuthFormMode.login;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_isLogin) {
        await widget.authRepository.signIn(email: email, password: password);
      } else {
        await widget.authRepository.signUp(email: email, password: password);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '인증 처리 중 문제가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? '로그인' : '회원가입';
    final alternateText = _isLogin ? '계정 만들기' : '로그인으로 돌아가기';
    final alternateRoute = _isLogin ? AppRoutes.signUp : AppRoutes.login;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('emailField'),
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    prefixIcon: Icon(Icons.mail_outline),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty || !email.contains('@')) {
                      return '올바른 이메일을 입력하세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('passwordField'),
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if ((value ?? '').length < 6) {
                      return '비밀번호는 6자 이상이어야 합니다.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  key: ValueKey(_isLogin ? 'loginButton' : 'signUpButton'),
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isLogin ? Icons.login : Icons.person_add_alt),
                  label: Text(title),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(alternateRoute),
                  child: Text(alternateText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
