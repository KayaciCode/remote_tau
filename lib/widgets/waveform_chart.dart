import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaveformChartWidget extends StatelessWidget {
  final String title;
  final String valueText;
  final List<double> points;
  final Color color;
  final double maxValue;
  final bool isDark;

  const WaveformChartWidget({
    Key? key,
    required this.title,
    required this.valueText,
    required this.points,
    required this.color,
    this.maxValue = 100.0,
    this.isDark = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textSecondary),
              ),
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 38,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(points: points, color: color, maxValue: maxValue, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final double maxValue;
  final bool isDark;

  WaveformPainter({
    required this.points,
    required this.color,
    required this.maxValue,
    this.isDark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Draw background grid lines
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.04) : const Color(0x0E000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), gridPaint);

    final strokePath = Path();
    final fillPath = Path();

    final stepX = size.width / (points.length - 1);

    List<Offset> offsets = [];
    for (int i = 0; i < points.length; i++) {
      final y = size.height - (points[i] / maxValue * size.height).clamp(2.0, size.height - 2.0);
      offsets.add(Offset(i * stepX, y));
    }

    strokePath.moveTo(offsets[0].dx, offsets[0].dy);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i > 0 ? i - 1 : 0];
      final p1 = offsets[i];
      final p2 = offsets[i + 1];
      final p3 = offsets[i + 2 < offsets.length ? i + 2 : offsets.length - 1];

      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6.0, p1.dy + (p2.dy - p0.dy) / 6.0);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6.0, p2.dy - (p3.dy - p1.dy) / 6.0);

      strokePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw Gradient Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(isDark ? 0.35 : 0.22),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw Top Stroke
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8;

    canvas.drawPath(strokePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}

