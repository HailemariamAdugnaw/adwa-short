import 'package:flutter/material.dart';

import 'auth_screen.dart';

export 'auth_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen(initialMode: AuthScreenMode.login);
  }
}
