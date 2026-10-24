import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class AdwaTextField extends StatefulWidget {
  const AdwaTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.maxLength,
    this.inputFormatters,
    this.fillColor,
    this.borderColor,
    this.contentPadding,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Color? fillColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? contentPadding;

  @override
  State<AdwaTextField> createState() => _AdwaTextFieldState();
}

class _AdwaTextFieldState extends State<AdwaTextField> {
  late bool _obscure;
  bool _hasFocus = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscure;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus != _hasFocus) {
        setState(() => _hasFocus = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.borderColor ??
        (_hasFocus ? AppColors.bloodRed : AppColors.border);

    Widget? suffix = widget.suffixIcon;
    if (widget.obscure) {
      suffix = IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AppColors.textTertiary,
          size: 20,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTextStyles.label
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: widget.fillColor ?? AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: _hasFocus
                ? const [
                    BoxShadow(
                      color: AppColors.bloodRedGlow,
                      blurRadius: 12,
                      offset: Offset(0, 0),
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            validator: widget.validator,
            onFieldSubmitted: widget.onFieldSubmitted,
            onChanged: widget.onChanged,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            style: AppTextStyles.body1.copyWith(color: AppColors.textPrimary),
            cursorColor: AppColors.bloodRed,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle:
                  AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
              prefixIcon: widget.prefixIcon,
              suffixIcon: suffix,
              counterText: '',
              contentPadding: widget.contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Colors.transparent,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.error, width: 1.6),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.error, width: 1.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
