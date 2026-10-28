import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Highly polished 'Connection Lost' error screen widget matching the
/// ADWA SHORT dark cinematic brand identity (Black, Blood Red, High-Contrast White).
class ConnectionLostView extends StatefulWidget {
  const ConnectionLostView({
    super.key,
    this.onRetry,
    this.title = 'Connection Lost',
    this.subtitle = "Can't connect to server, please try\nagain later.",
    this.buttonText = 'Try Again',
    this.isFullScreen = false,
  });

  final Future<void> Function()? onRetry;
  final String title;
  final String subtitle;
  final String buttonText;
  final bool isFullScreen;

  @override
  State<ConnectionLostView> createState() => _ConnectionLostViewState();
}

class _ConnectionLostViewState extends State<ConnectionLostView>
    with SingleTickerProviderStateMixin {
  bool _isRetrying = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    if (_isRetrying || widget.onRetry == null) return;
    HapticFeedback.lightImpact();
    setState(() => _isRetrying = true);
    try {
      await widget.onRetry!();
    } catch (_) {
      // Errors handled by caller or state listener
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 560;
        final graphicWidth = isCompact ? 160.0 : 240.0;
        final graphicHeight = isCompact ? 145.0 : 220.0;
        final topSpacing = isCompact ? 16.0 : 36.0;
        final subtitleSpacing = isCompact ? 8.0 : 14.0;
        final buttonSpacing = isCompact ? 20.0 : 38.0;

        return Stack(
          children: [
            // Corner diagonal blood red light streak accents
            const Positioned.fill(
              child: CustomPaint(
                painter: CornerStreaksPainter(),
              ),
            ),

            // Main centered content
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: isCompact ? 16 : 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Disconnected 3D-styled glossy Wi-Fi graphic with neon floor ring & X badge
                    SizedBox(
                      width: graphicWidth,
                      height: graphicHeight,
                      child: const CustomPaint(
                        painter: WifiDisconnectedPainter(),
                      ),
                    ),
                    SizedBox(height: topSpacing),

                    // Main Title: "Connection " in bold white, "Lost" in vibrant Blood Red
                    _buildTitle(),
                    SizedBox(height: subtitleSpacing),

                    // Subtitle
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFB0B0B0),
                        fontSize: isCompact ? 13.5 : 15,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        letterSpacing: 0.1,
                      ),
                    ),
                    SizedBox(height: buttonSpacing),

                    // Action Button: Rounded glossy pill button with red neon glow & gradient
                    if (widget.onRetry != null)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: child,
                          );
                        },
                        child: _buildRetryButton(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    if (widget.isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: content),
      );
    }

    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: content,
    );
  }

  Widget _buildTitle() {
    // If the title contains "Lost", style "Lost" in Blood Red
    if (widget.title.contains('Lost')) {
      final parts = widget.title.split('Lost');
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            fontFamily: 'Roboto',
          ),
          children: [
            TextSpan(
              text: parts.first,
              style: const TextStyle(color: Colors.white),
            ),
            const TextSpan(
              text: 'Lost',
              style: TextStyle(
                color: Color(0xFFFF1E27),
                shadows: [
                  Shadow(
                    color: Color(0x66FF1744),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
            if (parts.length > 1)
              TextSpan(
                text: parts.sublist(1).join('Lost'),
                style: const TextStyle(color: Colors.white),
              ),
          ],
        ),
      );
    }

    return Text(
      widget.title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildRetryButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isRetrying ? null : _handleRetry,
        borderRadius: BorderRadius.circular(28),
        splashColor: Colors.white.withValues(alpha: 0.15),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            // Crimson to deep blood-red gradient fill
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE50914),
                Color(0xFF8B0010),
              ],
            ),
            // Vibrant red neon border stroke
            border: Border.all(
              color: const Color(0xFFFF334B),
              width: 1.5,
            ),
            // Vibrant red neon glow outer halo
            boxShadow: const [
              BoxShadow(
                color: Color(0x99FF1744),
                blurRadius: 20,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Color(0x44FF1E27),
                blurRadius: 32,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reload/retry circular arrow icon
              if (_isRetrying)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 22,
                ),

              // Thin vertical divider line
              Container(
                width: 1,
                height: 18,
                color: Colors.white.withValues(alpha: 0.35),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),

              // Button Text
              Text(
                widget.buttonText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standalone full-screen route wrapper for [ConnectionLostView].
class ConnectionLostScreen extends StatelessWidget {
  const ConnectionLostScreen({
    super.key,
    this.onRetry,
    this.title = 'Connection Lost',
    this.subtitle = "Can't connect to server, please try\nagain later.",
  });

  final Future<void> Function()? onRetry;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ConnectionLostView(
      onRetry: onRetry,
      title: title,
      subtitle: subtitle,
      isFullScreen: true,
    );
  }
}

/// Paints the diagonal blood red light streak accents in top-left and bottom-right corners.
class CornerStreaksPainter extends CustomPainter {
  const CornerStreaksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- TOP-LEFT CORNER STREAKS ---
    // Soft ambient red radial glow
    final tlGlowPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x66FF1744),
          Color(0x22C8102E),
          Colors.transparent,
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(const Rect.fromLTWH(-170, -170, 340, 340))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(Offset.zero, 160, tlGlowPaint);

    // Primary laser streak 1
    final tlStreak1 = Path()
      ..moveTo(-20, 60)
      ..lineTo(60, -20)
      ..lineTo(95, -20)
      ..lineTo(-20, 95)
      ..close();
    final tlPaint1 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF1E27),
          Color(0xFF8B0010),
          Colors.transparent,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 110, 110));
    canvas.drawPath(tlStreak1, tlPaint1);

    // Secondary accent streak 2
    final tlStreak2 = Path()
      ..moveTo(-15, 120)
      ..lineTo(120, -15)
      ..lineTo(135, -15)
      ..lineTo(-15, 135)
      ..close();
    final tlPaint2 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xCCFF1744),
          Color(0x558B0010),
          Colors.transparent,
        ],
        stops: [0.0, 0.6, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 140, 140));
    canvas.drawPath(tlStreak2, tlPaint2);

    // --- BOTTOM-RIGHT CORNER STREAKS ---
    // Soft ambient red radial glow
    final brGlowPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x66FF1744),
          Color(0x22C8102E),
          Colors.transparent,
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(w, h), radius: 170))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(Offset(w, h), 160, brGlowPaint);

    // Primary laser streak 1
    final brStreak1 = Path()
      ..moveTo(w + 20, h - 60)
      ..lineTo(w - 60, h + 20)
      ..lineTo(w - 95, h + 20)
      ..lineTo(w + 20, h - 95)
      ..close();
    final brPaint1 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: const [
          Color(0xFFFF1E27),
          Color(0xFF8B0010),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(w - 110, h - 110, 110, 110));
    canvas.drawPath(brStreak1, brPaint1);

    // Secondary accent streak 2
    final brStreak2 = Path()
      ..moveTo(w + 15, h - 120)
      ..lineTo(w - 120, h + 15)
      ..lineTo(w - 135, h + 15)
      ..lineTo(w + 15, h - 135)
      ..close();
    final brPaint2 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: const [
          Color(0xCCFF1744),
          Color(0x558B0010),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(w - 140, h - 140, 140, 140));
    canvas.drawPath(brStreak2, brPaint2);
  }

  @override
  bool shouldRepaint(covariant CornerStreaksPainter oldDelegate) => false;
}

/// Custom painter for the 3D-styled glossy metallic Wi-Fi icon with
/// floor neon ellipse, floor reflection, neon orbital ring, and red 'X' notification badge.
class WifiDisconnectedPainter extends CustomPainter {
  const WifiDisconnectedPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.46;
    final floorY = cy + 48.0;

    // ==========================================
    // 1. FLOOR LIGHT BLOOM & REFLECTION
    // ==========================================
    // Floor ambient radial red bloom
    final floorGlowShader = const RadialGradient(
      colors: [
        Color(0x99FF1744),
        Color(0x33C8102E),
        Colors.transparent,
      ],
      stops: [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCenter(
      center: Offset(cx, floorY),
      width: 220,
      height: 55,
    ));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, floorY), width: 190, height: 46),
      Paint()..shader = floorGlowShader,
    );

    // Floor reflection of bottom dot & lower arc
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, floorY, size.width, size.height));
    final reflectDotShader = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.18),
        const Color(0x446B7280),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(
      center: Offset(cx, floorY + (floorY - cy)),
      radius: 9,
    ));
    canvas.drawCircle(
      Offset(cx, floorY + (floorY - cy)),
      8.5,
      Paint()..shader = reflectDotShader,
    );
    canvas.restore();

    // Floor neon ring outer glow
    final floorRingRect = Rect.fromCenter(center: Offset(cx, floorY), width: 125, height: 20);
    canvas.drawOval(
      floorRingRect,
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Floor neon ring sharp stroke
    canvas.drawOval(
      floorRingRect,
      Paint()
        ..color = const Color(0xFFFF334B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    // Floor neon ring core white highlight
    canvas.drawOval(
      floorRingRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // ==========================================
    // 2. TILTED NEON ORBITAL RING AROUND WI-FI
    // ==========================================
    canvas.save();
    canvas.translate(cx, cy - 12);
    canvas.rotate(-0.40); // Tilted ~ -23 degrees
    final orbitRect = Rect.fromCenter(center: Offset.zero, width: 170, height: 52);

    // Wide outer neon bloom
    canvas.drawOval(
      orbitRect,
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Sharp neon ring
    canvas.drawOval(
      orbitRect,
      Paint()
        ..color = const Color(0xFFFF2A3D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    // Core white hot laser streak
    canvas.drawOval(
      orbitRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.restore();

    // ==========================================
    // 3. 3D GLOSSY METALLIC WI-FI ARCS
    // ==========================================
    // Concentric arcs radiating upward from (cx, cy)
    // Straight up is -pi / 2 radians. Sweep is 1.62 rad (~93 degrees).
    const sweep = 1.62;
    const startAngle = -math.pi / 2 - (sweep / 2);

    const arcs = [
      _ArcSpec(radius: 66.0, strokeWidth: 12.0),
      _ArcSpec(radius: 46.0, strokeWidth: 11.0),
      _ArcSpec(radius: 27.0, strokeWidth: 10.0),
    ];

    for (final arc in arcs) {
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: arc.radius);
      final shadowRect = Rect.fromCircle(center: Offset(cx, cy + 3.0), radius: arc.radius);

      // Layer A: 3D Dark Underneath Bevel / Shadow
      canvas.drawArc(
        shadowRect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = const Color(0xFF0D0F12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = arc.strokeWidth + 0.5
          ..strokeCap = StrokeCap.round,
      );

      // Layer B: Main Metallic Gunmetal Body
      final bodyShader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF5E6573), // Specular light metallic
          Color(0xFF2E323B), // Gunmetal body
          Color(0xFF14161A), // Deep shadow base
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);

      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..shader = bodyShader
          ..style = PaintingStyle.stroke
          ..strokeWidth = arc.strokeWidth
          ..strokeCap = StrokeCap.round,
      );

      // Layer C: Gloss Specular Top Rim Sheen
      final highlightRect = Rect.fromCircle(
        center: Offset(cx, cy - 0.6),
        radius: arc.radius + (arc.strokeWidth * 0.28),
      );
      canvas.drawArc(
        highlightRect,
        startAngle + 0.12,
        sweep - 0.24,
        false,
        Paint()
          ..color = const Color(0xFFE8EEF5).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }

    // ==========================================
    // 4. METALLIC CENTER DOT / SPHERE
    // ==========================================
    // Drop shadow
    canvas.drawCircle(
      Offset(cx, cy + 2.2),
      8.5,
      Paint()..color = const Color(0xFF0A0C0E),
    );

    // 3D Metallic Sphere Shader
    final dotShader = const RadialGradient(
      center: Alignment(-0.35, -0.4),
      radius: 0.9,
      colors: [
        Color(0xFFFFFFFF),
        Color(0xFF7E8794),
        Color(0xFF2C3038),
        Color(0xFF101215),
      ],
      stops: [0.0, 0.35, 0.75, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 8.5));

    canvas.drawCircle(
      Offset(cx, cy),
      8.5,
      Paint()..shader = dotShader,
    );

    // Specular shine pin on dot
    canvas.drawCircle(
      Offset(cx - 2.5, cy - 2.8),
      2.0,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // ==========================================
    // 5. GLOWING BLOOD-RED NOTIFICATION BADGE (X)
    // ==========================================
    // Overlaid on the right side of the Wi-Fi arcs
    final badgeX = cx + 37.0;
    final badgeY = cy - 2.0;
    const badgeR = 17.5;

    // Outer Red Neon Bloom
    canvas.drawCircle(
      Offset(badgeX, badgeY),
      badgeR + 9.0,
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Outer sharp neon border
    canvas.drawCircle(
      Offset(badgeX, badgeY),
      badgeR + 1.0,
      Paint()
        ..color = const Color(0xFFFF334B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Glossy 3D Red Badge Body
    final badgeShader = const RadialGradient(
      center: Alignment(-0.35, -0.45),
      radius: 0.95,
      colors: [
        Color(0xFFFF3B49),
        Color(0xFFE50914),
        Color(0xFF880010),
      ],
      stops: [0.0, 0.6, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(badgeX, badgeY), radius: badgeR));

    canvas.drawCircle(
      Offset(badgeX, badgeY),
      badgeR,
      Paint()..shader = badgeShader,
    );

    // Glass / Specular Sheen on Upper Half of Badge
    final glossRect = Rect.fromCenter(
      center: Offset(badgeX, badgeY - 5.5),
      width: 21,
      height: 10,
    );
    final glossShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: 0.6),
        Colors.white.withValues(alpha: 0.0),
      ],
    ).createShader(glossRect);

    canvas.drawOval(
      glossRect,
      Paint()..shader = glossShader,
    );

    // Bold Crisp White 'X' in Center
    const armDelta = 5.6;
    final xPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(badgeX - armDelta, badgeY - armDelta),
      Offset(badgeX + armDelta, badgeY + armDelta),
      xPaint,
    );
    canvas.drawLine(
      Offset(badgeX + armDelta, badgeY - armDelta),
      Offset(badgeX - armDelta, badgeY + armDelta),
      xPaint,
    );
  }

  @override
  bool shouldRepaint(covariant WifiDisconnectedPainter oldDelegate) => false;
}

class _ArcSpec {
  const _ArcSpec({required this.radius, required this.strokeWidth});
  final double radius;
  final double strokeWidth;
}
