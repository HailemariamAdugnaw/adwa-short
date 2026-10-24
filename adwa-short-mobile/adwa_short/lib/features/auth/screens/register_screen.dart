import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../core/widgets/adwa_text_field.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _autovalidate = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = true);
      return;
    }
    final ok = await context.read<AuthProvider>().register(
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed('/main');
    } else {
      final msg =
          context.read<AuthProvider>().errorMessage ?? 'Registration failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                  const SizedBox(height: 28),
                  Text('Create your account', style: AppTextStyles.display3),
                  const SizedBox(height: 6),
                  Text('Join ADWA SHORT in seconds', style: AppTextStyles.body2),
                  const SizedBox(height: 24),
                  AdwaTextField(
                    controller: _displayNameController,
                    label: 'Display Name',
                    hint: 'e.g. Selam A.',
                    textCapitalization: TextCapitalization.words,
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        color: AppColors.textTertiary, size: 20),
                    validator: Validators.displayName,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
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
                    hint: 'At least 6 characters',
                    obscure: true,
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.textTertiary, size: 20),
                    validator: Validators.password,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  AdwaButton(
                    label: 'Create Account',
                    icon: Icons.person_add_alt_1_rounded,
                    loading: auth.status == AuthStatus.loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account? ',
                          style: AppTextStyles.body2),
                      GestureDetector(
                        onTap: () => Navigator.of(context)
                            .pushReplacementNamed('/login'),
                        child: Text(
                          'Log In',
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
