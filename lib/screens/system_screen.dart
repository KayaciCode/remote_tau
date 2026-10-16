import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/websocket_service.dart';

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  final WebSocketService _ws = WebSocketService();
  Timer? _timer;
  Map<String, dynamic> _status = {};

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    final host = _ws.currentHost;
    if (host.isEmpty) return;

    try {
      final res = await http.get(Uri.parse('http://$host/api/status'));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _status = jsonDecode(res.body);
        });
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final cpu = (_status['cpu_percent'] ?? 0).toDouble();
    final ram = (_status['ram_percent'] ?? 0).toDouble();
    final ramUsed = _status['ram_used_gb'] ?? 0;
    final ramTotal = _status['ram_total_gb'] ?? 0;
    final uptime = _status['uptime'] ?? '-';
    final hostname = _status['hostname'] ?? 'PC';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Hardware Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(hostname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Süre: $uptime', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('İşlemci (CPU): %${cpu.toStringAsFixed(1)}', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: cpu / 100.0, color: const Color(0xFF38BDF8), backgroundColor: Colors.white10),
                  const SizedBox(height: 16),
                  Text('Bellek (RAM): %${ram.toStringAsFixed(1)} ($ramUsed / $ramTotal GB)', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: ram / 100.0, color: const Color(0xFF10B981), backgroundColor: Colors.white10),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Power Actions Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Güç ve Sistem Yönetimi', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: [
                      _buildPwrBtn(Icons.lock, 'Kilitle', Colors.amber, () {
                        _ws.send({'type': 'power', 'action': 'lock'});
                      }),
                      _buildPwrBtn(Icons.nightlight_round, 'Uyku Modu', Colors.purpleAccent, () {
                        _ws.send({'type': 'power', 'action': 'sleep'});
                      }),
                      _buildPwrBtn(Icons.tv_off, 'Ekranı Kapat', Colors.blueGrey, () {
                        _ws.send({'type': 'power', 'action': 'monitor_off'});
                      }),
                      _buildPwrBtn(Icons.tv, 'Ekranı Aç', Colors.cyanAccent, () {
                        _ws.send({'type': 'power', 'action': 'monitor_on'});
                      }),
                      _buildPwrBtn(Icons.restart_alt, 'Yeniden Başlat', Colors.orange, () {
                        _confirmDialog('Bilgisayarı yeniden başlatmak istiyor musunuz?', () {
                          _ws.send({'type': 'power', 'action': 'restart', 'timer': 0});
                        });
                      }),
                      _buildPwrBtn(Icons.power_settings_new, 'Kapat', Colors.redAccent, () {
                        _confirmDialog('Bilgisayarı hemen kapatmak istiyor musunuz?', () {
                          _ws.send({'type': 'power', 'action': 'shutdown', 'timer': 0});
                        });
                      }),
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

  Widget _buildPwrBtn(IconData icon, String title, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: () {
        HapticFeedback.heavyImpact();
        onTap();
      },
      icon: Icon(icon, color: color, size: 20),
      label: Text(title, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        alignment: Alignment.centerLeft,
      ),
    );
  }

  void _confirmDialog(String msg, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Onay'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Evet'),
          ),
        ],
      ),
    );
  }
}
