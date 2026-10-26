import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class AdwaButton extends StatefulWidget {
  const AdwaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconRight,
    this.loading = false,
    this.disabled = false,
    this.expanded = true,
    this.variant = AdwaButtonVariant.primary,
    this.size = AdwaButtonSize.md,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? iconRight;
  final bool loading;
  final bool disabled;
  final bool expanded;
  final AdwaButtonVariant variant;
  final AdwaButtonSize size;

  @override
  State<AdwaButton> createState() => _AdwaButtonState();
}

class _AdwaButtonState extends State<AdwaButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || widget.loading;
    final canTap = !isDisabled && widget.onPressed != null;

    final palette = _paletteFor(widget.variant, isDisabled);
    final padding = _paddingFor(widget.size);
    final fontSize = _fontSizeFor(widget.size);

    final child = Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: widget.loading ? 0 : 1,
          child: Row(
            mainAxisSize:
                widget.expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: palette.foreground, size: fontSize + 4),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    color: palette.foreground,
                    fontSize: fontSize,
                  ),
                ),
              ),
              if (widget.iconRight != null) ...[
                const SizedBox(width: 8),
                Icon(widget.iconRight,
                    color: palette.foreground, size: fontSize + 4),
              ],
            ],
          ),
        ),
        if (widget.loading)
          SizedBox(
            height: fontSize + 6,
            width: fontSize + 6,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(palette.foreground),
            ),
          ),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: canTap ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(
            minWidth: widget.expanded ? double.infinity : 0,
            minHeight: _minHeightFor(widget.size),
          ),
          padding: padding,
          decoration: BoxDecoration(
            color: palette.background,
            gradient: palette.gradient,
            borderRadius: BorderRadius.circular(10),
            border: palette.border,
            boxShadow: _shadowFor(widget.variant, _hovering, isDisabled),
          ),
          child: child,
        ),
      ),
    );
  }

  _AdwaButtonPalette _paletteFor(AdwaButtonVariant v, bool disabled) {
    if (disabled) {
      return _AdwaButtonPalette(
        background: AppColors.surfaceElevated,
        foreground: AppColors.textDisabled,
      );
    }
    switch (v) {
      case AdwaButtonVariant.primary:
        return _AdwaButtonPalette(
          background: AppColors.bloodRed,
          foreground: AppColors.white,
          gradient: AppColors.bloodRedGradient,
        );
      case AdwaButtonVariant.secondary:
        return _AdwaButtonPalette(
          background: AppColors.surfaceElevated,
          foreground: AppColors.textPrimary,
          border: Border.all(color: AppColors.border, width: 1.2),
        );
      case AdwaButtonVariant.outline:
        return _AdwaButtonPalette(
          background: Colors.transparent,
          foreground: AppColors.bloodRed,
          border: Border.all(color: AppColors.bloodRed, width: 1.4),
        );
      case AdwaButtonVariant.ghost:
        return _AdwaButtonPalette(
          background: Colors.transparent,
          foreground: AppColors.textPrimary,
        );
    }
  }

  EdgeInsets _paddingFor(AdwaButtonSize size) {
    switch (size) {
      case AdwaButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case AdwaButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 22, vertical: 14);
      case AdwaButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 28, vertical: 18);
    }
  }

  double _fontSizeFor(AdwaButtonSize size) {
    switch (size) {
      case AdwaButtonSize.sm:
        return 13;
      case AdwaButtonSize.md:
        return 15;
      case AdwaButtonSize.lg:
        return 17;
    }
  }

  double _minHeightFor(AdwaButtonSize size) {
    switch (size) {
      case AdwaButtonSize.sm:
        return 40;
      case AdwaButtonSize.md:
        return 50;
      case AdwaButtonSize.lg:
        return 58;
    }
  }

  List<BoxShadow>? _shadowFor(
      AdwaButtonVariant v, bool hovering, bool disabled) {
    if (disabled) return null;
    if (v == AdwaButtonVariant.primary && hovering) {
      return const [
        BoxShadow(
          color: AppColors.bloodRedGlow,
          blurRadius: 18,
          offset: Offset(0, 4),
        ),
      ];
    }
    return null;
  }
}

enum AdwaButtonVariant { primary, secondary, outline, ghost }

enum AdwaButtonSize { sm, md, lg }

class _AdwaButtonPalette {
  _AdwaButtonPalette({
    required this.background,
    required this.foreground,
    this.gradient,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Gradient? gradient;
  final Border? border;
}
