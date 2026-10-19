import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/touchpad_widget.dart';
import '../services/connection_service.dart';
import '../services/discovery_service.dart';

class CustomStreamDeckKey {
  final String id;
  final String title;
  final String actionType; // 'app', 'hotkey', 'cmd', 'media'
  final String command;
  final String iconName;
  final Color color;

  CustomStreamDeckKey({
    required this.id,
    required this.title,
    required this.actionType,
    required this.command,
    required this.iconName,
    required this.color,
  });

  IconData get icon => resolveIcon(iconName);

  static IconData resolveIcon(String name) {
    switch (name) {
      case 'play':
        return Icons.play_circle_filled;
      case 'code':
        return Icons.code;
      case 'camera':
        return Icons.camera_alt;
      case 'speed':
        return Icons.speed;
      case 'mic':
        return Icons.mic;
      case 'videocam':
        return Icons.videocam;
      case 'terminal':
        return Icons.terminal;
      case 'globe':
        return Icons.language;
      case 'folder':
        return Icons.folder_open;
      case 'music':
        return Icons.music_note;
      case 'game':
        return Icons.sports_esports;
      case 'calc':
        return Icons.calculate;
      case 'edit':
        return Icons.edit_note;
      case 'star':
      default:
        return Icons.star;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'actionType': actionType,
        'command': command,
        'iconName': iconName,
        'colorValue': color.value,
      };

  factory CustomStreamDeckKey.fromJson(Map<String, dynamic> json) =>
      CustomStreamDeckKey(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        actionType: json['actionType'] ?? 'app',
        command: json['command'] ?? '',
        iconName: json['iconName'] ?? 'star',
        color: Color(json['colorValue'] ?? 0xFF00F2FE),
      );
}

class MobileControllerScreen extends StatefulWidget {
  const MobileControllerScreen({Key? key}) : super(key: key);

  @override
  State<MobileControllerScreen> createState() => _MobileControllerScreenState();
}

class _MobileControllerScreenState extends State<MobileControllerScreen>
    with TickerProviderStateMixin {
  final ConnectionService _conn = ConnectionService();
  final MobileDiscoveryService _discovery = MobileDiscoveryService();

  int _activeLobbyIndex = 0; // 0: Pairing, 1: Touchpad, 2: Screen, 3: Keyboard, 4: StreamDeck, 5: Media&Power
  bool _isConnected = false;
  int _selectedMonitor = 0;
  double _volumeLevel = 50.0;
  double _mouseSensitivity = 1.0;
  bool _isRightClickMode = false;
  Timer? _statusPollTimer;

  // Live Screen Streaming State
  Uint8List? _screenFrameBytes;
  Timer? _screenStreamTimer;
  bool _isFetchingFrame = false;
  int _streamFps = 0;
  int _fpsCounter = 0;
  DateTime _lastFpsTime = DateTime.now();

  // Pairing Controllers
  final TextEditingController _deskIdCtrl =
      TextEditingController(text: "849 210 492");
  final TextEditingController _pinCtrl =
      TextEditingController(text: "793 421");
  final TextEditingController _ipCtrl =
      TextEditingController(text: "192.168.1.20");
  final TextEditingController _portCtrl =
      TextEditingController(text: "8000");
  final TextEditingController _wanUrlCtrl =
      TextEditingController();
  final TextEditingController _macCtrl =
      TextEditingController(text: "40:C2:BA:5B:1B:25");
  final TextEditingController _keyboardInputCtrl = TextEditingController();

  // Zero-Trust Security Controllers & State
  final TextEditingController _emailCtrl =
      TextEditingController(text: "admin@pcremote.local");
  final TextEditingController _passwordCtrl =
      TextEditingController(text: "123456");
  final TextEditingController _otpCtrl =
      TextEditingController(text: "793 421");
  bool _isAuthLoading = false;
  int _authModalTab = 0; // 0: PIN / QR, 1: Master Hesap

  int _pairingSubTab = 0; // 0: Yerel Wi-Fi, 1: Mobil Veri (WAN)

  // Stream Deck Custom Keys & Category
  int _streamDeckCategory = 0; // 0: Gaming/Stream, 1: Productivity, 2: Soundboard, 3: Custom
  List<CustomStreamDeckKey> _customKeys = [];

  // Full-Screen Touch Monitor State
  bool _isFullScreenMonitorMode = false;
  bool _isHudCollapsed = false;
  Offset _hudPosition = const Offset(20, 20);
  int _sidecarSubTab = 0; // 0: 2. Monitör Modu, 1: Siber Yan Panel Kokpiti

  // Floating Draggable Cyber Mouse Controller State
  bool _showFloatingMouseController = true;
  Offset _floatingMousePos = const Offset(20, 100);
  bool _isFloatingMouseCollapsed = false;
  bool _isMouseDragLocked = false;
  double _lastDirectTouchX = 0;
  double _lastDirectTouchY = 0;
  Offset? _pointerDownPos;
  DateTime? _pointerDownTime;

  void _toggleFullScreenMonitor(bool enable) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isFullScreenMonitorMode = enable;
    });
    if (enable) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _startScreenStream();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _showOnScreenKeyboardModal() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: AppTheme.accentCyan),
            SizedBox(width: 8),
            Text("Windows'a Metin Gönder", style: TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Yazmak istediğiniz metni girin...",
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          onSubmitted: (val) {
            if (val.isNotEmpty) {
              _conn.sendText(val);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
            onPressed: () {
              final val = textCtrl.text;
              if (val.isNotEmpty) {
                _conn.sendText(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Gönder", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Rotary Dial Animation
  double _rotaryAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCustomKeys();
    _conn.loadSettings().then((_) {
      setState(() {
        _ipCtrl.text = _conn.host;
        _portCtrl.text = _conn.port.toString();
        _pinCtrl.text = _conn.pin;
        _otpCtrl.text = _conn.pin;
        _deskIdCtrl.text = _conn.deskId;
        _emailCtrl.text = _conn.masterEmail;
        if (_conn.wanUrl.isNotEmpty) {
          _wanUrlCtrl.text = _conn.wanUrl;
        } else if (_conn.autoWanUrl.isNotEmpty) {
          _wanUrlCtrl.text = _conn.autoWanUrl;
        }
        if (_conn.isWanMode) {
          _pairingSubTab = 1;
        }
      });
      _tryAutoConnect();
    });

    _discovery.startDiscovery();

    _statusPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isConnected) {
        _conn.checkConnection().then((ok) {
          if (mounted) setState(() => _isConnected = ok);
        });
      }
    });
  }

  bool _isEnablingVirtualMonitor = false;

  Future<void> _ensureThirdMonitorActive() async {
    if (_isEnablingVirtualMonitor) return;
    setState(() {
      _isEnablingVirtualMonitor = true;
    });
    final ok = await _conn.enableVirtualMonitor();
    if (mounted) {
      final newCount = _conn.lastStatus?.monitors.length ?? 1;
      setState(() {
        _isEnablingVirtualMonitor = false;
        if (ok || newCount >= 3) {
          _selectedMonitor = 2;
        } else if (newCount >= 2) {
          _selectedMonitor = newCount - 1;
        }
        _screenFrameBytes = null;
      });
      _startScreenStream();
    }
  }

  Future<void> _disableThirdMonitor() async {
    if (_isEnablingVirtualMonitor) return;
    setState(() {
      _isEnablingVirtualMonitor = true;
    });
    await _conn.disableVirtualMonitor();
    if (mounted) {
      setState(() {
        _isEnablingVirtualMonitor = false;
        _selectedMonitor = 0;
        _screenFrameBytes = null;
      });
    }
  }

  void _switchLobby(int idx) {
    HapticFeedback.lightImpact();
    final prevLobby = _activeLobbyIndex;
    final monCount = _conn.lastStatus?.monitors.length ?? 1;
    setState(() {
      _activeLobbyIndex = idx;
      _screenFrameBytes = null;
      if (idx == 2) {
        // Sayfa A (Monitör Yansıtma): Fiziksel monitörleri (Monitör 1 veya 2) yansıtır
        if (_selectedMonitor >= 2 || _selectedMonitor >= monCount) {
          _selectedMonitor = 0;
        }
      } else if (idx == 3) {
        // Sayfa B (Yeni 3. Monitör): Bağımsız 3. sanal monitörü seçer
        if (monCount >= 3) {
          _selectedMonitor = 2;
        } else if (monCount >= 2) {
          _selectedMonitor = monCount - 1;
        } else {
          _selectedMonitor = 0;
        }
      }
    });
    if (prevLobby == 3 && idx != 3 && _isConnected) {
      _conn.disableVirtualMonitor();
    } else if (idx == 3 && monCount < 3 && _isConnected) {
      _ensureThirdMonitorActive();
    }
    if (idx == 2 || idx == 3) {
      _startScreenStream();
    } else {
      _stopScreenStream();
    }
  }

  void _startScreenStream() {
    _screenStreamTimer?.cancel();
    // 45ms interval gives ~22 FPS fluid, low-latency, real-time desktop mirror via high-speed JPEG
    _screenStreamTimer = Timer.periodic(const Duration(milliseconds: 45), (timer) async {
      if (!mounted || (!_isFullScreenMonitorMode && _activeLobbyIndex != 2 && _activeLobbyIndex != 3) || !_isConnected) return;
      if (_isFetchingFrame) return;
      _isFetchingFrame = true;
      try {
        final bytes = await _conn.fetchScreenFrame(
          monitor: _selectedMonitor,
          scale: 0.65,
          quality: 75,
        );
        if (bytes != null && mounted) {
          _fpsCounter++;
          final now = DateTime.now();
          if (now.difference(_lastFpsTime).inSeconds >= 1) {
            _streamFps = _fpsCounter;
            _fpsCounter = 0;
            _lastFpsTime = now;
          }
          setState(() {
            _screenFrameBytes = bytes;
          });
        }
      } catch (_) {
      } finally {
        _isFetchingFrame = false;
      }
    });
  }

  void _stopScreenStream() {
    _screenStreamTimer?.cancel();
    _screenStreamTimer = null;
  }

  @override
  void dispose() {
    if (_activeLobbyIndex == 3 && _isConnected) {
      _conn.disableVirtualMonitor();
    }
    _statusPollTimer?.cancel();
    _stopScreenStream();
    _discovery.stopDiscovery();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadCustomKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('custom_streamdeck_keys');
    if (data != null) {
      try {
        final List list = jsonDecode(data);
        setState(() {
          _customKeys =
              list.map((e) => CustomStreamDeckKey.fromJson(e)).toList();
        });
      } catch (_) {}
    } else {
      // Default initial custom keys
      setState(() {
        _customKeys = [
          CustomStreamDeckKey(
            id: '1',
            title: 'YouTube Aç',
            actionType: 'app',
            command: 'https://youtube.com',
            iconName: 'play',
            color: const Color(0xFFFF0055),
          ),
          CustomStreamDeckKey(
            id: '2',
            title: 'VS Code',
            actionType: 'app',
            command: 'code',
            iconName: 'code',
            color: const Color(0xFF007ACC),
          ),
          CustomStreamDeckKey(
            id: '3',
            title: 'Ekran Alıntısı',
            actionType: 'hotkey',
            command: 'screenshot',
            iconName: 'camera',
            color: const Color(0xFF00F2FE),
          ),
          CustomStreamDeckKey(
            id: '4',
            title: 'Görev Yöneticisi',
            actionType: 'hotkey',
            command: 'task_mgr',
            iconName: 'speed',
            color: const Color(0xFF8A2BE2),
          ),
        ];
      });
      _saveCustomKeys();
    }
  }

  Future<void> _saveCustomKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _customKeys.map((e) => e.toJson()).toList();
    await prefs.setString('custom_streamdeck_keys', jsonEncode(jsonList));
  }

  Future<void> _tryAutoConnect() async {
    final ok = await _conn.checkConnection();
    if (mounted) {
      setState(() => _isConnected = ok);
      if (ok && _conn.isAuthenticated && _activeLobbyIndex == 0) {
        _switchLobby(1); // Go to trackpad when connected & authorized
      }
    }
  }

  void _manualConnect() async {
    HapticFeedback.mediumImpact();
    await _conn.saveSettings(
      _ipCtrl.text.trim(),
      int.tryParse(_portCtrl.text.trim()) ?? 8000,
      _pinCtrl.text.trim(),
      _deskIdCtrl.text.trim(),
      wanMode: false,
    );
    final ok = await _conn.checkConnection();
    if (mounted) {
      setState(() => _isConnected = ok);
      if (ok) {
        // If not yet authenticated, try pairing with PIN
        if (!_conn.isAuthenticated && _pinCtrl.text.trim().isNotEmpty) {
          await _conn.pairWithOtp(_pinCtrl.text.trim());
          if (mounted) setState(() {});
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentGreen,
            content: Text("✅ PC'ye Yerel Wi-Fi ile Bağlandı! (${_conn.host})${_conn.isAuthenticated ? ' • Zero-Trust Korumalı 🔒' : ''}"),
          ),
        );
        _switchLobby(1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.accentRed,
            content: Text("❌ Bağlantı kurulamadı. PC Host açık mı ve aynı Wi-Fi'da mısınız?"),
          ),
        );
      }
    }
  }

  void _connectViaWan() async {
    HapticFeedback.mediumImpact();
    final wanUrl = _wanUrlCtrl.text.trim().isNotEmpty ? _wanUrlCtrl.text.trim() : _conn.autoWanUrl;
    if (wanUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.accentAmber,
          content: Text("⚠️ PC'deki Bulut Tüneli linki henüz hazır değil veya girilmedi."),
        ),
      );
      return;
    }

    await _conn.saveSettings(
      _ipCtrl.text.trim(),
      int.tryParse(_portCtrl.text.trim()) ?? 8000,
      _pinCtrl.text.trim(),
      _deskIdCtrl.text.trim(),
      wanMode: true,
      newWanUrl: wanUrl,
    );
    final ok = await _conn.checkConnection();
    if (mounted) {
      setState(() => _isConnected = ok);
      if (ok) {
        if (!_conn.isAuthenticated && _pinCtrl.text.trim().isNotEmpty) {
          await _conn.pairWithOtp(_pinCtrl.text.trim());
          if (mounted) setState(() {});
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentGreen,
            content: Text("🌐 Mobil Veri ile PC'ye Bağlanıldı!${_conn.isAuthenticated ? ' • Zero-Trust Korumalı 🔒' : ''}"),
          ),
        );
        _switchLobby(1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.accentRed,
            content: Text("❌ Uzak bağlantı kurulamadı. PC'de 'Mobil Veri Tüneli' açık mı?"),
          ),
        );
      }
    }
  }

  Future<void> _submitPinAuth([String? customOtp]) async {
    final otp = (customOtp ?? _otpCtrl.text).trim();
    if (otp.isEmpty) return;
    setState(() => _isAuthLoading = true);
    HapticFeedback.mediumImpact();
    final res = await _conn.pairWithOtp(otp);
    if (mounted) {
      setState(() => _isAuthLoading = false);
      if (res['success'] == true) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.accentGreen,
            content: Text("🔒 Cihaz Başarıyla Eşleşti & Yetkilendirildi!"),
          ),
        );
        _switchLobby(1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentRed,
            content: Text("❌ ${res['error'] ?? 'Eşleşme başarısız'}"),
          ),
        );
      }
    }
  }

  Future<void> _submitMasterAuth() async {
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) return;
    setState(() => _isAuthLoading = true);
    HapticFeedback.mediumImpact();
    final res = await _conn.loginWithCredentials(email, pass);
    if (mounted) {
      setState(() => _isAuthLoading = false);
      if (res['success'] == true) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.accentGreen,
            content: Text("🔑 Yönetici Girişi Başarılı! Cihaz Eşleşti."),
          ),
        );
        _switchLobby(1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentRed,
            content: Text("❌ ${res['error'] ?? 'Giriş başarısız'}"),
          ),
        );
      }
    }
  }

  Future<void> _logoutDevice() async {
    await _conn.logout();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.accentAmber,
          content: Text("🔓 Oturum kapatıldı, cihaz yetkisi kaldırıldı."),
        ),
      );
    }
  }

  void _showAuthModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppTheme.accentCyan, size: 22),
                          SizedBox(width: 8),
                          Text(
                            "Zero-Trust Cihaz Eşleşmesi",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "PC'nizi yetkisiz erişimlere karşı korumak için cihazınızı eşleştirin.",
                    style: TextStyle(fontSize: 11, color: AppTheme.darkTextMuted),
                  ),
                  const SizedBox(height: 16),

                  // Auth Method Selector Tabs
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => _authModalTab = 0),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _authModalTab == 0 ? AppTheme.accentCyan : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.pin, size: 14, color: _authModalTab == 0 ? Colors.black : Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(
                                    "PIN ile Eşle",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: _authModalTab == 0 ? Colors.black : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => _authModalTab = 1),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _authModalTab == 1 ? const Color(0xFF8B5CF6) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person, size: 14, color: _authModalTab == 1 ? Colors.white : Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Yönetici Girişi",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: _authModalTab == 1 ? Colors.white : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // TAB 0: PIN / OTP AUTH
                  if (_authModalTab == 0) ...[
                    TextField(
                      controller: _otpCtrl,
                      style: const TextStyle(fontSize: 15, color: Colors.white, letterSpacing: 3, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "PC Ekranındaki 6 Haneli PIN Kodu",
                        labelStyle: const TextStyle(color: AppTheme.accentCyan, fontSize: 11),
                        hintText: "793 421",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCyan,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isAuthLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(_isAuthLoading ? "Yetkilendiriliyor..." : "Bu Cihazı Eşle & Yetkilendir", style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _isAuthLoading
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await _submitPinAuth();
                              },
                      ),
                    ),
                  ],

                  // TAB 1: MASTER CREDENTIALS AUTH
                  if (_authModalTab == 1) ...[
                    TextField(
                      controller: _emailCtrl,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Yönetici E-posta",
                        labelStyle: const TextStyle(color: Color(0xFFC084FC), fontSize: 11),
                        hintText: "admin@pcremote.local",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Master Parola",
                        labelStyle: const TextStyle(color: Color(0xFFC084FC), fontSize: 11),
                        hintText: "••••••",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isAuthLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.vpn_key, size: 18),
                        label: Text(_isAuthLoading ? "Doğrulanıyor..." : "Giriş Yap ve Yetki Al", style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _isAuthLoading
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await _submitMasterAuth();
                              },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreenMonitorMode) {
      return _buildFullScreenTouchMonitor();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: SafeArea(
        child: Column(
          children: [
            // Top Persistent Header
            _buildTopHeader(),

            // AdMob Monetization Banner
            _buildAdMobBannerSlot(),

            // Active Lobby Body
            Expanded(
              child: _buildActiveLobbyContent(),
            ),

            // Bottom Lobby Navigation Dock
            _buildBottomDock(),
          ],
        ),
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1322),
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.gamepad, size: 16, color: Colors.black),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Remote Deck PRO",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.5)),
                        ),
                        child: const Text("PRO",
                            style: TextStyle(
                                color: Color(0xFFFFB800),
                                fontSize: 8,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text(
                    _isConnected
                        ? (_conn.isWanMode
                            ? "🌐 Mobil Veri (WAN) • ${_conn.isAuthenticated ? 'Yetkili 🔒' : 'Eşleşme Gerekli ⚠️'}"
                            : "📶 Wi-Fi: ${_conn.host} • ${_conn.isAuthenticated ? 'Yetkili 🔒' : 'Eşleşme Gerekli ⚠️'}")
                        : "Bağlantı Bekleniyor",
                    style: TextStyle(
                      fontSize: 9.5,
                      color: _isConnected
                          ? (_conn.isAuthenticated
                              ? (_conn.isWanMode ? const Color(0xFFC084FC) : AppTheme.accentGreen)
                              : Colors.amberAccent)
                          : AppTheme.darkTextMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Zero-Trust Auth Badge
              if (_isConnected)
                InkWell(
                  onTap: _showAuthModal,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _conn.isAuthenticated
                          ? Colors.green.withOpacity(0.18)
                          : Colors.amber.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _conn.isAuthenticated
                            ? Colors.green.withOpacity(0.4)
                            : Colors.amber.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _conn.isAuthenticated ? Icons.shield : Icons.lock_open,
                          size: 10,
                          color: _conn.isAuthenticated ? Colors.greenAccent : Colors.amberAccent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _conn.isAuthenticated ? "Zero-Trust" : "Giriş Yap",
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _conn.isAuthenticated ? Colors.greenAccent : Colors.amberAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Latency / WAN Pill
              if (_isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: _conn.isWanMode
                        ? const Color(0xFF8B5CF6).withOpacity(0.18)
                        : AppTheme.accentCyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _conn.isWanMode
                          ? const Color(0xFF8B5CF6).withOpacity(0.4)
                          : AppTheme.accentCyan.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _conn.isWanMode ? "🌐 4G/5G WAN" : "📶 ${_conn.latencyMs}ms",
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: _conn.isWanMode ? const Color(0xFFC084FC) : AppTheme.accentCyan,
                    ),
                  ),
                ),
              // Connection Status Badge
              InkWell(
                onTap: () => _switchLobby(0),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isConnected
                        ? AppTheme.accentGreen.withOpacity(0.15)
                        : AppTheme.accentRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isConnected
                          ? AppTheme.accentGreen.withOpacity(0.4)
                          : AppTheme.accentRed.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.check_circle : Icons.link_off,
                        size: 12,
                        color: _isConnected ? AppTheme.accentGreen : AppTheme.accentRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isConnected ? "Online" : "Bağlan",
                        style: TextStyle(
                          color: _isConnected ? AppTheme.accentGreen : AppTheme.accentRed,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ADMOB BANNER SLOT ---
  Widget _buildAdMobBannerSlot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1626),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: const Text("AD",
                style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber)),
          ),
          const SizedBox(width: 8),
          const Text(
            "Google AdMob Banner Reklam Alanı (Canlı)",
            style: TextStyle(fontSize: 9.5, color: AppTheme.darkTextMuted),
          ),
        ],
      ),
    );
  }

  // --- LOBBY ROUTER ---
  Widget _buildActiveLobbyContent() {
    switch (_activeLobbyIndex) {
      case 0:
        return _buildLobby1Pairing();
      case 1:
        return _buildLobby2Touchpad();
      case 2:
        return _buildLobby3ScreenMirror();
      case 3:
        return _buildLobby3SidecarAndSecondMonitor();
      case 4:
        return _buildLobby4Keyboard();
      case 5:
        return _buildLobby5StreamDeck();
      case 6:
        return _buildLobby6MediaAndPower();
      default:
        return _buildLobby1Pairing();
    }
  }

  // ==========================================
  // LOBİ 1: GİRİŞ, BAĞLANTI & QR KOD MERKEZİ
  // ==========================================
  Widget _buildLobby1Pairing() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ZERO-TRUST SECURITY CARD
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _conn.isAuthenticated
                    ? [const Color(0xFF065F46).withOpacity(0.35), const Color(0xFF0F172A)]
                    : [const Color(0xFF78350F).withOpacity(0.35), const Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _conn.isAuthenticated
                    ? Colors.greenAccent.withOpacity(0.4)
                    : Colors.amberAccent.withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _conn.isAuthenticated
                        ? Colors.greenAccent.withOpacity(0.15)
                        : Colors.amberAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _conn.isAuthenticated ? Icons.verified_user : Icons.gpp_maybe,
                    color: _conn.isAuthenticated ? Colors.greenAccent : Colors.amberAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _conn.isAuthenticated ? "Zero-Trust: Cihaz Yetkili" : "Güvenlik: Eşleşme Gerekli",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: (_conn.isAuthenticated ? Colors.green : Colors.amber).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _conn.isAuthenticated ? "KORUMALI" : "KİLİTLİ",
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: _conn.isAuthenticated ? Colors.greenAccent : Colors.amberAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _conn.isAuthenticated
                            ? "Cihaz ID: ${_conn.deviceId.length > 16 ? _conn.deviceId.substring(0, 16) + '...' : _conn.deviceId}"
                            : "PC kontrolü için PIN veya Yönetici şifresi girin.",
                        style: const TextStyle(fontSize: 10, color: AppTheme.darkTextMuted),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _conn.isAuthenticated ? const Color(0xFF1E293B) : AppTheme.accentCyan,
                    foregroundColor: _conn.isAuthenticated ? Colors.white70 : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _conn.isAuthenticated ? _logoutDevice : _showAuthModal,
                  child: Text(
                    _conn.isAuthenticated ? "Çıkış Yap" : "Giriş Yap",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // ZERO-TOUCH AUTO-WAN CARD (Markette / Dışarıda)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_sync, color: Color(0xFFC084FC), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Zero-Touch Dış Erişim (Market / 4G)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _conn.isWanMode
                            ? "Bulut Tüneli üzerinden bağlısınız 🌐"
                            : (_conn.autoWanUrl.isNotEmpty
                                ? "Ev dışına çıktığınızda tünel otomatik bağlanır."
                                : "PC tüneli arka planda otomatik hazırlanıyor..."),
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (_conn.isWanMode || _conn.autoWanUrl.isNotEmpty ? Colors.green : Colors.amber).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _conn.isWanMode ? "WAN Canlı" : (_conn.autoWanUrl.isNotEmpty ? "Hazır" : "Bekleniyor"),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _conn.isWanMode || _conn.autoWanUrl.isNotEmpty ? Colors.greenAccent : Colors.amberAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Connection Mode Selector Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF101726),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _pairingSubTab = 0);
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _pairingSubTab == 0 ? const Color(0xFF00F2FE) : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi, size: 15, color: _pairingSubTab == 0 ? Colors.black : Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            "🏠 Yerel Wi-Fi",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _pairingSubTab == 0 ? Colors.black : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _pairingSubTab = 1);
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _pairingSubTab == 1 ? const Color(0xFF8B5CF6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _pairingSubTab == 1
                            ? [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 8)]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.public, size: 15, color: _pairingSubTab == 1 ? Colors.white : Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            "🌐 Mobil Veri (WAN)",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _pairingSubTab == 1 ? Colors.white : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // TAB 0: YEREL WI-FI
          if (_pairingSubTab == 0) ...[
            // Banner Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00F2FE).withOpacity(0.15),
                    const Color(0xFF8A2BE2).withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00F2FE).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F2FE).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: Color(0xFF00F2FE), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "PC ile Anında Eşleş",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "PC ekranındaki Wi-Fi QR kodunu okutun veya IP girin.",
                          style: TextStyle(fontSize: 10.5, color: AppTheme.darkTextMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F2FE),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showQrScannerModal,
                    child: const Text("QR Tara", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Desk ID & PIN Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🔑 Wi-Fi Manuel Bağlantı Bilgileri",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _ipCtrl,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "PC Yerel IP Adresi",
                            labelStyle: const TextStyle(color: AppTheme.accentCyan, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF0A0F1A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _portCtrl,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Port",
                            labelStyle: const TextStyle(color: AppTheme.accentCyan, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF0A0F1A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _deskIdCtrl,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Desk ID",
                            labelStyle: const TextStyle(color: AppTheme.darkTextMuted, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF0A0F1A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _pinCtrl,
                          style: const TextStyle(fontSize: 12, color: Colors.white, letterSpacing: 2),
                          decoration: InputDecoration(
                            labelText: "PIN (6 Hane)",
                            labelStyle: const TextStyle(color: AppTheme.darkTextMuted, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF0A0F1A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.bolt, size: 18),
                      label: const Text("Wi-Fi ile Hemen Bağlan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: _manualConnect,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // TAB 1: MOBIL VERI (WAN)
          if (_pairingSubTab == 1) ...[
            // Purple WAN Banner Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(0.2),
                    const Color(0xFF3B82F6).withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.language, color: Color(0xFFC084FC), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Küresel Mobil Veri Erişimi",
                          style: TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Nerede olursanız olun (4G/5G) PC'nizi güvenle yönetin.",
                          style: TextStyle(fontSize: 10.5, color: AppTheme.darkTextMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showQrScannerModal,
                    child: const Text("QR Tara", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // WAN Link & PIN Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("🌐 PC Uzak Bağlantı (HTTPS) Linki",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      InkWell(
                        onTap: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data != null && data.text != null && data.text!.isNotEmpty) {
                            setState(() {
                              _wanUrlCtrl.text = data.text!.trim();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppTheme.accentGreen,
                                content: Text("📋 Pano içeriği yapıştırıldı!"),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.paste, size: 12, color: Color(0xFFC084FC)),
                              SizedBox(width: 4),
                              Text("Yapıştır", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC084FC))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _wanUrlCtrl,
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: "https://xxx.trycloudflare.com veya 176.41.x.x:8000",
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                      prefixIcon: const Icon(Icons.link, color: Color(0xFFC084FC), size: 18),
                      filled: true,
                      fillColor: const Color(0xFF0A0F1A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _deskIdCtrl,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Desk ID",
                            labelStyle: const TextStyle(color: AppTheme.darkTextMuted, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF0A0F1A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _pinCtrl,
                          style: const TextStyle(fontSize: 12, color: Colors.white, letterSpacing: 2),
                          decoration: InputDecoration(
                            labelText: "PIN (6 Hane)",
                            labelStyle: const TextStyle(color: AppTheme.darkTextMuted, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF0A0F1A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.language, size: 18),
                      label: const Text("Mobil Veri ile Uzaktan Bağlan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: _connectViaWan,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFFC084FC)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "💡 PC'de 'Mobil Veri Erişimini Başlat' butonuna bastıktan sonra oluşan HTTPS bağlantısını buraya girerek veya QR kodu okutarak bağlanabilirsiniz.",
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Wi-Fi Zero-Config Discovered PCs Stream
          const Text("📡 Yerel Ağda Keşfedilen Bilgisayarlar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
          const SizedBox(height: 8),
          StreamBuilder<List<DiscoveredDevice>>(
            stream: _discovery.devicesStream,
            builder: (context, snapshot) {
              final devices = snapshot.data ?? [];
              if (devices.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101726),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
                      ),
                      const SizedBox(height: 8),
                      Text("Wi-Fi ağı taranıyor (Port 8888)...",
                          style: TextStyle(fontSize: 11, color: AppTheme.darkTextMuted)),
                      const SizedBox(height: 4),
                      Text("PC uygulamasının açık olduğundan emin olun.",
                          style: TextStyle(fontSize: 9.5, color: Colors.white38)),
                    ],
                  ),
                );
              }

              return Column(
                children: devices.map((dev) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121B2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentCyan.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.desktop_windows, color: AppTheme.accentCyan, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dev.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                Text("${dev.ip}:${dev.port} • ${dev.os}",
                                    style: const TextStyle(fontSize: 10, color: AppTheme.darkTextMuted)),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentCyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            setState(() {
                              _ipCtrl.text = dev.ip;
                              _portCtrl.text = dev.port.toString();
                            });
                            _manualConnect();
                          },
                          child: const Text("Bağlan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showQrScannerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1422),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("📷 QR Kod ile Eşleş",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 14),
              // Simulated dynamic viewfinder
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00F2FE), width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.qr_code_2, size: 120, color: Colors.white24),
                    Container(
                      width: 160,
                      height: 2,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00F2FE),
                        boxShadow: [BoxShadow(color: Color(0xFF00F2FE), blurRadius: 8, spreadRadius: 1)],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text("PC Dashboard ekranında beliren QR Kodu kameraya tutun.",
                  style: TextStyle(fontSize: 11, color: AppTheme.darkTextMuted), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F2FE),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.qr_code, size: 18),
                  label: const Text("Kodu Otomatik Çöz & Bağlan", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data != null && data.text != null && data.text!.isNotEmpty) {
                      final text = data.text!.trim();
                      if (text.contains('.trycloudflare.com') || text.contains('http://') || text.contains('https://')) {
                        _wanUrlCtrl.text = text;
                        setState(() => _pairingSubTab = 1);
                        _connectViaWan();
                        return;
                      }
                    }
                    if (_pairingSubTab == 1 && _wanUrlCtrl.text.isNotEmpty) {
                      _connectViaWan();
                    } else {
                      _manualConnect();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // LOBİ 2: HASSAS LASER TRACKPAD
  // ==========================================
  Widget _buildLobby2Touchpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          // Sensitivity & Quick bar
          Row(
            children: [
              const Icon(Icons.speed, size: 16, color: AppTheme.accentCyan),
              const SizedBox(width: 6),
              const Text("Hassasiyet:", style: TextStyle(fontSize: 11, color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: _mouseSensitivity,
                  min: 0.5,
                  max: 2.5,
                  activeColor: AppTheme.accentCyan,
                  inactiveColor: Colors.white10,
                  onChanged: (v) => setState(() => _mouseSensitivity = v),
                ),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isRightClickMode = !_isRightClickMode);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isRightClickMode ? AppTheme.accentPurple : const Color(0xFF162032),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isRightClickMode ? "Sağ Tık Modu" : "Normal Mod",
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Main Laser Touchpad Area with Right-edge Scroll Ribbon
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: TouchpadWidget(
                    onMove: (dx, dy) => _conn.sendMouseMove(dx * _mouseSensitivity, dy * _mouseSensitivity),
                    onClick: (btn) => _conn.sendMouseClick(_isRightClickMode ? 'right' : btn),
                    onScroll: (dy) => _conn.sendMouseScroll(dy),
                  ),
                ),
                const SizedBox(width: 8),
                // Dedicated Vertical Scroll Ribbon
                Container(
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1524),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      _conn.sendMouseScroll(-details.delta.dy * 0.5);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Icon(Icons.arrow_drop_up, color: AppTheme.accentCyan, size: 20),
                        ),
                        RotatedBox(
                          quarterTurns: 3,
                          child: Text("SCROLL",
                              style: TextStyle(
                                  fontSize: 8.5,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkTextMuted)),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Icon(Icons.arrow_drop_down, color: AppTheme.accentCyan, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Hardware Buttons Row (Sol Tık, Çift Tık, Orta Tık, Sağ Tık)
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildPhysicalButton("SOL TIK", () {
                  HapticFeedback.lightImpact();
                  _conn.sendMouseClick('left');
                }, isPrimary: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _buildPhysicalButton("ÇİFT TIK", () {
                  HapticFeedback.mediumImpact();
                  _conn.sendMouseClick('double');
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _buildPhysicalButton("SAĞ TIK", () {
                  HapticFeedback.mediumImpact();
                  _conn.sendMouseClick('right');
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalButton(String label, VoidCallback onTap, {bool isPrimary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF16243A) : const Color(0xFF121927),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? AppTheme.accentCyan.withOpacity(0.4) : Colors.white12,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isPrimary ? AppTheme.accentCyan : Colors.white,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SAYFA A (LOBİ 2): MONİTÖR YANSITMA (FİZİKSEL 1. VE 2. MONİTÖR)
  // ==========================================
  Widget _buildLobby3ScreenMirror() {
    final allMonitors = _conn.lastStatus?.monitors ?? [];
    // Physical monitors for Mirroring page (Monitor 1 & Monitor 2)
    final mirrorMonitors = allMonitors.length >= 2 ? allMonitors.take(2).toList() : allMonitors;

    return Column(
      children: [
        // Page A Identity & Physical Monitor Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1524),
            border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (mirrorMonitors.isEmpty) {
                      return Row(
                        children: [
                          _buildMonitorTab(0, "🖥️ 1. Monitör (Ana Ekran)"),
                          const SizedBox(width: 8),
                          _buildMonitorTab(1, "🖥️ 2. Monitör (Fiziksel)"),
                        ],
                      );
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(mirrorMonitors.length, (i) {
                          final m = mirrorMonitors[i];
                          final title = i == 0
                              ? "🖥️ 1. Monitör (Ana • ${m.width}x${m.height})"
                              : "🖥️ 2. Monitör (Fiziksel • ${m.width}x${m.height})";
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildMonitorTab(i, title),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  if (_streamFps > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                      ),
                      child: Text(
                        "⚡ $_streamFps FPS",
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: AppTheme.accentCyan),
                    tooltip: "Yenile",
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _startScreenStream();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Mode Info Strip + Quick Jump to Independent 3rd Monitor
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0E172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.accentCyan.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cast_connected, size: 15, color: AppTheme.accentCyan),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Monitör Yansıtma Modu: Şu an ${_selectedMonitor + 1}. fiziksel monitörünüzü yansıtıyorsunuz.",
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
              InkWell(
                onTap: () => _switchLobby(3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF8B5CF6)),
                  ),
                  child: const Text(
                    "➕ Yeni 3. Monitöre Geç",
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFC084FC)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Fullscreen Launch Glowing Banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          width: double.infinity,
          height: 42,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F2FE),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 4,
              shadowColor: const Color(0xFF00F2FE).withOpacity(0.5),
            ),
            icon: const Icon(Icons.fullscreen, size: 20, color: Colors.black),
            label: Text(
              "⛶ ${_selectedMonitor + 1}. MONİTÖRÜ TAM EKRAN YANSIT",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.5),
            ),
            onPressed: () => _toggleFullScreenMonitor(true),
          ),
        ),

        // Live Mirrored Desktop Canvas with Direct Touch-to-Click
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final currentMon = (_conn.lastStatus?.monitors.length ?? 0) > _selectedMonitor
                    ? _conn.lastStatus!.monitors[_selectedMonitor]
                    : null;
                final pcWidth = currentMon?.width ?? (_conn.lastStatus?.screenWidth ?? 1920);
                final pcHeight = currentMon?.height ?? (_conn.lastStatus?.screenHeight ?? 1080);

                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    _pointerDownPos = event.localPosition;
                    _pointerDownTime = DateTime.now();
                    final targetX = (event.localPosition.dx / constraints.maxWidth * pcWidth).clamp(0, pcWidth).round();
                    final targetY = (event.localPosition.dy / constraints.maxHeight * pcHeight).clamp(0, pcHeight).round();
                    _lastDirectTouchX = targetX.toDouble();
                    _lastDirectTouchY = targetY.toDouble();
                  },
                  onPointerMove: (event) {
                    if (_pointerDownPos == null) return;
                    final dist = (event.localPosition - _pointerDownPos!).distance;
                    if (dist > 14.0) {
                      final targetX = (event.localPosition.dx / constraints.maxWidth * pcWidth).clamp(0, pcWidth).round();
                      final targetY = (event.localPosition.dy / constraints.maxHeight * pcHeight).clamp(0, pcHeight).round();
                      _lastDirectTouchX = targetX.toDouble();
                      _lastDirectTouchY = targetY.toDouble();
                      _conn.sendMouseAbs(targetX, targetY, monitor: _selectedMonitor);
                    }
                  },
                  onPointerUp: (event) {
                    final downPos = _pointerDownPos ?? event.localPosition;
                    final downTime = _pointerDownTime ?? DateTime.now();
                    final dist = (event.localPosition - downPos).distance;
                    final elapsedMs = DateTime.now().difference(downTime).inMilliseconds;
                    final targetX = (event.localPosition.dx / constraints.maxWidth * pcWidth).clamp(0, pcWidth).round();
                    final targetY = (event.localPosition.dy / constraints.maxHeight * pcHeight).clamp(0, pcHeight).round();
                    _lastDirectTouchX = targetX.toDouble();
                    _lastDirectTouchY = targetY.toDouble();

                    if (dist < 28.0) {
                      if (elapsedMs >= 450) {
                        HapticFeedback.heavyImpact();
                        _conn.sendMouseAbs(targetX, targetY, click: 'right', monitor: _selectedMonitor);
                      } else {
                        HapticFeedback.lightImpact();
                        _conn.sendMouseAbs(targetX, targetY, click: 'left', monitor: _selectedMonitor);
                      }
                    }
                    _pointerDownPos = null;
                    _pointerDownTime = null;
                  },
                  child: Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF070B12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _screenFrameBytes != null
                            ? AppTheme.accentCyan.withOpacity(0.5)
                            : Colors.white12,
                        width: 1.5,
                      ),
                      boxShadow: [
                        if (_screenFrameBytes != null)
                          BoxShadow(
                            color: AppTheme.accentCyan.withOpacity(0.12),
                            blurRadius: 16,
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_screenFrameBytes != null)
                            Image.memory(
                              _screenFrameBytes!,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                            )
                          else
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppTheme.accentCyan,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _isConnected
                                        ? "🖥️ ${_selectedMonitor + 1}. Fiziksel Monitör Yansıtılıyor..."
                                        : "⚠️ PC Bağlantısı Yok (Lobi 1'den bağlanın)",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isConnected
                                        ? "Ultra-Düşük Gecikmeli Doğrudan GDI Akışı Aktif"
                                        : "PC IP: ${_conn.host}:${_conn.port}",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.darkTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Live Screen status badge
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _screenFrameBytes != null ? AppTheme.accentGreen : Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _screenFrameBytes != null
                                        ? "Yansıtma: ${_selectedMonitor + 1}. Monitör Canlı"
                                        : "Yükleniyor...",
                                    style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Direct Touch Instructions Banner
                          Positioned(
                            bottom: 8,
                            left: 12,
                            right: 12,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                                ),
                                child: const Text(
                                  "👆 Dokun: Sol Tık • Uzun Bas: Sağ Tık • Sürükle: Fare Taşı",
                                  style: TextStyle(fontSize: 9.5, color: AppTheme.accentCyan, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Quick Mouse Control Bar in Lobby 2
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F2FE),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.mouse, size: 16),
                    label: const Text("SOL TIK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      _conn.sendMouseClick('left');
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.touch_app, size: 16),
                    label: const Text("SAĞ TIK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      _conn.sendMouseClick('right');
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _conn.sendMouseClick('double');
                  },
                  child: const Text("Çift Tık", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 18, color: Colors.white70),
                tooltip: "Yukarı Kaydır",
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _conn.sendMouseScroll(120);
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 18, color: Colors.white70),
                tooltip: "Aşağı Kaydır",
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _conn.sendMouseScroll(-120);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonitorTab(int idx, String title) {
    final isSelected = _selectedMonitor == idx;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedMonitor = idx;
          _screenFrameBytes = null;
        });
        _startScreenStream();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentCyan.withOpacity(0.2) : const Color(0xFF141C2B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.accentCyan : Colors.white10),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.accentCyan : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMoveChip(String label, String appKey, {int targetMonitor = 2}) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        _conn.moveAppToMonitor(appKey, monitor: targetMonitor);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withOpacity(0.25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.6)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  // ==========================================
  // SAYFA B (LOBİ 3): 📱 YENİ BAĞIMSIZ 3. MONİTÖR (EXTENDED 3RD DISPLAY) & YAN PANEL
  // ==========================================
  Widget _buildLobby3SidecarAndSecondMonitor() {
    final monitors = _conn.lastStatus?.monitors ?? [];
    final monCount = monitors.length;
    final hasThirdMonitor = monCount >= 3;
    final thirdMonIdx = hasThirdMonitor ? 2 : (monCount > 0 ? monCount - 1 : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-Tab Switcher: Bağımsız 3. Monitör vs Siber Yan Panel
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF101726),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _sidecarSubTab = 0;
                        _selectedMonitor = thirdMonIdx;
                      });
                      _startScreenStream();
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _sidecarSubTab == 0 ? const Color(0xFF8B5CF6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _sidecarSubTab == 0
                            ? [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 8)]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_to_queue, size: 15, color: _sidecarSubTab == 0 ? Colors.white : Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            "📱 Yeni 3. Monitör (Bağımsız)",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _sidecarSubTab == 0 ? Colors.white : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _sidecarSubTab = 1;
                      });
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _sidecarSubTab == 1 ? const Color(0xFF00F2FE) : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dashboard_customize, size: 15, color: _sidecarSubTab == 1 ? Colors.black : Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            "🎛️ Siber Yan Panel Kokpiti",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _sidecarSubTab == 1 ? Colors.black : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // SUB-TAB 0: YENİ BAĞIMSIZ 3. MONİTÖR (TELEFON EKRANI)
          if (_sidecarSubTab == 0) ...[
            // 3rd Monitor Status & Activation Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasThirdMonitor
                      ? [
                          const Color(0xFF059669).withOpacity(0.22),
                          const Color(0xFF8B5CF6).withOpacity(0.18),
                        ]
                      : [
                          const Color(0xFF8B5CF6).withOpacity(0.22),
                          const Color(0xFF1E293B),
                        ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasThirdMonitor
                      ? AppTheme.accentGreen.withOpacity(0.5)
                      : const Color(0xFF8B5CF6).withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (hasThirdMonitor ? AppTheme.accentGreen : const Color(0xFF8B5CF6)).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasThirdMonitor ? Icons.phonelink : Icons.add_to_queue,
                      color: hasThirdMonitor ? AppTheme.accentGreen : const Color(0xFFC084FC),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                hasThirdMonitor
                                    ? "🟢 3. Bağımsız Monitör Aktif [Ekran 3]"
                                    : (_isEnablingVirtualMonitor
                                        ? "⏳ 3. Sanal Monitör Oluşturuluyor..."
                                        : "⚪ 3. Sanal Monitör Kapalı"),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasThirdMonitor
                              ? "1. Monitörde kodlama, 2. Monitörde render yaparken bu ekranda bağımsız müzik/uygulama açabilirsiniz."
                              : "Tek dokunuşla Windows'a 3. bağımsız ekranı ekleyin.",
                          style: const TextStyle(fontSize: 10, color: AppTheme.darkTextMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasThirdMonitor ? const Color(0xFF1E293B) : AppTheme.accentGreen,
                      foregroundColor: hasThirdMonitor ? Colors.redAccent : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isEnablingVirtualMonitor
                        ? null
                        : () {
                            if (hasThirdMonitor) {
                              _disableThirdMonitor();
                            } else {
                              _ensureThirdMonitorActive();
                            }
                          },
                    child: Text(
                      _isEnablingVirtualMonitor
                          ? "..."
                          : (hasThirdMonitor ? "3. Ekranı Kapat" : "➕ 3. Ekranı Aç"),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // One-Tap App Launcher & Window Mover directly to 3rd Monitor
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF14102A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.rocket_launch, size: 13, color: Color(0xFFC084FC)),
                      SizedBox(width: 5),
                      Text(
                        "3. Monitörde (Telefonunda) Şarkı / Uygulama Aç veya Buraya Çek:",
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFC084FC)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickMoveChip("🎵 Spotify", "spotify", targetMonitor: thirdMonIdx),
                        const SizedBox(width: 6),
                        _buildQuickMoveChip("🎶 YouTube Müzik", "ytmusic", targetMonitor: thirdMonIdx),
                        const SizedBox(width: 6),
                        _buildQuickMoveChip("▶️ YouTube", "youtube", targetMonitor: thirdMonIdx),
                        const SizedBox(width: 6),
                        _buildQuickMoveChip("💬 Discord", "discord", targetMonitor: thirdMonIdx),
                        const SizedBox(width: 6),
                        _buildQuickMoveChip("🌐 Tarayıcı", "chrome", targetMonitor: thirdMonIdx),
                        const SizedBox(width: 6),
                        _buildQuickMoveChip("🪟 Aktif Pencereyi Çek", "active", targetMonitor: thirdMonIdx),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Big Glowing Full-Screen 3rd Monitor Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                  shadowColor: const Color(0xFF8B5CF6).withOpacity(0.6),
                ),
                icon: const Icon(Icons.fullscreen, size: 22),
                label: const Text(
                  "⛶ TAM EKRAN 3. MONİTÖRÜ (YATAY MOD) BAŞLAT",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.4),
                ),
                onPressed: () {
                  setState(() {
                    _selectedMonitor = thirdMonIdx;
                  });
                  _toggleFullScreenMonitor(true);
                },
              ),
            ),
            const SizedBox(height: 10),

            // Live 3rd Monitor Interactive Canvas with Direct Touch, Drag, and Right-Click
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF070B12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final currentMon = monitors.length > thirdMonIdx ? monitors[thirdMonIdx] : null;
                    final pcWidth = currentMon?.width ?? 1920;
                    final pcHeight = currentMon?.height ?? 1080;

                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        _pointerDownPos = event.localPosition;
                        _pointerDownTime = DateTime.now();
                        final targetX = (event.localPosition.dx / constraints.maxWidth * pcWidth).clamp(0, pcWidth).round();
                        final targetY = (event.localPosition.dy / constraints.maxHeight * pcHeight).clamp(0, pcHeight).round();
                        _lastDirectTouchX = targetX.toDouble();
                        _lastDirectTouchY = targetY.toDouble();
                      },
                      onPointerMove: (event) {
                        if (_pointerDownPos == null) return;
                        final dist = (event.localPosition - _pointerDownPos!).distance;
                        if (dist > 14.0) {
                          final targetX = (event.localPosition.dx / constraints.maxWidth * pcWidth).clamp(0, pcWidth).round();
                          final targetY = (event.localPosition.dy / constraints.maxHeight * pcHeight).clamp(0, pcHeight).round();
                          _lastDirectTouchX = targetX.toDouble();
                          _lastDirectTouchY = targetY.toDouble();
                          _conn.sendMouseAbs(targetX, targetY, monitor: thirdMonIdx);
                        }
                      },
                      onPointerUp: (event) {
                        final downPos = _pointerDownPos ?? event.localPosition;
                        final downTime = _pointerDownTime ?? DateTime.now();
                        final dist = (event.localPosition - downPos).distance;
                        final elapsedMs = DateTime.now().difference(downTime).inMilliseconds;
                        final targetX = (event.localPosition.dx / constraints.maxWidth * pcWidth).clamp(0, pcWidth).round();
                        final targetY = (event.localPosition.dy / constraints.maxHeight * pcHeight).clamp(0, pcHeight).round();
                        _lastDirectTouchX = targetX.toDouble();
                        _lastDirectTouchY = targetY.toDouble();

                        if (dist < 28.0) {
                          if (elapsedMs >= 450) {
                            HapticFeedback.heavyImpact();
                            _conn.sendMouseAbs(targetX, targetY, click: 'right', monitor: thirdMonIdx);
                          } else {
                            HapticFeedback.lightImpact();
                            _conn.sendMouseAbs(targetX, targetY, click: 'left', monitor: thirdMonIdx);
                          }
                        }
                        _pointerDownPos = null;
                        _pointerDownTime = null;
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_screenFrameBytes != null)
                            Image.memory(
                              _screenFrameBytes!,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                            )
                          else
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _isConnected
                                        ? "📱 Bağımsız 3. Monitör Yayını Alınıyor..."
                                        : "⚠️ PC Bağlantısı Yok",
                                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          // Overlay status badge
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_to_queue, size: 12, color: Color(0xFFC084FC)),
                                  const SizedBox(width: 4),
                                  Text(
                                    "BAĞIMSIZ ${thirdMonIdx + 1}. MONİTÖR (${pcWidth}x$pcHeight)",
                                    style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Touch Tip
                          Positioned(
                            bottom: 8,
                            left: 12,
                            right: 12,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                                ),
                                child: const Text(
                                  "👆 1. ve 2. monitördeki işinizi bölmeden 3. monitöre dokunun",
                                  style: TextStyle(fontSize: 9.5, color: Color(0xFFC084FC), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Dedicated 3rd Monitor Music & Media Control Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.music_note, size: 16, color: Color(0xFFC084FC)),
                      SizedBox(width: 4),
                      Text(
                        "Şarkı / Medya:",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Colors.white, size: 20),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _conn.sendMediaAction('prev');
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _conn.sendMediaAction('play_pause');
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Colors.white, size: 20),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _conn.sendMediaAction('next');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_down, color: Colors.white70, size: 18),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _conn.sendMediaAction('vol_down');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: AppTheme.accentCyan, size: 18),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _conn.sendMediaAction('vol_up');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3-Monitor Layout Guide Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_stories, color: Color(0xFF00F2FE), size: 18),
                      SizedBox(width: 8),
                      Text("💡 3 Monitörlü Çalışma Düzeni Nasıl Çalışır?",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildGuideStepItem(
                    "1",
                    "1. Monitör (Kodlama) & 2. Monitör (Video Render)",
                    "Bilgisayarınızdaki fiziksel 1. ve 2. monitörleriniz tamamen kendi işlerinize ayrılır.",
                  ),
                  const SizedBox(height: 8),
                  _buildGuideStepItem(
                    "2",
                    "3. Monitör: Telefonunuz (Müzik / Yan Ekran)",
                    "Yukarıdaki '🎵 Spotify' veya '🎶 YouTube Müzik' butonuna bastığınızda uygulama doğrudan 3. monitör olan telefonunuza gelir.",
                  ),
                  const SizedBox(height: 8),
                  _buildGuideStepItem(
                    "3",
                    "Odak Koruma (Focus Guard)",
                    "Telefonunuzdaki 3. monitöre dokunup şarkı değiştirdiğinizde, 1. monitördeki kodlama imleciniz ve pencere odağınız bozulmaz!",
                  ),
                ],
              ),
            ),
          ],

          // SUB-TAB 1: SİBER YAN PANEL KOKPİTİ
          if (_sidecarSubTab == 1) ...[
            // Hardware Status Dashboard Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00F2FE).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accentGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${_conn.lastStatus?.hostname ?? 'Windows-PC'} • Canlı Donanım",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${_conn.lastStatus?.screenWidth ?? 1920}x${_conn.lastStatus?.screenHeight ?? 1080}",
                          style: const TextStyle(fontSize: 9.5, color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // CPU Gauge Tile
                      Expanded(
                        child: _buildSidecarMetricTile(
                          "İŞLEMCİ (CPU)",
                          "%${_conn.lastStatus?.cpuPercent.toStringAsFixed(1) ?? '14.5'}",
                          Icons.memory,
                          const Color(0xFF00F2FE),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // RAM Gauge Tile
                      Expanded(
                        child: _buildSidecarMetricTile(
                          "BELLEK (RAM)",
                          "%${_conn.lastStatus?.ramPercent.round() ?? 48}",
                          Icons.storage,
                          const Color(0xFFC084FC),
                          subValue: "${_conn.lastStatus?.ramUsedGb.toStringAsFixed(1) ?? '8.0'} / ${_conn.lastStatus?.ramTotalGb.toStringAsFixed(0) ?? '16'} GB",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick App Launchers Grid (Sidecar Dock)
            const Text("🚀 Yan Panel Hızlı Uygulama Başlatıcı",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.15,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildStreamDeckKey("VS Code", Icons.code, const Color(0xFF007ACC), () => _conn.sendStreamDeckApp("vscode")),
                _buildStreamDeckKey("Chrome", Icons.language, const Color(0xFF4285F4), () => _conn.sendStreamDeckApp("chrome")),
                _buildStreamDeckKey("Spotify", Icons.music_note, const Color(0xFF1DB954), () => _conn.sendStreamDeckApp("spotify")),
                _buildStreamDeckKey("Discord", Icons.chat, const Color(0xFF5865F2), () => _conn.sendStreamDeckApp("discord")),
                _buildStreamDeckKey("YouTube", Icons.play_circle_fill, const Color(0xFFFF0055), () => _conn.sendStreamDeckApp("youtube")),
                _buildStreamDeckKey("Terminal", Icons.terminal, const Color(0xFF00FF88), () => _conn.sendStreamDeckApp("cmd")),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Windows Shortcuts Row
            const Text("⚡ Windows Kısayol Tuşları",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildKeyCap("Win + D", () => _conn.sendShortcut("win_d"))),
                const SizedBox(width: 6),
                Expanded(child: _buildKeyCap("Alt + Tab", () => _conn.sendShortcut("alt_tab"))),
                const SizedBox(width: 6),
                Expanded(child: _buildKeyCap("Görev Yön.", () => _conn.sendShortcut("task_mgr"))),
                const SizedBox(width: 6),
                Expanded(child: _buildKeyCap("Ekran Alıntısı", () => _conn.sendShortcut("screenshot"))),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Media & Volume Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCircleControl(Icons.volume_down, () => _conn.sendMediaAction("vol_down")),
                  _buildCircleControl(Icons.skip_previous, () => _conn.sendMediaAction("prev")),
                  _buildCircleControl(Icons.play_arrow, () => _conn.sendMediaAction("play_pause"), isPrimary: true),
                  _buildCircleControl(Icons.skip_next, () => _conn.sendMediaAction("next")),
                  _buildCircleControl(Icons.volume_up, () => _conn.sendMediaAction("vol_up")),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuideStepItem(String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.25),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF8B5CF6)),
          ),
          alignment: Alignment.center,
          child: Text(num, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFC084FC))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white)),
              const SizedBox(height: 1),
              Text(desc, style: const TextStyle(fontSize: 10, color: AppTheme.darkTextMuted, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidecarMetricTile(String label, String value, IconData icon, Color col, {String? subValue}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.darkTextMuted)),
              Icon(icon, size: 16, color: col),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: col)),
          if (subValue != null) ...[
            const SizedBox(height: 2),
            Text(subValue, style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // LOBİ 4: AKILLI KLAVYE & WINDOWS MAKROLARI
  // ==========================================
  Widget _buildLobby4Keyboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text Sender Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101726),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keyboardInputCtrl,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "PC'ye anında yazmak için metin girin...",
                      hintStyle: TextStyle(color: AppTheme.darkTextMuted, fontSize: 11.5),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (val) {
                      if (val.isNotEmpty) {
                        _conn.sendText(val);
                        _keyboardInputCtrl.clear();
                      }
                    },
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final text = _keyboardInputCtrl.text;
                    if (text.isNotEmpty) {
                      HapticFeedback.lightImpact();
                      _conn.sendText(text);
                      _keyboardInputCtrl.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Metin PC'ye aktarıldı!")),
                      );
                    }
                  },
                  child: const Text("Gönder", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Windows Shortcuts Deck
          const Text("⚡ Windows Kısayol Tuşları",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _buildShortcutButton("Alt + Tab", Icons.tab, () => _conn.sendShortcut("alt_tab")),
              _buildShortcutButton("Win + D (Masaüstü)", Icons.desktop_windows, () => _conn.sendShortcut("win_d")),
              _buildShortcutButton("Görev Yöneticisi", Icons.speed, () => _conn.sendShortcut("task_mgr")),
              _buildShortcutButton("Ekran Alıntısı (Win+S)", Icons.camera_alt, () => _conn.sendShortcut("screenshot")),
              _buildShortcutButton("Ctrl + C (Kopyala)", Icons.copy, () => _conn.sendShortcut("copy")),
              _buildShortcutButton("Ctrl + V (Yapıştır)", Icons.paste, () => _conn.sendShortcut("paste")),
              _buildShortcutButton("Alt + F4 (Kapat)", Icons.close, () => _conn.sendShortcut("alt_f4")),
              _buildShortcutButton("Win + L (Kilitle)", Icons.lock, () => _conn.sendShortcut("win_l")),
            ],
          ),
          const SizedBox(height: 14),

          // Function Keys Strip (F1 - F12)
          const Text("⌨️ Fonksiyon & Yön Tuşları",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildKeyCap("ESC", () => _conn.sendShortcut("esc")),
              _buildKeyCap("ENTER", () => _conn.sendShortcut("enter")),
              _buildKeyCap("TAB", () => _conn.sendShortcut("tab")),
              _buildKeyCap("DEL", () => _conn.sendShortcut("delete")),
              _buildKeyCap("SPACE", () => _conn.sendShortcut("space")),
              _buildKeyCap("F5 (Yenile)", () => _conn.sendShortcut("f5")),
              _buildKeyCap("F11 (Tam Ekran)", () => _conn.sendShortcut("f11")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF121B2C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.accentCyan),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyCap(String text, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF162032),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  // ==========================================
  // LOBİ 5: 🚀 ULTRA STREAM DECK PRO (CUSTOM TASK ATAMALI)
  // ==========================================
  Widget _buildLobby5StreamDeck() {
    return Column(
      children: [
        // Category Tabs
        Container(
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildStreamDeckCategoryTab(0, "🎮 Yayın & Oyun", Icons.videogame_asset),
              const SizedBox(width: 6),
              _buildStreamDeckCategoryTab(1, "💼 Üretkenlik", Icons.work),
              const SizedBox(width: 6),
              _buildStreamDeckCategoryTab(2, "🎵 Soundboard", Icons.music_note),
              const SizedBox(width: 6),
              _buildStreamDeckCategoryTab(3, "⭐ Özel Görevlerim", Icons.star),
            ],
          ),
        ),

        // Stream Deck Grid View
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: _buildStreamDeckContentForCategory(),
          ),
        ),
      ],
    );
  }

  Widget _buildStreamDeckCategoryTab(int idx, String title, IconData icon) {
    final isSelected = _streamDeckCategory == idx;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _streamDeckCategory = idx);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00F2FE).withOpacity(0.2) : const Color(0xFF101726),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF00F2FE) : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? const Color(0xFF00F2FE) : Colors.white70),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF00F2FE) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamDeckContentForCategory() {
    switch (_streamDeckCategory) {
      case 0: // Gaming / Stream
        return GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            _buildStreamDeckKey("OBS Kayıt", Icons.fiber_manual_record, const Color(0xFFFF3366), () => _conn.sendStreamDeckApp("obs")),
            _buildStreamDeckKey("Discord Mute", Icons.mic_off, const Color(0xFF5865F2), () => _conn.sendStreamDeckCmd("powershell -c \"Write-Host Mute\"")),
            _buildStreamDeckKey("Steam Başlat", Icons.sports_esports, const Color(0xFF1B2838), () => _conn.sendStreamDeckApp("steam")),
            _buildStreamDeckKey("Twitch Chat", Icons.live_tv, const Color(0xFF9146FF), () => _conn.sendStreamDeckApp("twitch")),
            _buildStreamDeckKey("Kamera Aç/Kapa", Icons.videocam, const Color(0xFF00F2FE), () => _conn.sendShortcut("win_d")),
            _buildStreamDeckKey("Mikrofon Mute", Icons.volume_off, const Color(0xFFFF9900), () => _conn.sendMediaAction("mute")),
          ],
        );
      case 1: // Productivity
        return GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            _buildStreamDeckKey("VS Code", Icons.code, const Color(0xFF007ACC), () => _conn.sendStreamDeckApp("vscode")),
            _buildStreamDeckKey("Terminal", Icons.terminal, const Color(0xFF00FF88), () => _conn.sendStreamDeckApp("cmd")),
            _buildStreamDeckKey("Google Chrome", Icons.language, const Color(0xFF4285F4), () => _conn.sendStreamDeckApp("chrome")),
            _buildStreamDeckKey("Dosya Gezgini", Icons.folder_open, const Color(0xFFFFB800), () => _conn.sendStreamDeckApp("explorer")),
            _buildStreamDeckKey("Hesap Makinesi", Icons.calculate, const Color(0xFF8A2BE2), () => _conn.sendStreamDeckApp("calc")),
            _buildStreamDeckKey("Not Defteri", Icons.edit_note, const Color(0xFF00F2FE), () => _conn.sendStreamDeckApp("notepad")),
          ],
        );
      case 2: // Soundboard
        return GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            _buildStreamDeckKey("Spotify", Icons.music_note, const Color(0xFF1DB954), () => _conn.sendStreamDeckApp("spotify")),
            _buildStreamDeckKey("Play / Pause", Icons.play_arrow, const Color(0xFF00F2FE), () => _conn.sendMediaAction("play_pause")),
            _buildStreamDeckKey("Sonraki Parça", Icons.skip_next, const Color(0xFF4FACFE), () => _conn.sendMediaAction("next")),
            _buildStreamDeckKey("Önceki Parça", Icons.skip_previous, const Color(0xFF4FACFE), () => _conn.sendMediaAction("prev")),
            _buildStreamDeckKey("Sessize Al", Icons.volume_mute, const Color(0xFFFF3366), () => _conn.sendMediaAction("mute")),
            _buildStreamDeckKey("Tam Ekran", Icons.fullscreen, const Color(0xFFFFB800), () => _conn.sendMediaAction("fullscreen")),
          ],
        );
      case 3: // Custom User Keys
      default:
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: _customKeys.length + 1, // +1 for "Add New Task" button
          itemBuilder: (context, idx) {
            if (idx == _customKeys.length) {
              return _buildAddNewTaskKey();
            }
            final key = _customKeys[idx];
            return _buildStreamDeckKey(key.title, key.icon, key.color, () {
              if (key.actionType == 'app') {
                _conn.sendStreamDeckApp(key.command);
              } else if (key.actionType == 'cmd') {
                _conn.sendStreamDeckCmd(key.command);
              } else if (key.actionType == 'hotkey') {
                _conn.sendShortcut(key.command);
              } else {
                _conn.sendMediaAction(key.command);
              }
            }, onLongPress: () => _showDeleteKeyDialog(idx));
          },
        );
    }
  }

  Widget _buildStreamDeckKey(String title, IconData icon, Color col, VoidCallback onTap, {VoidCallback? onLongPress}) {
    return InkWell(
      onTap: () {
        HapticFeedback.heavyImpact();
        onTap();
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: col.withOpacity(0.5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: col.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: col.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: col),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewTaskKey() {
    return InkWell(
      onTap: _showCustomTaskModal,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1524),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_circle_outline, size: 28, color: AppTheme.accentCyan),
            SizedBox(height: 6),
            Text(
              "+ Görev Ata",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteKeyDialog(int idx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101726),
        title: const Text("Görevi Sil?", style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Text("${_customKeys[idx].title} butonunu silmek istiyor musunuz?",
            style: const TextStyle(color: AppTheme.darkTextMuted, fontSize: 12)),
        actions: [
          TextButton(
            child: const Text("İptal", style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
            onPressed: () {
              setState(() {
                _customKeys.removeAt(idx);
              });
              _saveCustomKeys();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showCustomTaskModal() {
    final titleCtrl = TextEditingController();
    final cmdCtrl = TextEditingController();
    String selectedType = 'app';
    Color selectedColor = const Color(0xFF00F2FE);
    String selectedIconName = 'star';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1626),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("✨ Yeni Stream Deck Görevi Ata",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white60), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Task Title
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Tuş Başlığı (Örn: YouTube Aç)",
                        labelStyle: const TextStyle(color: AppTheme.accentCyan, fontSize: 11),
                        filled: true,
                        fillColor: const Color(0xFF0A0F1A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Action Type Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: const Color(0xFF101726),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: "Görev Türü",
                        labelStyle: const TextStyle(color: AppTheme.accentCyan, fontSize: 11),
                        filled: true,
                        fillColor: const Color(0xFF0A0F1A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'app', child: Text("🚀 Program / Web URL Başlat")),
                        DropdownMenuItem(value: 'hotkey', child: Text("⌨️ Özel Kısayol Tuşu")),
                        DropdownMenuItem(value: 'cmd', child: Text("💻 PowerShell / Terminal Komutu")),
                        DropdownMenuItem(value: 'media', child: Text("🎛️ Özel Medya Eylemi")),
                      ],
                      onChanged: (v) => setModalState(() => selectedType = v ?? 'app'),
                    ),
                    const SizedBox(height: 10),
                    // Command input
                    TextField(
                      controller: cmdCtrl,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: selectedType == 'app'
                            ? "Uygulama veya Web URL (Örn: https://youtube.com veya code)"
                            : (selectedType == 'hotkey' ? "Kısayol (Örn: screenshot, alt_tab, win_d)" : "Komut (Örn: dir, ping 8.8.8.8)"),
                        labelStyle: const TextStyle(color: AppTheme.accentCyan, fontSize: 11),
                        filled: true,
                        fillColor: const Color(0xFF0A0F1A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Color Picker Row
                    const Text("🎨 RGB Neon Renk Seçimi",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const Color(0xFF00F2FE),
                        const Color(0xFFFF0055),
                        const Color(0xFF00FF88),
                        const Color(0xFF8A2BE2),
                        const Color(0xFFFFB800),
                        const Color(0xFF4FACFE),
                      ].map((col) {
                        final isSel = selectedColor == col;
                        return InkWell(
                          onTap: () => setModalState(() => selectedColor = col),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSel ? Colors.white : Colors.transparent, width: 2.5),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F2FE),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          if (titleCtrl.text.isEmpty) return;
                          final newKey = CustomStreamDeckKey(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleCtrl.text.trim(),
                            actionType: selectedType,
                            command: cmdCtrl.text.trim(),
                            iconName: selectedIconName,
                            color: selectedColor,
                          );
                          setState(() {
                            _customKeys.add(newKey);
                          });
                          _saveCustomKeys();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("✅ Yeni Stream Deck Tuşu Kaydedildi!")),
                          );
                        },
                        child: const Text("Tuşu Kaydet ve Ekle", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // LOBİ 6: MEDYA JOG-WHEEL, SUNUM & ⚡ GÜÇ (WAKE-ON-LAN)
  // ==========================================
  Widget _buildLobby6MediaAndPower() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cyber DJ Rotary Jog-Dial Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF101726),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00F2FE).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text("🎛️ Cyber DJ Ses & Medya Kadranı",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                const SizedBox(height: 14),
                // Rotary Dial with Gesture
                GestureDetector(
                  onPanUpdate: (details) {
                    final dy = details.delta.dy;
                    if (dy < -2) {
                      _conn.sendMediaAction("vol_up");
                      setState(() {
                        _volumeLevel = (_volumeLevel + 2).clamp(0.0, 100.0);
                        _rotaryAngle += 0.1;
                      });
                      HapticFeedback.selectionClick();
                    } else if (dy > 2) {
                      _conn.sendMediaAction("vol_down");
                      setState(() {
                        _volumeLevel = (_volumeLevel - 2).clamp(0.0, 100.0);
                        _rotaryAngle -= 0.1;
                      });
                      HapticFeedback.selectionClick();
                    }
                  },
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFF1C273C), Color(0xFF0B101D)],
                      ),
                      border: Border.all(color: const Color(0xFF00F2FE), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F2FE).withOpacity(0.25),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Transform.rotate(
                      angle: _rotaryAngle,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00F2FE),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text("${_volumeLevel.round()}%",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                          const Text("SES DÜZEYİ",
                              style: TextStyle(fontSize: 8, letterSpacing: 1.5, color: AppTheme.darkTextMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Media Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCircleControl(Icons.skip_previous, () => _conn.sendMediaAction("prev")),
                    _buildCircleControl(Icons.play_arrow, () => _conn.sendMediaAction("play_pause"), isPrimary: true),
                    _buildCircleControl(Icons.skip_next, () => _conn.sendMediaAction("next")),
                    _buildCircleControl(Icons.volume_off, () => _conn.sendMediaAction("mute")),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Wake-on-LAN Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF101726),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("⚡ Wake-on-LAN (Uzaktan PC Açma)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                const SizedBox(height: 6),
                const Text("Bilgisayar kapalıyken Magic Packet göndererek uzaktan uyandırın:",
                    style: TextStyle(fontSize: 10.5, color: AppTheme.darkTextMuted)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _macCtrl,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "PC MAC Adresi",
                          labelStyle: const TextStyle(color: AppTheme.accentGreen, fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF0A0F1A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.bolt, size: 16),
                      label: const Text("PC'yi Aç", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        _conn.sendWakeOnLan(_macCtrl.text);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("⚡ WoL Sihirli Paketi Subnet'e Gönderildi!")),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Power Actions Deck
          const Text("🔒 Sistem Güç Eylemleri",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildPowerActionTile("Kilitle", Icons.lock, const Color(0xFF00F2FE), () => _conn.sendPowerAction("lock"))),
              const SizedBox(width: 8),
              Expanded(child: _buildPowerActionTile("Uyut", Icons.bedtime, const Color(0xFF8A2BE2), () => _conn.sendPowerAction("sleep"))),
              const SizedBox(width: 8),
              Expanded(child: _buildPowerActionTile("Yeniden Başlat", Icons.restart_alt, const Color(0xFFFFB800), () => _conn.sendPowerAction("restart"))),
              const SizedBox(width: 8),
              Expanded(child: _buildPowerActionTile("Kapat", Icons.power_settings_new, const Color(0xFFFF3366), () => _showShutdownConfirmDialog())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleControl(IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: isPrimary ? 54 : 44,
        height: isPrimary ? 54 : 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPrimary ? const Color(0xFF00F2FE) : const Color(0xFF162234),
        ),
        child: Icon(icon, size: isPrimary ? 28 : 20, color: isPrimary ? Colors.black : Colors.white),
      ),
    );
  }

  Widget _buildPowerActionTile(String label, IconData icon, Color col, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.heavyImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: col.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: col.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: col),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: col)),
          ],
        ),
      ),
    );
  }

  void _showShutdownConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101726),
        title: const Text("⚠️ Bilgisayarı Kapat?", style: TextStyle(color: Colors.white, fontSize: 15)),
        content: const Text("Bilgisayar kapatılacak. Onaylıyor musunuz?",
            style: TextStyle(color: AppTheme.darkTextMuted, fontSize: 12)),
        actions: [
          TextButton(
            child: const Text("İptal", style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3366)),
            child: const Text("Kapat", style: TextStyle(color: Colors.white)),
            onPressed: () {
              _conn.sendPowerAction("shutdown");
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // --- BOTTOM DOCK NAVIGATION ---
  Widget _buildBottomDock() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF0B101C),
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDockItem(0, Icons.link, "Giriş"),
          _buildDockItem(1, Icons.touch_app, "Trackpad"),
          _buildDockItem(2, Icons.cast_connected, "Yansıtma"),
          _buildDockItem(3, Icons.add_to_queue, "Yeni Monitör", isSpecial: true),
          _buildDockItem(4, Icons.keyboard, "Klavye"),
          _buildDockItem(5, Icons.grid_view, "Stream Deck"),
          _buildDockItem(6, Icons.music_note, "Medya/Güç"),
        ],
      ),
    );
  }

  Widget _buildDockItem(int idx, IconData icon, String label, {bool isSpecial = false}) {
    final isSelected = _activeLobbyIndex == idx;
    return InkWell(
      onTap: () => _switchLobby(idx),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: isSpecial ? 22 : 18,
            color: isSelected
                ? const Color(0xFF00F2FE)
                : (isSpecial ? const Color(0xFFFFB800) : AppTheme.darkTextMuted),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppTheme.darkTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FULLSCREEN TOUCH MONITOR (TAM EKRAN DOKUNMATİK MONİTÖR)
  // ==========================================
  Widget _buildFullScreenTouchMonitor() {
    final currentMon = (_conn.lastStatus?.monitors.length ?? 0) > _selectedMonitor
        ? _conn.lastStatus!.monitors[_selectedMonitor]
        : null;
    final pcWidth = currentMon?.width ?? (_conn.lastStatus?.screenWidth ?? 1920);
    final pcHeight = currentMon?.height ?? (_conn.lastStatus?.screenHeight ?? 1080);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _toggleFullScreenMonitor(false);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final screenH = constraints.maxHeight;

            return Stack(
              children: [
                // 1. Edge-to-Edge Desktop Stream & Touch Surface
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      _pointerDownPos = event.localPosition;
                      _pointerDownTime = DateTime.now();
                      final targetX = (event.localPosition.dx / screenW * pcWidth).clamp(0, pcWidth).round();
                      final targetY = (event.localPosition.dy / screenH * pcHeight).clamp(0, pcHeight).round();
                      _lastDirectTouchX = targetX.toDouble();
                      _lastDirectTouchY = targetY.toDouble();
                      if (_isMouseDragLocked) {
                        _conn.sendMouseDown(targetX, targetY, btn: 'left', monitor: _selectedMonitor);
                      }
                    },
                    onPointerMove: (event) {
                      if (_pointerDownPos == null) return;
                      final dist = (event.localPosition - _pointerDownPos!).distance;
                      if (dist > 14.0 || _isMouseDragLocked) {
                        final targetX = (event.localPosition.dx / screenW * pcWidth).clamp(0, pcWidth).round();
                        final targetY = (event.localPosition.dy / screenH * pcHeight).clamp(0, pcHeight).round();
                        _lastDirectTouchX = targetX.toDouble();
                        _lastDirectTouchY = targetY.toDouble();
                        _conn.sendMouseAbs(targetX, targetY, monitor: _selectedMonitor);
                      }
                    },
                    onPointerUp: (event) {
                      final downPos = _pointerDownPos ?? event.localPosition;
                      final downTime = _pointerDownTime ?? DateTime.now();
                      final dist = (event.localPosition - downPos).distance;
                      final elapsedMs = DateTime.now().difference(downTime).inMilliseconds;
                      final targetX = (event.localPosition.dx / screenW * pcWidth).clamp(0, pcWidth).round();
                      final targetY = (event.localPosition.dy / screenH * pcHeight).clamp(0, pcHeight).round();
                      _lastDirectTouchX = targetX.toDouble();
                      _lastDirectTouchY = targetY.toDouble();

                      if (_isMouseDragLocked) {
                        _conn.sendMouseUp(targetX, targetY, btn: 'left', monitor: _selectedMonitor);
                      } else if (dist < 28.0) {
                        if (elapsedMs >= 450) {
                          HapticFeedback.heavyImpact();
                          _conn.sendMouseAbs(targetX, targetY, click: 'right', monitor: _selectedMonitor);
                        } else {
                          HapticFeedback.lightImpact();
                          _conn.sendMouseAbs(targetX, targetY, click: 'left', monitor: _selectedMonitor);
                        }
                      }
                      _pointerDownPos = null;
                      _pointerDownTime = null;
                    },
                    child: _screenFrameBytes != null
                        ? Image.memory(
                            _screenFrameBytes!,
                            width: screenW,
                            height: screenH,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          )
                        : Container(
                            color: const Color(0xFF070B12),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: AppTheme.accentCyan,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedMonitor == 1
                                        ? "🖥️ Genişletilmiş 2. Monitör Başlatılıyor..."
                                        : "🖥️ Tam Ekran Dokunmatik Monitör Başlatılıyor...",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Çözünürlük: $pcWidth x $pcHeight • Monitör ${_selectedMonitor + 1}",
                                    style: const TextStyle(
                                      color: AppTheme.darkTextMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),

                // 2. Floating Draggable Cyber Action HUD
                Positioned(
                  left: _hudPosition.dx.clamp(8.0, math.max(8.0, screenW - 280.0)),
                  top: _hudPosition.dy.clamp(8.0, math.max(8.0, screenH - 60.0)),
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _hudPosition += details.delta;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xE60D1527),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF00F2FE).withOpacity(0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: const Color(0xFF00F2FE).withOpacity(0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag Handle Icon
                          const Icon(Icons.drag_indicator, size: 16, color: Colors.white38),
                          const SizedBox(width: 4),

                          // Monitor Number Pill / Switcher
                          InkWell(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              final monCount = _conn.lastStatus?.monitors.length ?? 2;
                              setState(() {
                                _selectedMonitor = (_selectedMonitor + 1) % math.max(1, monCount);
                                _screenFrameBytes = null;
                              });
                              _startScreenStream();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: (_selectedMonitor == 1 ? const Color(0xFF8B5CF6) : AppTheme.accentCyan).withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _selectedMonitor == 1 ? const Color(0xFF8B5CF6) : AppTheme.accentCyan,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.desktop_windows,
                                    size: 11,
                                    color: _selectedMonitor == 1 ? const Color(0xFFC084FC) : AppTheme.accentCyan,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    "M${_selectedMonitor + 1}",
                                    style: TextStyle(
                                      color: _selectedMonitor == 1 ? const Color(0xFFC084FC) : AppTheme.accentCyan,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // FPS Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _streamFps > 0 ? "$_streamFps FPS" : "CANLI",
                              style: const TextStyle(
                                color: AppTheme.accentGreen,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          if (!_isHudCollapsed) ...[
                            // Keyboard Input Modal Button
                            _buildHudIconButton(
                              icon: Icons.keyboard,
                              color: AppTheme.accentCyan,
                              tooltip: "Klavye",
                              onTap: _showOnScreenKeyboardModal,
                            ),
                            const SizedBox(width: 4),

                            // Right Click Simulator Button
                            _buildHudIconButton(
                              icon: Icons.mouse,
                              color: const Color(0xFFC084FC),
                              tooltip: "Sağ Tık",
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                _conn.sendMouseClick('right');
                              },
                            ),
                            const SizedBox(width: 4),

                            // Windows Shortcuts Menu Button
                            _buildHudIconButton(
                              icon: Icons.bolt,
                              color: const Color(0xFFFFB800),
                              tooltip: "Kısayollar",
                              onTap: _showQuickShortcutsModal,
                            ),
                            const SizedBox(width: 4),

                            // Refresh Stream Button
                            _buildHudIconButton(
                              icon: Icons.refresh,
                              color: const Color(0xFF00FF88),
                              tooltip: "Yenile",
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _startScreenStream();
                              },
                            ),
                            const SizedBox(width: 4),

                            // Floating Mouse Controller Toggle
                            _buildHudIconButton(
                              icon: Icons.touch_app,
                              color: _showFloatingMouseController ? const Color(0xFF00F2FE) : Colors.white38,
                              tooltip: "Fare Kumandası",
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _showFloatingMouseController = !_showFloatingMouseController;
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                          ],

                          // HUD Collapse / Expand Button
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isHudCollapsed = !_isHudCollapsed;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _isHudCollapsed ? Icons.chevron_right : Icons.chevron_left,
                                size: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Exit Full-Screen Button
                          InkWell(
                            onTap: () => _toggleFullScreenMonitor(false),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3366).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFF3366).withOpacity(0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fullscreen_exit, size: 14, color: Color(0xFFFF3366)),
                                  SizedBox(width: 4),
                                  Text(
                                    "Çıkış",
                                    style: TextStyle(
                                      color: Color(0xFFFF3366),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Floating Draggable Cyber Mouse Controller
                if (_showFloatingMouseController)
                  Positioned(
                    left: _floatingMousePos.dx.clamp(8.0, math.max(8.0, screenW - (_isFloatingMouseCollapsed ? 95.0 : 210.0))),
                    top: _floatingMousePos.dy.clamp(8.0, math.max(8.0, screenH - (_isFloatingMouseCollapsed ? 50.0 : 310.0))),
                    child: _buildFloatingMouseWidget(screenW, screenH),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // FLOATING & DRAGGABLE CYBER MOUSE CONTROLLER
  // ==========================================
  Widget _buildFloatingMouseWidget(double screenW, double screenH) {
    if (_isFloatingMouseCollapsed) {
      return GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _floatingMousePos += details.delta;
          });
        },
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _isFloatingMouseCollapsed = false;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xE60A101D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00F2FE), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F2FE).withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mouse, size: 16, color: Color(0xFF00F2FE)),
                SizedBox(width: 6),
                Text(
                  "FARE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xF2090E1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00F2FE).withOpacity(0.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.85),
            blurRadius: 18,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: const Color(0xFF00F2FE).withOpacity(0.2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Drag Handle & Quick Snap & Collapse
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _floatingMousePos += details.delta;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0x3300F2FE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.drag_indicator, size: 16, color: Colors.white60),
                  const SizedBox(width: 2),
                  const Expanded(
                    child: Text(
                      "FARE KUMANDASI",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Quick Snap Left
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _floatingMousePos = Offset(12, _floatingMousePos.dy);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text("SOL", style: TextStyle(fontSize: 8, color: Color(0xFF00F2FE), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Quick Snap Right
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _floatingMousePos = Offset(math.max(12, screenW - 215), _floatingMousePos.dy);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text("SAĞ", style: TextStyle(fontSize: 8, color: Color(0xFF00F2FE), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Minimize button
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isFloatingMouseCollapsed = true;
                      });
                    },
                    child: const Icon(Icons.remove, size: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mini Precision Trackpad Surface
                GestureDetector(
                  onPanUpdate: (details) {
                    _conn.sendMouseMove(details.delta.dx * 1.5, details.delta.dy * 1.5);
                  },
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _conn.sendMouseClick('left');
                  },
                  onDoubleTap: () {
                    HapticFeedback.mediumImpact();
                    _conn.sendMouseClick('double');
                  },
                  child: Container(
                    height: 75,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF060A14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, size: 20, color: const Color(0xFF00F2FE).withOpacity(0.5)),
                          const SizedBox(height: 3),
                          Text(
                            "Hassas Trackpad\n(Kaydır / Tıkla)",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.4),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Big Primary Click Buttons: SOL TIK & SAĞ TIK
                Row(
                  children: [
                    // SOL TIK (Cyan)
                    Expanded(
                      flex: 6,
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00F2FE),
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 4,
                          ),
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            _conn.sendMouseClick('left');
                          },
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mouse, size: 15, color: Colors.black),
                              SizedBox(height: 2),
                              Text(
                                "SOL TIK",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // SAĞ TIK (Purple)
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 4,
                          ),
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            _conn.sendMouseClick('right');
                          },
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.touch_app, size: 15, color: Colors.white),
                              SizedBox(height: 2),
                              Text(
                                "SAĞ TIK",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Secondary Row: Çift Tık & Sürükle (Drag Lock)
                Row(
                  children: [
                    // Çift Tık
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _conn.sendMouseClick('double');
                          },
                          child: const Text("Çift Tık", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Drag Lock
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isMouseDragLocked ? Colors.amber : Colors.white70,
                            side: BorderSide(
                              color: _isMouseDragLocked ? Colors.amber : Colors.white24,
                              width: _isMouseDragLocked ? 1.5 : 1.0,
                            ),
                            backgroundColor: _isMouseDragLocked ? Colors.amber.withOpacity(0.15) : null,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _isMouseDragLocked = !_isMouseDragLocked;
                            });
                            if (_isMouseDragLocked) {
                              _conn.sendMouseDown(_lastDirectTouchX.round(), _lastDirectTouchY.round(), btn: 'left', monitor: _selectedMonitor);
                            } else {
                              _conn.sendMouseUp(_lastDirectTouchX.round(), _lastDirectTouchY.round(), btn: 'left', monitor: _selectedMonitor);
                            }
                          },
                          child: Text(
                            _isMouseDragLocked ? "🔒 Sürükle" : "Sürükle",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isMouseDragLocked ? Colors.amber : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Scroll Row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white60,
                            side: const BorderSide(color: Colors.white12),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.arrow_upward, size: 12),
                          label: const Text("Yukarı", style: TextStyle(fontSize: 9)),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _conn.sendMouseScroll(120);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white60,
                            side: const BorderSide(color: Colors.white12),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.arrow_downward, size: 12),
                          label: const Text("Aşağı", style: TextStyle(fontSize: 9)),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _conn.sendMouseScroll(-120);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Game-Safe Media Strip (Play/Pause/Next/Mute without stealing focus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101829),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _conn.sendMediaAction('prev');
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.skip_previous, size: 15, color: Colors.white70),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _conn.sendMediaAction('play_pause');
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.play_arrow, size: 17, color: Color(0xFF00F2FE)),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _conn.sendMediaAction('next');
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.skip_next, size: 15, color: Colors.white70),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _conn.sendMediaAction('mute');
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.volume_off, size: 14, color: Color(0xFFFF3366)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  void _showQuickShortcutsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "⚡ Hızlı Windows Kısayolları",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _buildShortcutButton("Alt+Tab", Icons.tab, () {
                    _conn.sendShortcut("alt_tab");
                    Navigator.pop(ctx);
                  }),
                  _buildShortcutButton("Win+D", Icons.desktop_windows, () {
                    _conn.sendShortcut("win_d");
                    Navigator.pop(ctx);
                  }),
                  _buildShortcutButton("Görev Yön.", Icons.speed, () {
                    _conn.sendShortcut("task_mgr");
                    Navigator.pop(ctx);
                  }),
                  _buildShortcutButton("Kopyala", Icons.copy, () {
                    _conn.sendShortcut("copy");
                    Navigator.pop(ctx);
                  }),
                  _buildShortcutButton("Yapıştır", Icons.paste, () {
                    _conn.sendShortcut("paste");
                    Navigator.pop(ctx);
                  }),
                  _buildShortcutButton("ESC", Icons.keyboard_return, () {
                    _conn.sendShortcut("esc");
                    Navigator.pop(ctx);
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
