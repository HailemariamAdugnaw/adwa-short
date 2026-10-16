class Validators {
  Validators._();

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Phone number is required';
    final pattern = RegExp(r'^\+?\d{9,15}$');
    if (!pattern.hasMatch(v.replaceAll(RegExp(r'\s+'), ''))) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Display name is required';
    if (v.length < 2) return 'Display name is too short';
    if (v.length > 40) return 'Display name is too long';
    return null;
  }

  static String? amount(String? value, {num min = 1}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Amount is required';
    final n = num.tryParse(v);
    if (n == null) return 'Enter a valid amount';
    if (n < min) return 'Minimum is $min';
    return null;
  }

  static String? required(String? value, {String label = 'This field'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final pattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!pattern.hasMatch(v)) return 'Enter a valid email';
    return null;
  }
}
