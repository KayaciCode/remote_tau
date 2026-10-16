import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class TouchpadWidget extends StatefulWidget {
  final Function(double dx, double dy) onMove;
  final Function(String btn) onClick;
  final Function(double dy) onScroll;

  const TouchpadWidget({
    Key? key,
    required this.onMove,
    required this.onClick,
    required this.onScroll,
  }) : super(key: key);

  @override
  State<TouchpadWidget> createState() => _TouchpadWidgetState();
}

class _TouchpadWidgetState extends State<TouchpadWidget> with SingleTickerProviderStateMixin {
  Offset? _lastPanPos;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D121D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GestureDetector(
          onScaleStart: (details) {
            _lastPanPos = details.focalPoint;
          },
          onScaleUpdate: (details) {
            if (_lastPanPos == null) return;
            final dx = details.focalPoint.dx - _lastPanPos!.dx;
            final dy = details.focalPoint.dy - _lastPanPos!.dy;

            if (details.pointerCount == 1) {
              // Mouse Move with Acceleration
              final speed = math.sqrt(dx * dx + dy * dy);
              final accel = speed > 8 ? 1.5 : 1.0;
              widget.onMove(dx * accel, dy * accel);
            } else if (details.pointerCount == 2) {
              // 2-Finger Scroll
              widget.onScroll(dy);
            }
            _lastPanPos = details.focalPoint;
          },
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onClick('left');
          },
          onSecondaryTap: () {
            HapticFeedback.mediumImpact();
            widget.onClick('right');
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Laser Grid Background Painter
              Positioned.fill(
                child: CustomPaint(
                  painter: LaserGridPainter(),
                ),
              ),

              // 2. Central Glowing Target Ripple
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + _pulseController.value * 0.15;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentCyan.withOpacity(0.12),
                        border: Border.all(
                          color: AppTheme.accentCyan.withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentCyan.withOpacity(0.4),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.touch_app,
                        color: AppTheme.accentCyan,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),

              // 3. Subtitle Label
              Positioned(
                bottom: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: const Text(
                    "Touch to control",
                    style: TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LaserGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = AppTheme.accentCyan.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
