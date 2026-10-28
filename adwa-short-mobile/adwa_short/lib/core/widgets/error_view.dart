import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'connection_lost_view.dart';

/// App-wide error presentation component.
///
/// For full-page / section states, this renders the dedicated, highly polished
/// [ConnectionLostView] with the 3D-styled glossy Wi-Fi graphic, glowing red
/// notification circle, neon rings, floor reflections, and red neon 'Try Again' pill button.
///
/// For compact inline views (e.g. inside small cards or lists), it displays
/// a sleek brand-compliant blood-red / black compact error banner.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
    this.icon = Icons.error_outline_rounded,
    this.title,
    this.forceConnectionLostStyle = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;
  final IconData icon;
  final String? title;
  final bool forceConnectionLostStyle;

  static bool isConnectionError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('connect') ||
        lower.contains('server') ||
        lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('host lookup') ||
        lower.contains('offline') ||
        lower.contains('failed to load') ||
        lower.contains('failed to fetch') ||
        lower.contains('unavailable');
  }

  @override
  Widget build(BuildContext context) {
    // In full (non-compact) mode, display the visual ConnectionLostView
    if (!compact || forceConnectionLostStyle) {
      return ConnectionLostView(
        onRetry: onRetry != null ? () async => onRetry!() : null,
        title: title ?? 'Connection Lost',
        subtitle: message.isNotEmpty && isConnectionError(message)
            ? "Can't connect to server, please try\nagain later."
            : message,
      );
    }

    // Compact inline error view (for cards / small embedded zones)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bloodRed.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bloodRed.withValues(alpha: 0.18),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bloodRed.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.bloodRed,
                width: 1.0,
              ),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFFF1E27),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Connection Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE50914), Color(0xFF8B0010)],
                    ),
                    border: Border.all(
                      color: const Color(0xFFFF334B),
                      width: 1.0,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Retry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
