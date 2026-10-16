import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'udp_helper.dart';

class HostStatus {
  final bool isOnline;
  final String deskId;
  final String hostname;
  final String ip;
  final int port;
  final String os;
  final double cpuPercent;
  final double ramPercent;
  final double ramUsedGb;
  final double ramTotalGb;
  final int battery;
  final int screenWidth;
  final int screenHeight;
  final List<MonitorInfo> monitors;

  HostStatus({
    required this.isOnline,
    this.deskId = "849 210 492",
    this.hostname = "Windows-PC",
    this.ip = "192.168.1.145",
    this.port = 8000,
    this.os = "Windows 11 PRO",
    this.cpuPercent = 14.5,
    this.ramPercent = 48.0,
    this.ramUsedGb = 8.0,
    this.ramTotalGb = 16.0,
    this.battery = 100,
    this.screenWidth = 1920,
    this.screenHeight = 1080,
    this.monitors = const [],
  });

  factory HostStatus.fromJson(Map<String, dynamic> json) {
    var monList = <MonitorInfo>[];
    if (json['monitors'] != null) {
      for (var m in json['monitors']) {
        monList.add(MonitorInfo.fromJson(m));
      }
    }
    return HostStatus(
      isOnline: true,
      deskId: json['desk_id'] ?? "849 210 492",
      hostname: json['device_name'] ?? "Windows-PC",
      ip: json['ip'] ?? "127.0.0.1",
      port: json['port'] ?? 8000,
      os: json['os'] ?? "Windows",
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 15.0,
      ramPercent: (json['ram_percent'] as num?)?.toDouble() ?? 45.0,
      ramUsedGb: (json['ram_used_gb'] as num?)?.toDouble() ?? 8.0,
      ramTotalGb: (json['ram_total_gb'] as num?)?.toDouble() ?? 16.0,
      battery: (json['battery'] as num?)?.toInt() ?? 100,
      screenWidth: (json['screen_width'] as num?)?.toInt() ?? 1920,
      screenHeight: (json['screen_height'] as num?)?.toInt() ?? 1080,
      monitors: monList,
    );
  }
}

class MonitorInfo {
  final int id;
  final String name;
  final int width;
  final int height;
  final bool isPrimary;

  MonitorInfo({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.isPrimary,
  });

  factory MonitorInfo.fromJson(Map<String, dynamic> json) {
    return MonitorInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? "Display",
      width: json['width'] ?? 1920,
      height: json['height'] ?? 1080,
      isPrimary: json['is_primary'] ?? false,
    );
  }
}

class ConnectionService {
  String host = '192.168.1.20';
  int port = 8000;
  String pin = '793 421';
  String deskId = '849 210 492';
  String wanUrl = '';
  bool isWanMode = false;
  bool isConnected = false;
  bool isDemoMode = false;
  int latencyMs = 1;

  HostStatus? lastStatus;

  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal() {
    if (kIsWeb && Uri.base.host.isNotEmpty) {
      host = Uri.base.host;
      if (Uri.base.hasPort && Uri.base.port > 0) {
        port = Uri.base.port;
      }
      if (Uri.base.scheme == 'https') {
        isWanMode = true;
        wanUrl = Uri.base.origin;
      }
    }
  }

  String get baseUrl {
    if (kIsWeb && Uri.base.host.isNotEmpty && !isWanMode && host == Uri.base.host) {
      return Uri.base.origin;
    }
    if (isWanMode && wanUrl.isNotEmpty) {
      var u = wanUrl.trim();
      if (!u.startsWith('http://') && !u.startsWith('https://')) {
        u = 'https://$u';
      }
      if (u.endsWith('/')) {
        u = u.substring(0, u.length - 1);
      }
      return u;
    }

    var h = host.trim();
    if (h.startsWith('http://') || h.startsWith('https://')) {
      if (h.endsWith('/')) {
        h = h.substring(0, h.length - 1);
      }
      return h;
    }
    if (h.contains('.trycloudflare.com') || h.contains('.pinggy.link') || h.contains('.loca.lt')) {
      return 'https://$h';
    }
    return 'http://$h:$port';
  }

  final StreamController<bool> _connectionStreamController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStreamController.stream;

  Future<void> saveSettings(
    String newHost,
    int newPort,
    String newPin,
    String newDeskId, {
    bool wanMode = false,
    String? newWanUrl,
  }) async {
    host = newHost;
    port = newPort;
    pin = newPin;
    deskId = newDeskId;
    isWanMode = wanMode;
    if (newWanUrl != null) wanUrl = newWanUrl;
    final cleanId = newDeskId.replaceAll(' ', '');
    isDemoMode = cleanId == '000000000' || newHost.toLowerCase() == 'demo';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pc_host', host);
    await prefs.setInt('pc_port', port);
    await prefs.setString('pc_pin', pin);
    await prefs.setString('pc_desk_id', deskId);
    await prefs.setBool('pc_is_wan_mode', isWanMode);
    await prefs.setString('pc_wan_url', wanUrl);
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb && Uri.base.host.isNotEmpty) {
      host = Uri.base.host;
      port = Uri.base.hasPort && Uri.base.port > 0 ? Uri.base.port : 8000;
    } else {
      host = prefs.getString('pc_host') ?? '192.168.1.20';
      port = prefs.getInt('pc_port') ?? 8000;
    }
    pin = prefs.getString('pc_pin') ?? '793 421';
    deskId = prefs.getString('pc_desk_id') ?? '849 210 492';
    isWanMode = prefs.getBool('pc_is_wan_mode') ?? false;
    wanUrl = prefs.getString('pc_wan_url') ?? '';
  }

  Future<bool> checkConnection() async {
    if (isDemoMode || deskId.replaceAll(' ', '') == '000000000') {
      isDemoMode = true;
      isConnected = true;
      latencyMs = 2;
      lastStatus = HostStatus(
        isOnline: true,
        deskId: "000 000 000",
        hostname: "Demo-Gaming-PC",
        ip: "192.168.1.20",
        port: 8000,
        os: "Windows 11 PRO",
        cpuPercent: 18.4,
        ramPercent: 42.0,
        ramUsedGb: 13.4,
        ramTotalGb: 32.0,
        battery: 100,
        screenWidth: 1920,
        screenHeight: 1080,
        monitors: [
          MonitorInfo(id: 0, name: "🖥️ Monitör 1 (Ana Ekran - 1920x1080)", width: 1920, height: 1080, isPrimary: true),
          MonitorInfo(id: 1, name: "🖥️ Monitör 2 (Yan Ekran - 1920x1080)", width: 1920, height: 1080, isPrimary: false),
        ],
      );
      _connectionStreamController.add(true);
      return true;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/status'))
          .timeout(const Duration(milliseconds: 3000));
      stopwatch.stop();
      latencyMs = stopwatch.elapsedMilliseconds;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        lastStatus = HostStatus.fromJson(data);
        isConnected = true;
        _connectionStreamController.add(true);
        return true;
      }
    } catch (_) {
      isConnected = false;
      _connectionStreamController.add(false);
    }
    return isConnected;
  }

  // --- Input APIs ---

  void sendMouseMove(double dx, double dy) {
    if (isDemoMode) return;
    http.get(Uri.parse('$baseUrl/api/mouse/move?dx=${dx.round()}&dy=${dy.round()}'));
  }

  void sendMouseAbs(int x, int y, {String? click, int monitor = 0}) {
    if (isDemoMode) return;
    final clickParam = click != null ? '&click=$click' : '';
    http.get(Uri.parse('$baseUrl/api/mouse/abs?x=$x&y=$y&monitor=$monitor$clickParam'));
  }

  void sendMouseDown(int x, int y, {String btn = 'left', int monitor = 0}) {
    if (isDemoMode) return;
    http.get(Uri.parse('$baseUrl/api/mouse/down?x=$x&y=$y&btn=$btn&monitor=$monitor'));
  }

  void sendMouseUp(int x, int y, {String btn = 'left', int monitor = 0}) {
    if (isDemoMode) return;
    http.get(Uri.parse('$baseUrl/api/mouse/up?x=$x&y=$y&btn=$btn&monitor=$monitor'));
  }

  void sendMouseClick(String btn) {
    if (isDemoMode) return;
    http.get(Uri.parse('$baseUrl/api/mouse/click?btn=$btn'));
  }

  void sendMouseScroll(double dy) {
    if (isDemoMode) return;
    http.get(Uri.parse('$baseUrl/api/mouse/scroll?dy=${dy.round()}'));
  }

  void sendText(String text) {
    if (isDemoMode) return;
    final encoded = Uri.encodeComponent(text);
    http.get(Uri.parse('$baseUrl/api/keyboard/type?text=$encoded'));
  }

  void sendShortcut(String combo) {
    if (isDemoMode) return;
    http.get(Uri.parse('$baseUrl/api/keyboard/shortcut?combo=$combo'));
  }

  Future<Uint8List?> fetchScreenFrame({int monitor = 0, double scale = 0.65, int quality = 75}) async {
    if (isDemoMode) return null;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/screen/frame?monitor=$monitor&scale=$scale&q=$quality'))
          .timeout(const Duration(milliseconds: 1500));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  // --- Stream Deck APIs ---

  void sendStreamDeckApp(String app) {
    if (isDemoMode) return;
    final encoded = Uri.encodeComponent(app);
    http.get(Uri.parse('$baseUrl/api/streamdeck/launch?app=$encoded'));
  }

  void sendStreamDeckCmd(String cmd) {
    if (isDemoMode) return;
    final encoded = Uri.encodeComponent(cmd);
    http.get(Uri.parse('$baseUrl/api/streamdeck/command?cmd=$encoded'));
  }

  void moveAppToMonitor(String app, {int monitor = 1}) {
    if (isDemoMode) return;
    final encoded = Uri.encodeComponent(app);
    http.get(Uri.parse('$baseUrl/api/monitors/move_app?app=$encoded&monitor=$monitor'));
  }

  // --- Media & Power APIs ---

  void sendMediaAction(String act) {
    if (isDemoMode) return;
    http.get(Uri.parse('$baseUrl/api/media/action?act=$act'));
  }

  void sendPowerAction(String act) {
    if (isDemoMode) return;
    http.get(Uri.parse('$baseUrl/api/power/action?act=$act'));
  }

  Future<void> sendWakeOnLan(String mac) async {
    if (isDemoMode) return;
    try {
      final cleanMac = mac.replaceAll(':', '').replaceAll('-', '');
      if (cleanMac.length != 12) return;

      final bytes = <int>[];
      for (var i = 0; i < 6; i++) {
        bytes.add(0xFF);
      }
      final macBytes = <int>[];
      for (var i = 0; i < 12; i += 2) {
        macBytes.add(int.parse(cleanMac.substring(i, i + 2), radix: 16));
      }
      for (var i = 0; i < 16; i++) {
        bytes.addAll(macBytes);
      }

      await sendUdpWakeOnLan(bytes);
    } catch (e) {
      debugPrint("WoL Error: $e");
    }
  }
}
