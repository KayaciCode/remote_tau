import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlowGaugeWidget extends StatelessWidget {
  final String title;
  final double percent;
  final String valueText;
  final String subtitle;
  final Color color;
  final bool isDark;

  const GlowGaugeWidget({
    Key? key,
    required this.title,
    required this.percent,
    required this.valueText,
    required this.subtitle,
    required this.color,
    this.isDark = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.07 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(isDark ? 0.25 : 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(64, 64),
                  painter: GaugePainter(percent: percent, color: color, isDark: isDark),
                ),
                Text(
                  "${percent.toInt()}%",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: color,
                  shadows: isDark
                      ? [
                          Shadow(color: color.withOpacity(0.5), blurRadius: 10),
                        ]
                      : null,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double percent;
  final Color color;
  final bool isDark;

  GaugePainter({
    required this.percent,
    required this.color,
    this.isDark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    const startAngle = -math.pi * 1.25;
    const sweepTotal = math.pi * 1.5;

    // Track
    final trackPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.08) : const Color(0x18000000)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    // Active Glow Arc
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.0;

    final activeSweep = sweepTotal * (percent.clamp(0.0, 100.0) / 100.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.color != color || oldDelegate.isDark != isDark;
}

