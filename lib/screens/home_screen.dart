import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/websocket_service.dart';
import '../services/discovery_service.dart';
import 'touchpad_screen.dart';
import 'screen_mirror_screen.dart';
import 'media_screen.dart';
import 'keyboard_screen.dart';
import 'system_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final WebSocketService _ws = WebSocketService();
  final MobileDiscoveryService _discovery = MobileDiscoveryService();
  
  bool _isConnected = false;
  int _currentIndex = 0;
  List<DiscoveredDevice> _nearbyPCs = [];

  @override
  void initState() {
    super.initState();
    _ws.connectionStream.listen((state) {
      if (mounted) {
        setState(() {
          _isConnected = state;
        });
      }
    });

    _discovery.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _nearbyPCs = devices;
        });
      }
    });

    _discovery.startDiscovery();
  }

  @override
  void dispose() {
    _discovery.stopDiscovery();
    super.dispose();
  }

  void _pairWithDevice(DiscoveredDevice dev) {
    _showPinDialog(dev.baseUrl, dev.name);
  }

  void _showPinDialog(String baseUrl, String pcName) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8)),
            const SizedBox(width: 8),
            Text(pcName, style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PC ekranındaki 4 haneli Eşleşme PIN kodunu girin:', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              autofocus: true,
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'PIN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFF161E2E),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.heavyImpact();
              _ws.connect(baseUrl, pinCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Eşleş ve Bağlan'),
          ),
        ],
      ),
    );
  }

  void _manualConnect() {
    final url = _urlController.text.trim();
    final pin = _pinController.text.trim();
    if (url.isNotEmpty) {
      HapticFeedback.mediumImpact();
      _ws.connect(url, pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) {
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.laptop_chromebook, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              Text('PC Remote Master', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nearby Radar Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161E2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.radar, color: Color(0xFF38BDF8), size: 20),
                            SizedBox(width: 8),
                            Text('Yakındaki Bilgisayarlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            children: [
                              CircleAvatar(radius: 3, backgroundColor: Colors.greenAccent),
                              SizedBox(width: 4),
                              Text('Taranıyor', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_nearbyPCs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              Text('Ağdaki PC aranıyor...', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                              const SizedBox(height: 4),
                              const Text('Bilgisayarınızda PC Remote Master açık olmalıdır', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _nearbyPCs.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                        itemBuilder: (context, index) {
                          final dev = _nearbyPCs[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF2563EB).withOpacity(0.2),
                              child: const Icon(Icons.desktop_windows, color: Color(0xFF38BDF8)),
                            ),
                            title: Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('ID: ${dev.id} • ${dev.ip}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            trailing: ElevatedButton(
                              onPressed: () => _pairWithDevice(dev),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Text('Eşleş', style: TextStyle(fontSize: 12)),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Manual Entry Section
              const Text('VEYA KOD İLE EŞLEŞİN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
              const SizedBox(height: 12),

              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'PC Adresi veya Küresel Link',
                  hintText: 'Örn: http://192.168.1.35:8000 veya trycloudflare.com',
                  prefixIcon: const Icon(Icons.link, color: Color(0xFF38BDF8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFF161E2E),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: 'Eşleşme PIN Kodu',
                  hintText: 'Örn: 1234',
                  prefixIcon: const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFF161E2E),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _manualConnect,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('BAĞLANTIYI BAŞLAT', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Active Control View
    final List<Widget> pages = [
      const TouchpadScreen(),
      const ScreenMirrorScreen(),
      const MediaScreen(),
      const KeyboardScreen(),
      const SystemScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('PC Remote Master', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: () {
              HapticFeedback.heavyImpact();
              _ws.send({'type': 'power', 'action': 'lock'});
            },
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            onPressed: () {
              _ws.disconnect();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          HapticFeedback.selectionClick();
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF121824),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: const Color(0xFF64748B),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.touch_app), label: 'Fare'),
          BottomNavigationBarItem(icon: Icon(Icons.desktop_windows), label: 'Ekran'),
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Medya'),
          BottomNavigationBarItem(icon: Icon(Icons.keyboard), label: 'Klavye'),
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'Sistem'),
        ],
      ),
    );
  }
}
