import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/websocket_service.dart';

class ScreenMirrorScreen extends StatefulWidget {
  const ScreenMirrorScreen({super.key});

  @override
  State<ScreenMirrorScreen> createState() => _ScreenMirrorScreenState();
}

class _ScreenMirrorScreenState extends State<ScreenMirrorScreen> {
  final WebSocketService _ws = WebSocketService();
  WebSocketChannel? _screenChannel;
  Uint8List? _latestFrame;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  void _startStream() {
    final host = _ws.currentHost;
    final pin = _ws.currentPin;
    if (host.isEmpty) return;

    final uri = Uri.parse("ws://$host/ws/screen?pin=$pin");
    try {
      _screenChannel = WebSocketChannel.connect(uri);
      setState(() {
        _isStreaming = true;
      });

      _screenChannel!.stream.listen((data) {
        if (data is Uint8List || data is List<int>) {
          if (mounted) {
            setState(() {
              _latestFrame = Uint8List.fromList(data);
            });
          }
        }
      }, onDone: () {
        if (mounted) setState(() => _isStreaming = false);
      }, onError: (e) {
        if (mounted) setState(() => _isStreaming = false);
      });
    } catch (e) {
      setState(() => _isStreaming = false);
    }
  }

  void _stopStream() {
    _screenChannel?.sink.close();
    _screenChannel = null;
    setState(() {
      _isStreaming = false;
    });
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top action bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _isStreaming ? _stopStream : _startStream,
                icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                label: Text(_isStreaming ? 'Yayını Durdur' : 'Yayını Başlat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isStreaming ? Colors.redAccent : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
              ),
              const Text('Ekrana dokunup tıklayabilirsiniz', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            ],
          ),
        ),

        // Live stream screen area
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: _latestFrame != null
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapDown: (details) {
                          HapticFeedback.selectionClick();
                          final rx = details.localPosition.dx / constraints.maxWidth;
                          final ry = details.localPosition.dy / constraints.maxHeight;
                          _ws.send({
                            'type': 'mouse_abs_click',
                            'rx': rx.clamp(0.0, 1.0),
                            'ry': ry.clamp(0.0, 1.0),
                            'button': 'left',
                          });
                        },
                        child: Center(
                          child: Image.memory(
                            _latestFrame!,
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.desktop_windows, size: 64, color: Color(0xFF64748B)),
                        SizedBox(height: 12),
                        Text('Canlı Ekran Yayını Duraklatıldı', style: TextStyle(color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
