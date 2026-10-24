import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../core/widgets/adwa_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _autovalidate = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = true);
      return;
    }
    final ok = await context.read<AuthProvider>().login(
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed('/main');
    } else {
      _showError(context.read<AuthProvider>().errorMessage ?? 'Login failed');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bloodRedDark, AppColors.black],
              stops: [0.0, 0.35],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Form(
              key: _formKey,
              autovalidateMode: _autovalidate
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _brand(),
                  const SizedBox(height: 36),
                  Text('Welcome back', style: AppTextStyles.display3),
                  const SizedBox(height: 6),
                  Text('Log in to continue streaming',
                      style: AppTextStyles.body2),
                  const SizedBox(height: 28),
                  AdwaTextField(
                    controller: _phoneController,
                    label: 'Phone',
                    hint: 'e.g. 0912345678',
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_outlined,
                        color: AppColors.textTertiary, size: 20),
                    validator: Validators.phone,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  AdwaTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter your password',
                    obscure: true,
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.textTertiary, size: 20),
                    validator: Validators.password,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showError('Password reset is not available yet.');
                      },
                      child: Text(
                        'Forgot password?',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.bloodRedBright),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AdwaButton(
                    label: 'Log In',
                    icon: Icons.login_rounded,
                    loading: auth.status == AuthStatus.loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ",
                          style: AppTextStyles.body2),
                      GestureDetector(
                        onTap: () => Navigator.of(context)
                            .pushReplacementNamed('/register'),
                        child: Text(
                          'Register',
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.bloodRedBright),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.bloodRed,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.play_arrow_rounded,
              color: AppColors.white, size: 40),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: AppTextStyles.brandLogo.copyWith(fontSize: 28),
            children: const [
              TextSpan(text: 'ADWA', style: TextStyle(color: AppColors.white)),
              TextSpan(
                  text: ' SHORT',
                  style: TextStyle(color: AppColors.bloodRedBright)),
            ],
          ),
        ),
      ],
    );
  }
}
