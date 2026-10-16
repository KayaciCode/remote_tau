import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RadarWidget extends StatefulWidget {
  final double size;
  final bool isDark;

  const RadarWidget({Key? key, this.size = 150, this.isDark = true}) : super(key: key);

  @override
  State<RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: RadarPainter(progress: _controller.value, isDark: widget.isDark),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center Host Node
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGreen.withOpacity(0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.desktop_windows, size: 13, color: Colors.white),
                ),
                // Target Blips
                Positioned(
                  top: widget.size * 0.20,
                  left: widget.size * 0.22,
                  child: _buildBlip("iPhone 16 Pro", Icons.phone_iphone, AppTheme.accentCyan),
                ),
                Positioned(
                  bottom: widget.size * 0.22,
                  right: widget.size * 0.20,
                  child: _buildBlip("iPad Pro M4", Icons.tablet_mac, AppTheme.accentPurple),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlip(String label, IconData icon, Color col) {
    return Tooltip(
      message: label,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: col.withOpacity(0.25),
          shape: BoxShape.circle,
          border: Border.all(color: col, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: col.withOpacity(0.5),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, size: 11, color: col),
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  RadarPainter({required this.progress, this.isDark = true});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 1. Concentric Circles
    final ringPaint = Paint()
      ..color = AppTheme.accentGreen.withOpacity(isDark ? 0.22 : 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3.0), ringPaint);
    }

    // 2. Crosshairs
    final linePaint = Paint()
      ..color = AppTheme.accentGreen.withOpacity(isDark ? 0.15 : 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), linePaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), linePaint);

    // 3. Expanding Pulse Ripples
    final pulseProgress1 = (progress * 2) % 1.0;
    final pulseRadius1 = pulseProgress1 * maxRadius;
    final pulsePaint1 = Paint()
      ..color = AppTheme.accentGreen.withOpacity((1.0 - pulseProgress1) * (isDark ? 0.45 : 0.35))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, pulseRadius1, pulsePaint1);

    // 4. Conical Sweep Shader / Arc
    final sweepAngle = progress * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          AppTheme.accentGreen.withOpacity(0.0),
          AppTheme.accentGreen.withOpacity(isDark ? 0.35 : 0.25),
        ],
        transform: GradientRotation(sweepAngle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // 5. Leading Sweep Line
    final sweepLinePaint = Paint()
      ..color = AppTheme.accentGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final lineEnd = Offset(
      center.dx + maxRadius * math.cos(sweepAngle),
      center.dy + maxRadius * math.sin(sweepAngle),
    );
    canvas.drawLine(center, lineEnd, sweepLinePaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) => true;
}

