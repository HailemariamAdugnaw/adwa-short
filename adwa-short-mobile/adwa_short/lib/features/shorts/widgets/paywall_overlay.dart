import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/short_item.dart';
import '../../auth/providers/auth_provider.dart';

/// Highly polished, cinematic single-screen Paywall Overlay matching the
/// exact reference design (Pure Black, Glowing Blood Red, High-Contrast White).
class PaywallOverlay extends StatefulWidget {
  const PaywallOverlay({
    super.key,
    required this.item,
    this.onUnlockAds,
    this.onBuyCoins,
    this.onBuyPass,
    this.onSubscribe,
    this.onMaybeLater,
    this.isBottomSheet = false,
  });

  final ShortItem item;
  final VoidCallback? onUnlockAds;
  final VoidCallback? onBuyCoins;
  final VoidCallback? onBuyPass;
  final VoidCallback? onSubscribe;
  final VoidCallback? onMaybeLater;
  final bool isBottomSheet;

  static Future<void> showModal(
    BuildContext context, {
    required ShortItem item,
    VoidCallback? onUnlockAds,
    VoidCallback? onBuyCoins,
    VoidCallback? onBuyPass,
    VoidCallback? onSubscribe,
    VoidCallback? onMaybeLater,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => PaywallOverlay(
        item: item,
        isBottomSheet: true,
        onUnlockAds: onUnlockAds,
        onBuyCoins: onBuyCoins,
        onBuyPass: onBuyPass,
        onSubscribe: onSubscribe,
        onMaybeLater: onMaybeLater ?? () => Navigator.of(ctx).maybePop(),
      ),
    );
  }

  @override
  State<PaywallOverlay> createState() => _PaywallOverlayState();
}

class _PaywallOverlayState extends State<PaywallOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseGlow;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseGlow = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool _isGuestSession(BuildContext context) {
    try {
      final auth = Provider.of<AuthProvider?>(context, listen: false);
      if (auth != null) {
        return !auth.isAuthenticated;
      }
    } catch (_) {}
    return widget.item.accessReason == 'need_login';
  }

  String _episodeHeader() {
    final sTitle = widget.item.seriesTitle?.trim() ?? '';
    final eTitle = widget.item.title.trim();
    if (sTitle.isNotEmpty && eTitle.isNotEmpty) {
      if (sTitle == eTitle) return sTitle;
      return '$sTitle · $eTitle';
    }
    if (sTitle.isNotEmpty) return sTitle;
    if (eTitle.isNotEmpty) return eTitle;
    if (widget.item.episodeNumber != null) {
      return 'Episode ${widget.item.episodeNumber}';
    }
    return 'Episode';
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = _isGuestSession(context);
    final coinCost = widget.item.coinCost > 0 ? widget.item.coinCost : 50;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 680;
        final lockSize = isCompact ? 56.0 : 68.0;
        final headerSpacing = isCompact ? 6.0 : 10.0;
        final pillSpacing = isCompact ? 5.0 : 8.0;
        final cardTopSpacing = isCompact ? 8.0 : 12.0;

        final sheetContent = Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F080A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: const Color(0xFFFF1E27),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55FF1744),
                blurRadius: 28,
                spreadRadius: 2,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                isCompact ? 8 : 12,
                16,
                isCompact ? 10 : 14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle Pill
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 8 : 10),

                  // Top Centered Pulsing Red Lock Badge
                  _buildPulsingLockBadge(lockSize),
                  SizedBox(height: headerSpacing),

                  // Episode Header: "Series · Series - Episode X"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _episodeHeader(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 14.5 : 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  SizedBox(height: pillSpacing),

                  // Compact Red-Bordered "Locked" Pill Badge
                  _buildLockedBadge(),
                  SizedBox(height: cardTopSpacing),

                  // The Glowing Cyber Card Frame
                  _buildCyberCard(
                    isGuest: isGuest,
                    coinCost: coinCost,
                    isCompact: isCompact,
                  ),
                ],
              ),
            ),
          ),
        );

        if (widget.isBottomSheet) {
          return sheetContent;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // Semi-transparent dimmed backdrop
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onMaybeLater,
              child: Container(
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),

            // Subtle Diagonal Red Light Ribbons/Streaks behind sheet
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PaywallWavePainter(),
                ),
              ),
            ),

            // Bottom-anchored responsive bottom sheet container
            Align(
              alignment: Alignment.bottomCenter,
              child: sheetContent,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPulsingLockBadge(double size) {
    return AnimatedBuilder(
      animation: _pulseGlow,
      builder: (context, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1744)
                    .withValues(alpha: 0.45 * _pulseGlow.value),
                blurRadius: 36 * _pulseGlow.value,
                spreadRadius: 3 * _pulseGlow.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [
              Color(0xFF45060E),
              Color(0xFF220306),
              Color(0xFF100103),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFF1E27),
            width: 1.8,
          ),
        ),
        child: Icon(
          Icons.lock_rounded,
          color: Colors.white,
          size: size * 0.42,
        ),
      ),
    );
  }

  Widget _buildLockedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF140204),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF1E27),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44FF1744),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_rounded,
            size: 13,
            color: Color(0xFFFF1E27),
          ),
          SizedBox(width: 6),
          Text(
            'Locked',
            style: TextStyle(
              color: Color(0xFFFF1E27),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCyberCard({
    required bool isGuest,
    required int coinCost,
    required bool isCompact,
  }) {
    final rowSpacing = isCompact ? 7.0 : 9.0;
    final rowHeight = isCompact ? 46.0 : 50.0;

    return CustomPaint(
      painter: const _CyberCardPainter(),
      child: Container(
        padding: EdgeInsets.fromLTRB(16, isCompact ? 14 : 18, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 28,
                  color: Color(0xFFFF1E27),
                  shadows: [
                    Shadow(
                      color: Color(0xAAFF1744),
                      blurRadius: 10,
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Unlock Episode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      // Conditional Subtitle: ONLY rendered if session is in Guest Mode
                      if (isGuest) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'Sign in or register to unlock episodes.',
                          style: TextStyle(
                            color: Color(0xFFC08085),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isCompact ? 10 : 14),

            // Option 1: Unlock via Ads (Watch Ad)
            if (widget.onUnlockAds != null) ...[
              _buildPricingRow(
                height: rowHeight,
                leadingIcon: _buildCircleIcon(
                  icon: Icons.play_arrow_rounded,
                  iconColor: Colors.white,
                  bgColor: const Color(0xFFFF1E27),
                ),
                title: 'Unlock via Ads (Watch Ad)',
                badgeText: 'FREE',
                isSolidRedBadge: true,
                onTap: widget.onUnlockAds,
              ),
              SizedBox(height: rowSpacing),
            ],

            // Option 2: Unlock with Coins (50 Coins)
            _buildPricingRow(
              height: rowHeight,
              leadingIcon: _buildStackedCoinsIcon(),
              title: 'Unlock with Coins ($coinCost Coins)',
              badgeText: '$coinCost COINS',
              isSolidRedBadge: false,
              onTap: widget.onBuyCoins,
            ),
            SizedBox(height: rowSpacing),

            // Option 3: Buy Time Pass
            _buildPricingRow(
              height: rowHeight,
              leadingIcon: _buildCircleIcon(
                icon: Icons.access_time_filled_rounded,
                iconColor: Colors.white,
                bgColor: const Color(0xFFFF1E27),
              ),
              title: 'Buy Time Pass',
              badgeText: 'UNLIMITED',
              isSolidRedBadge: false,
              onTap: widget.onBuyPass,
            ),
            SizedBox(height: rowSpacing),

            // Option 4: Subscribe
            _buildPricingRow(
              height: rowHeight,
              leadingIcon: _buildCircleIcon(
                icon: Icons.military_tech_rounded,
                iconColor: Colors.white,
                bgColor: const Color(0xFFFF1E27),
              ),
              title: 'Subscribe',
              badgeText: 'BEST VALUE',
              isSolidRedBadge: false,
              onTap: widget.onSubscribe,
            ),
            SizedBox(height: isCompact ? 10 : 14),

            // Footer Action: Centered "Maybe later" with thin red divider lines
            _buildFooterAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIcon({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x66FF1744),
            blurRadius: 6,
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 19,
        color: iconColor,
      ),
    );
  }

  Widget _buildStackedCoinsIcon() {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      child: const CustomPaint(
        size: Size(22, 20),
        painter: _StackedCoinsPainter(),
      ),
    );
  }

  Widget _buildPricingRow({
    required double height,
    required Widget leadingIcon,
    required String title,
    required String badgeText,
    required bool isSolidRedBadge,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: const Color(0xFFFF1E27).withValues(alpha: 0.25),
        highlightColor: const Color(0xFFFF1E27).withValues(alpha: 0.1),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1E0306),
                Color(0xFF0C0102),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFF1E27),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33FF1744),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              leadingIcon,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isSolidRedBadge
                      ? const Color(0xFFFF1E27)
                      : const Color(0xFF150204),
                  borderRadius: BorderRadius.circular(14),
                  border: isSolidRedBadge
                      ? null
                      : Border.all(
                          color: const Color(0xFFFF1E27),
                          width: 1.2,
                        ),
                  boxShadow: isSolidRedBadge
                      ? const [
                          BoxShadow(
                            color: Color(0x66FF1744),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: isSolidRedBadge
                            ? Colors.white
                            : const Color(0xFFFF1E27),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: isSolidRedBadge
                          ? Colors.white
                          : const Color(0xFFFF1E27),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterAction() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0x88FF1E27),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GestureDetector(
            onTap: widget.onMaybeLater,
            behavior: HitTestBehavior.translucent,
            child: const Text(
              'Maybe later',
              style: TextStyle(
                color: Color(0xFFFF2A3B),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x88FF1E27),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints the futuristic cyber frame with glowing Blood Red neon borders
/// and the stepped top notch cutout matching the reference image.
class _CyberCardPainter extends CustomPainter {
  const _CyberCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const r = 20.0;

    final path = Path();
    path.moveTo(r, 0);

    // Top edge with cyber notch tab (at x ~ 28% to 48%)
    path.lineTo(w * 0.28, 0);
    path.lineTo(w * 0.33, 6);
    path.lineTo(w * 0.44, 6);
    path.lineTo(w * 0.49, 0);
    path.lineTo(w - r, 0);

    // Top-Right rounded corner
    path.arcToPoint(Offset(w, r), radius: const Radius.circular(r));

    // Right edge
    path.lineTo(w, h - r);

    // Bottom-Right rounded corner
    path.arcToPoint(Offset(w - r, h), radius: const Radius.circular(r));

    // Bottom edge
    path.lineTo(r, h);

    // Bottom-Left rounded corner
    path.arcToPoint(Offset(0, h - r), radius: const Radius.circular(r));

    // Left edge
    path.lineTo(0, r);

    // Top-Left rounded corner
    path.arcToPoint(const Offset(r, 0), radius: const Radius.circular(r));
    path.close();

    // 1. Outer Neon Glow Shadow
    final glowPaint = Paint()
      ..color = const Color(0x55FF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(path, glowPaint);

    // 2. Card Background Fill (Deep Black-Red)
    final fillPaint = Paint()
      ..color = const Color(0xFF070102)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 3. Neon Red Border
    final borderPaint = Paint()
      ..color = const Color(0xFFFF1E27)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path, borderPaint);

    // 4. Tech Accent Bar inside the notch
    final accentPaint = Paint()
      ..color = const Color(0xFFFF1E27)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(w * 0.32, 2.5),
      Offset(w * 0.42, 2.5),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints the two red stacked coins for the coin unlock row.
class _StackedCoinsPainter extends CustomPainter {
  const _StackedCoinsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()
      ..color = const Color(0xFFFF1E27)
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = const Color(0xFFFF4D5A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Bottom Coin
    final bottomRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.65),
      width: size.width * 0.78,
      height: size.height * 0.36,
    );
    canvas.drawOval(bottomRect, paintFill);
    canvas.drawOval(bottomRect, paintStroke);

    // Top Coin
    final topRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.35),
      width: size.width * 0.78,
      height: size.height * 0.36,
    );
    canvas.drawOval(topRect, paintFill);
    canvas.drawOval(topRect, paintStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints the diagonal curved red light ribbons in top-left & bottom-right corners.
class _PaywallWavePainter extends CustomPainter {
  const _PaywallWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- TOP-LEFT CORNER WAVE ---
    final pathTop = Path();
    pathTop.moveTo(0, h * 0.16);
    pathTop.cubicTo(w * 0.12, h * 0.12, w * 0.28, h * 0.04, w * 0.38, 0);
    pathTop.lineTo(0, 0);
    pathTop.close();

    final paintTop = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x55C8102E),
          Color(0x228B0010),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w * 0.4, h * 0.2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(pathTop, paintTop);

    final strokePathTop = Path();
    strokePathTop.moveTo(0, h * 0.14);
    strokePathTop.cubicTo(w * 0.12, h * 0.10, w * 0.26, h * 0.03, w * 0.36, 0);

    final strokePaintTop = Paint()
      ..color = const Color(0x66FF1E27)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(strokePathTop, strokePaintTop);

    // --- BOTTOM-RIGHT CORNER WAVE ---
    final pathBottom = Path();
    pathBottom.moveTo(w, h * 0.84);
    pathBottom.cubicTo(w * 0.88, h * 0.88, w * 0.72, h * 0.96, w * 0.62, h);
    pathBottom.lineTo(w, h);
    pathBottom.close();

    final paintBottom = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [
          Color(0x55C8102E),
          Color(0x228B0010),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(w * 0.6, h * 0.8, w * 0.4, h * 0.2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(pathBottom, paintBottom);

    final strokePathBottom = Path();
    strokePathBottom.moveTo(w, h * 0.86);
    strokePathBottom.cubicTo(
        w * 0.88, h * 0.90, w * 0.74, h * 0.97, w * 0.64, h);

    final strokePaintBottom = Paint()
      ..color = const Color(0x66FF1E27)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(strokePathBottom, strokePaintBottom);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
