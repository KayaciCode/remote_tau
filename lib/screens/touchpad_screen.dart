import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/websocket_service.dart';

class TouchpadScreen extends StatefulWidget {
  const TouchpadScreen({super.key});

  @override
  State<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends State<TouchpadScreen> {
  final WebSocketService _ws = WebSocketService();
  double _sensitivity = 1.2;

  Offset _lastPosition = Offset.zero;
  int _pointerCount = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main Touchpad Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Listener(
              onPointerDown: (event) {
                _pointerCount++;
                _lastPosition = event.position;
              },
              onPointerMove: (event) {
                final dx = (event.position.dx - _lastPosition.dx) * _sensitivity;
                final dy = (event.position.dy - _lastPosition.dy) * _sensitivity;
                _lastPosition = event.position;

                if (_pointerCount == 1) {
                  _ws.send({
                    'type': 'mouse_move',
                    'dx': dx,
                    'dy': dy,
                    'sens': 1.0,
                  });
                } else if (_pointerCount == 2) {
                  if (dy.abs() > 1.5) {
                    _ws.send({
                      'type': 'mouse_scroll',
                      'dy': dy > 0 ? 1 : -1,
                      'dx': 0,
                    });
                  }
                }
              },
              onPointerUp: (event) {
                _pointerCount = (_pointerCount - 1).clamp(0, 10);
              },
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _ws.send({'type': 'mouse_click', 'button': 'left'});
                },
                onDoubleTap: () {
                  HapticFeedback.mediumImpact();
                  _ws.send({'type': 'mouse_click', 'button': 'left', 'double': true});
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161E2E).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, size: 48, color: Color(0xFF64748B)),
                        SizedBox(height: 8),
                        Text('Dokunmatik Alan', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                        Text('1 Parmak: Fare | 2 Parmak: Kaydır | Dokun: Sol Tık', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Mouse Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _ws.send({'type': 'mouse_click', 'button': 'left'});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SOL TIK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _ws.send({'type': 'mouse_click', 'button': 'middle'});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.unfold_more, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _ws.send({'type': 'mouse_click', 'button': 'right'});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SAĞ TIK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),

        // Sensitivity Slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.speed, size: 18, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Text('Hassasiyet: ${_sensitivity.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              Expanded(
                child: Slider(
                  value: _sensitivity,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: (v) {
                    setState(() {
                      _sensitivity = v;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
