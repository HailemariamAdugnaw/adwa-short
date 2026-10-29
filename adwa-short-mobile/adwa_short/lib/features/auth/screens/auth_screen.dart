import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/app_state_provider.dart';
import '../../profile/providers/wallet_provider.dart';
import '../providers/auth_provider.dart';

enum AuthScreenMode { login, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.initialMode = AuthScreenMode.login,
  });

  final AuthScreenMode initialMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AuthScreenMode _currentMode;
  late final AnimationController _tabAnimController;

  // Login Form
  final _loginFormKey = GlobalKey<FormState>();
  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginAutovalidate = false;
  bool _loginObscurePassword = true;

  // Register Form
  final _registerFormKey = GlobalKey<FormState>();
  final _regDisplayNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regPasswordController = TextEditingController();
  bool _regAutovalidate = false;
  bool _regObscurePassword = true;

  // Focus tracking for glowing focus border
  final _loginPhoneFocus = FocusNode();
  final _loginPasswordFocus = FocusNode();
  final _regNameFocus = FocusNode();
  final _regPhoneFocus = FocusNode();
  final _regPasswordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _tabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: _currentMode == AuthScreenMode.login ? 0.0 : 1.0,
    );

    // Rebuild on focus changes to animate glowing red borders
    _loginPhoneFocus.addListener(() => setState(() {}));
    _loginPasswordFocus.addListener(() => setState(() {}));
    _regNameFocus.addListener(() => setState(() {}));
    _regPhoneFocus.addListener(() => setState(() {}));
    _regPasswordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabAnimController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _regDisplayNameController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();

    _loginPhoneFocus.dispose();
    _loginPasswordFocus.dispose();
    _regNameFocus.dispose();
    _regPhoneFocus.dispose();
    _regPasswordFocus.dispose();
    super.dispose();
  }

  void _switchMode(AuthScreenMode mode) {
    if (_currentMode == mode) return;
    setState(() => _currentMode = mode);
    if (mode == AuthScreenMode.login) {
      _tabAnimController.reverse();
    } else {
      _tabAnimController.forward();
    }
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      setState(() => _loginAutovalidate = true);
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      phone: _loginPhoneController.text.trim(),
      password: _loginPasswordController.text,
    );
    if (!mounted) return;
    if (ok) {
      _onAuthSuccess(auth);
    } else {
      _showError(auth.errorMessage ?? 'Login failed. Please check your credentials.');
    }
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) {
      setState(() => _regAutovalidate = true);
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      phone: _regPhoneController.text.trim(),
      password: _regPasswordController.text,
      displayName: _regDisplayNameController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      _onAuthSuccess(auth);
    } else {
      _showError(auth.errorMessage ?? 'Registration failed. Please try again.');
    }
  }

  void _onAuthSuccess(AuthProvider auth) {
    context.read<AppStateProvider>().syncFromAuth(auth);
    try {
      final wp = context.read<WalletProvider>();
      wp.loadWallet(refresh: true);
      wp.loadAccessDashboard(refresh: true);
    } catch (_) {}

    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(true);
    } else {
      nav.pushReplacementNamed(AppRoutes.main);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _continueAsGuest() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.continueAsGuest();
    } catch (_) {}

    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(false);
    } else {
      nav.pushReplacementNamed(AppRoutes.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final args = ModalRoute.of(context)?.settings.arguments;
    final String? promptMessage = args is Map
        ? (args['message'] as String?)
        : (args is String ? args : null);

    final isLogin = _currentMode == AuthScreenMode.login;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.black,
            gradient: RadialGradient(
              center: Alignment(-0.8, -0.6),
              radius: 1.3,
              colors: [
                Color(0x3AC8102E),
                Color(0x10000000),
                AppColors.black,
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Bar: Back & Centered Brand Header
                            _buildTopBar(),
                            const SizedBox(height: 24),

                            // Optional contextual prompt message banner
                            if (promptMessage != null && promptMessage.isNotEmpty) ...[
                              _buildPromptBanner(promptMessage),
                              const SizedBox(height: 18),
                            ],

                            // Animated Sliding Tab Switcher
                            _buildSlidingTabSwitcher(),
                            const SizedBox(height: 28),

                            // Animated Form Content with Centered Headings
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: isLogin
                                  ? _buildLoginForm(auth)
                                  : _buildRegisterForm(auth),
                            ),
                          ],
                        ),

                        // Bottom Section: Continue as Guest
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 28),
                            _buildGuestReturnShortcut(),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (Navigator.of(context).canPop())
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.white, size: 24),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            else
              const SizedBox(width: 48),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bloodRed,
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF2A3B),
                    AppColors.bloodRed,
                    AppColors.bloodRedDark,
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x77C8102E),
                    blurRadius: 22,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: AppColors.white, size: 36),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 14),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTextStyles.brandLogo.copyWith(fontSize: 26, letterSpacing: 1.2),
            children: const [
              TextSpan(text: 'ADWA', style: TextStyle(color: AppColors.white)),
              TextSpan(
                text: ' SHORT',
                style: TextStyle(color: AppColors.bloodRedBright),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromptBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF19070A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bloodRed, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44C8102E),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.bloodRedBright,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidingTabSwitcher() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262626), width: 1),
      ),
      child: AnimatedBuilder(
        animation: _tabAnimController,
        builder: (context, _) {
          return Stack(
            children: [
              // Sliding Red Pill Indicator
              Align(
                alignment: Alignment(
                  -1.0 + (_tabAnimController.value * 2.0),
                  0.0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF2535),
                          AppColors.bloodRed,
                          AppColors.bloodRedDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66E50914),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Tab Labels Row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _switchMode(AuthScreenMode.login),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            color: _currentMode == AuthScreenMode.login
                                ? AppColors.white
                                : const Color(0xFF9E9E9E),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _switchMode(AuthScreenMode.register),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            color: _currentMode == AuthScreenMode.register
                                ? AppColors.white
                                : const Color(0xFF9E9E9E),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoginForm(AuthProvider auth) {
    final isLoading = auth.status == AuthStatus.loading;

    return Form(
      key: _loginFormKey,
      autovalidateMode: _loginAutovalidate
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      child: Column(
        key: const ValueKey('login_form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Centered Main Heading
          Text(
            'Welcome Back',
            textAlign: TextAlign.center,
            style: AppTextStyles.h1.copyWith(
              color: AppColors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Log in to continue streaming',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Phone Field
          _buildInputField(
            label: 'PHONE NUMBER',
            controller: _loginPhoneController,
            focusNode: _loginPhoneFocus,
            hint: 'e.g. 0912345678',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: Validators.phone,
          ),
          const SizedBox(height: 16),

          // Password Field
          _buildInputField(
            label: 'PASSWORD',
            controller: _loginPasswordController,
            focusNode: _loginPasswordFocus,
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            obscure: _loginObscurePassword,
            textInputAction: TextInputAction.done,
            validator: Validators.password,
            onSubmitted: (_) => _submitLogin(),
            suffix: IconButton(
              icon: Icon(
                _loginObscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF888888),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _loginObscurePassword = !_loginObscurePassword),
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showError('Password reset is not available yet.'),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: AppColors.bloodRedBright,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Submit Button (Glossy Blood Red Pill)
          _buildSubmitPillButton(
            label: 'Log In',
            icon: Icons.login_rounded,
            isLoading: isLoading,
            onTap: _submitLogin,
          ),

          const SizedBox(height: 18),

          // Bottom switch link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
              ),
              GestureDetector(
                onTap: () => _switchMode(AuthScreenMode.register),
                child: const Text(
                  'Register',
                  style: TextStyle(
                    color: AppColors.bloodRedBright,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(AuthProvider auth) {
    final isLoading = auth.status == AuthStatus.loading;

    return Form(
      key: _registerFormKey,
      autovalidateMode: _regAutovalidate
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      child: Column(
        key: const ValueKey('register_form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Centered Main Heading
          Text(
            'Create Account',
            textAlign: TextAlign.center,
            style: AppTextStyles.h1.copyWith(
              color: AppColors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Join ADWA SHORT in seconds',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Display Name Field
          _buildInputField(
            label: 'DISPLAY NAME',
            controller: _regDisplayNameController,
            focusNode: _regNameFocus,
            hint: 'e.g. Selam A.',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: Validators.displayName,
          ),
          const SizedBox(height: 14),

          // Phone Field
          _buildInputField(
            label: 'PHONE NUMBER',
            controller: _regPhoneController,
            focusNode: _regPhoneFocus,
            hint: 'e.g. 0912345678',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: Validators.phone,
          ),
          const SizedBox(height: 14),

          // Password Field
          _buildInputField(
            label: 'PASSWORD',
            controller: _regPasswordController,
            focusNode: _regPasswordFocus,
            hint: 'At least 6 characters',
            icon: Icons.lock_outline_rounded,
            obscure: _regObscurePassword,
            textInputAction: TextInputAction.done,
            validator: Validators.password,
            onSubmitted: (_) => _submitRegister(),
            suffix: IconButton(
              icon: Icon(
                _regObscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF888888),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _regObscurePassword = !_regObscurePassword),
            ),
          ),
          const SizedBox(height: 22),

          // Submit Button (Glossy Blood Red Pill)
          _buildSubmitPillButton(
            label: 'Create Account',
            icon: Icons.person_add_alt_1_rounded,
            isLoading: isLoading,
            onTap: _submitRegister,
          ),

          const SizedBox(height: 18),

          // Bottom switch link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Already have an account? ',
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
              ),
              GestureDetector(
                onTap: () => _switchMode(AuthScreenMode.login),
                child: const Text(
                  'Log In',
                  style: TextStyle(
                    color: AppColors.bloodRedBright,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
    Widget? suffix,
  }) {
    final hasFocus = focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFDDDDDD),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasFocus ? AppColors.bloodRedBright : const Color(0xFF282828),
              width: hasFocus ? 1.6 : 1.2,
            ),
            boxShadow: hasFocus
                ? const [
                    BoxShadow(
                      color: Color(0x55E50914),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            validator: validator,
            onFieldSubmitted: onSubmitted,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: AppColors.bloodRedBright,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 14),
              prefixIcon: Icon(
                icon,
                color: hasFocus ? AppColors.bloodRedBright : const Color(0xFF888888),
                size: 20,
              ),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitPillButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF2535),
              AppColors.bloodRed,
              AppColors.bloodRedDark,
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77E50914),
              blurRadius: 18,
              spreadRadius: 1,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGuestReturnShortcut() {
    return Center(
      child: TextButton(
        onPressed: _continueAsGuest,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Continue as Guest',
              style: TextStyle(
                color: Color(0xFFB0B0B0),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.bloodRedBright,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
