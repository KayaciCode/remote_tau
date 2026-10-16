import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/websocket_service.dart';

class KeyboardScreen extends StatefulWidget {
  const KeyboardScreen({super.key});

  @override
  State<KeyboardScreen> createState() => _KeyboardScreenState();
}

class _KeyboardScreenState extends State<KeyboardScreen> {
  final WebSocketService _ws = WebSocketService();
  final TextEditingController _textController = TextEditingController();

  void _sendText() {
    final text = _textController.text;
    if (text.isNotEmpty) {
      HapticFeedback.lightImpact();
      _ws.send({'type': 'type_text', 'text': text});
      _textController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Metin PC'ye gönderildi"), duration: Duration(seconds: 1)),
      );
    }
  }

  void _sendKey(String key) {
    HapticFeedback.selectionClick();
    _ws.send({'type': 'key', 'key': key, 'state': 'press'});
  }

  void _sendShortcut(List<String> keys) {
    HapticFeedback.mediumImpact();
    _ws.send({'type': 'shortcut', 'keys': keys});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kısayol: ${keys.join(' + ')}'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Text Input Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: "Metin yazın veya yapıştırın, PC'ye yazılsın...",
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _sendText,
                      icon: const Icon(Icons.send),
                      label: const Text('PC\'ye Yazdır'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Common Keys Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Temel Tuşlar', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildKeyBtn('ESC', () => _sendKey('escape')),
                      _buildKeyBtn('TAB', () => _sendKey('tab')),
                      _buildKeyBtn('WIN', () => _sendKey('win')),
                      _buildKeyBtn('⌫ SIL', () => _sendKey('backspace')),
                      _buildKeyBtn('F5 Yenile', () => _sendKey('f5')),
                      _buildKeyBtn('F11 Tam Ekran', () => _sendKey('f11')),
                      _buildKeyBtn('ENTER ↵', () => _sendKey('enter'), isAccent: true),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Windows Shortcuts Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Windows Kısayolları', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.8,
                    children: [
                      _buildScBtn('Alt + Tab', ['alt', 'tab']),
                      _buildScBtn('Masaüstü (Win+D)', ['win', 'd']),
                      _buildScBtn('Görev Yöneticisi', ['ctrl', 'shift', 'escape']),
                      _buildScBtn('Kapat (Alt+F4)', ['alt', 'f4']),
                      _buildScBtn('Geri Al (Ctrl+Z)', ['ctrl', 'z']),
                      _buildScBtn('Kopyala (Ctrl+C)', ['ctrl', 'c']),
                      _buildScBtn('Yapıştır (Ctrl+V)', ['ctrl', 'v']),
                      _buildScBtn('Kilitle (Win+L)', ['win', 'l']),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyBtn(String label, VoidCallback onTap, {bool isAccent = false}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isAccent ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }

  Widget _buildScBtn(String label, List<String> keys) {
    return ElevatedButton(
      onPressed: () => _sendShortcut(keys),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        alignment: Alignment.centerLeft,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
