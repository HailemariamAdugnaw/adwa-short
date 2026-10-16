import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/star_rating.dart';
import '../providers/review_provider.dart';

class ReviewInput extends StatefulWidget {
  const ReviewInput({
    super.key,
    required this.episodeId,
    this.maxChars,
    this.onSubmitted,
    this.showStarSelector = true,
  });

  final String episodeId;
  final int? maxChars;
  final VoidCallback? onSubmitted;
  final bool showStarSelector;

  @override
  State<ReviewInput> createState() => _ReviewInputState();
}

class _ReviewInputState extends State<ReviewInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  int _stars = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _max =>
      widget.maxChars ??
      context.read<ReviewProvider>().maxChars;

  bool get _isValid {
    final t = _controller.text.trim();
    return t.isNotEmpty && t.length <= _max;
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    final provider = context.read<ReviewProvider>();
    final ok = await provider.submitReview(
      widget.episodeId,
      _controller.text,
      rating: widget.showStarSelector && _stars > 0 ? _stars : null,
    );
    if (!mounted) return;
    if (ok) {
      _controller.clear();
      setState(() {
        _stars = 0;
      });
      _focus.unfocus();
      widget.onSubmitted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (provider.submitError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.submitError!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReviewProvider>();
    final max = _max;
    final text = _controller.text;
    final over = text.length > max;
    final submitting = provider.isSubmitting(widget.episodeId);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_rounded,
                  color: AppColors.bloodRed, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Write a review',
                  style: AppTextStyles.label,
                ),
              ),
              if (widget.showStarSelector)
                StarRating(
                  currentRating: _stars,
                  interactive: true,
                  size: 22,
                  onRatingChanged: (v) => setState(() {
                    _stars = v;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            focusNode: _focus,
            maxLength: max + 50,
            minLines: 2,
            maxLines: 4,
            style: AppTextStyles.body2.copyWith(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Share your thoughts about this episode…',
              hintStyle: AppTextStyles.body2
                  .copyWith(color: AppColors.textTertiary),
              counterText: '',
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: over ? AppColors.error : AppColors.border,
                    width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: over ? AppColors.error : AppColors.bloodRed,
                    width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${text.length} / $max',
                style: AppTextStyles.caption.copyWith(
                  color: over
                      ? AppColors.error
                      : (text.isEmpty
                          ? AppColors.textTertiary
                          : AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              AdwaButton(
                label: submitting ? 'Posting…' : 'Post Review',
                onPressed: (_isValid && !submitting) ? _submit : null,
                disabled: !_isValid || submitting,
                loading: submitting,
                expanded: false,
                size: AdwaButtonSize.sm,
                icon: Icons.send_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget reviewAvatar(String? url, {double size = 36}) {
  final resolved = ApiClient.resolveMediaUrl(url);
  if (resolved.isEmpty) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.bloodRed.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded,
          color: AppColors.bloodRed, size: size * 0.55),
    );
  }
  return ClipOval(
    child: CachedNetworkImage(
      imageUrl: resolved,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => LoadingShimmer(
        width: size,
        height: size,
        borderRadius: size / 2,
      ),
      errorWidget: (_, __, ___) => Container(
        width: size,
        height: size,
        color: AppColors.surfaceElevated,
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded,
            color: AppColors.textTertiary, size: size * 0.55),
      ),
    ),
  );
}
