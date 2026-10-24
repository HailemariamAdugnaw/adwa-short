import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/formatters.dart';

class StarRating extends StatefulWidget {
  const StarRating({
    super.key,
    this.currentRating = 0,
    this.averageRating,
    this.ratingCount,
    this.onRatingChanged,
    this.size = 24,
    this.interactive = false,
    this.showNumeric = false,
    this.spacing = 4,
    this.activeColor,
    this.inactiveColor,
  });

  final int currentRating;
  final double? averageRating;
  final int? ratingCount;
  final ValueChanged<int>? onRatingChanged;
  final double size;
  final bool interactive;
  final bool showNumeric;
  final double spacing;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> {
  int _hoverStars = 0;

  int get _displayValue {
    if (widget.interactive) {
      return _hoverStars > 0 ? _hoverStars : widget.currentRating;
    }
    if (widget.averageRating != null) {
      return widget.averageRating!.round().clamp(0, 5);
    }
    return widget.currentRating;
  }

  double get _fillFraction {
    if (widget.interactive) return 1.0;
    if (widget.averageRating != null) {
      final v = widget.averageRating!.clamp(0.0, 5.0);
      return v - v.floor();
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final stars = _buildStars();
    if (!widget.showNumeric) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: stars,
      );
    }
    final avg = widget.averageRating;
    final count = widget.ratingCount;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...stars,
        if (avg != null || count != null) ...[
          SizedBox(width: widget.spacing + 2),
          Text(
            _numericLabel(avg, count),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  String _numericLabel(double? avg, int? count) {
    if (avg != null && count != null) {
      return '${avg.toStringAsFixed(1)} ★ (${Formatters.compact(count)} ratings)';
    }
    if (avg != null) return '${avg.toStringAsFixed(1)} ★';
    if (count != null) return '${Formatters.compact(count)} ratings';
    return '';
  }

  List<Widget> _buildStars() {
    final displayValue = _displayValue;
    final fillFraction = _fillFraction;
    final List<Widget> stars = [];
    for (var i = 1; i <= 5; i++) {
      final bool full = i <= displayValue;
      final bool partial = !full && i == displayValue + 1 && fillFraction > 0;
      stars.add(
        Padding(
          padding: EdgeInsets.only(right: i == 5 ? 0 : widget.spacing),
          child: widget.interactive
              ? GestureDetector(
                  onTap: () => _onTap(i),
                  onTapDown: (_) => _onHover(i),
                  onTapUp: (_) => _onHover(0),
                  onTapCancel: () => _onHover(0),
                  behavior: HitTestBehavior.opaque,
                  child: _star(
                    index: i,
                    filled: full,
                    partial: false,
                  ),
                )
              : _star(
                  index: i,
                  filled: full,
                  partial: partial,
                  partialFraction: partial ? fillFraction : 0,
                ),
        ),
      );
    }
    return stars;
  }

  Widget _star({
    required int index,
    required bool filled,
    bool partial = false,
    double partialFraction = 0,
  }) {
    final active = widget.activeColor ?? AppColors.bloodRed;
    final inactive = widget.inactiveColor ?? AppColors.textTertiary;
    final double size = widget.size;
    if (partial) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Icon(Icons.star_rounded, color: inactive, size: size),
            ClipRect(
              clipper: _StarClipper(fraction: partialFraction.clamp(0.0, 1.0)),
              child:
                  Icon(Icons.star_rounded, color: active, size: size),
            ),
          ],
        ),
      );
    }
    return Icon(
      filled ? Icons.star_rounded : Icons.star_border_rounded,
      color: filled ? active : inactive,
      size: size,
    );
  }

  void _onTap(int value) {
    HapticFeedback.selectionClick();
    widget.onRatingChanged?.call(value);
    setState(() => _hoverStars = 0);
  }

  void _onHover(int value) {
    if (!mounted) return;
    setState(() => _hoverStars = value);
  }
}

class _StarClipper extends CustomClipper<Rect> {
  _StarClipper({required this.fraction});
  final double fraction;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * fraction, size.height);
  }

  @override
  bool shouldReclip(covariant _StarClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}
