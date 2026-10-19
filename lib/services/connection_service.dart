import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
  final bool authRequired;
  final bool isAuthenticated;
  final bool isTunnelActive;
  final String tunnelUrl;
  final bool virtualMonitorActive;

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
    this.authRequired = true,
    this.isAuthenticated = false,
    this.isTunnelActive = false,
    this.tunnelUrl = "",
    this.virtualMonitorActive = false,
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
      authRequired: json['auth_required'] ?? true,
      isAuthenticated: json['is_authenticated'] ?? false,
      isTunnelActive: json['is_tunnel_active'] ?? false,
      tunnelUrl: json['tunnel_url'] ?? "",
      virtualMonitorActive: json['virtual_monitor_active'] ?? (monList.length >= 3),
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
  String autoWanUrl = '';
  bool isWanMode = false;
  bool isConnected = false;
  bool isDemoMode = false;
  int latencyMs = 1;

  // Zero-Trust Security State
  String authToken = '';
  String deviceId = '';
  String deviceName = 'Mobil Cihaz';
  String masterEmail = 'admin@pcremote.local';
  bool isAuthenticated = false;
  bool authRequired = true;

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

  String get effectiveWanUrl {
    if (wanUrl.isNotEmpty) return wanUrl;
    if (autoWanUrl.isNotEmpty) return autoWanUrl;
    return '';
  }

  String get baseUrl {
    if (kIsWeb && Uri.base.host.isNotEmpty && !isWanMode && host == Uri.base.host) {
      return Uri.base.origin;
    }
    if (isWanMode) {
      var u = effectiveWanUrl.trim();
      if (u.isNotEmpty) {
        if (!u.startsWith('http://') && !u.startsWith('https://')) {
          u = 'https://$u';
        }
        if (u.endsWith('/')) {
          u = u.substring(0, u.length - 1);
        }
        return u;
      }
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

  String _localBaseUrl() {
    var h = host.trim();
    if (h.startsWith('http://') || h.startsWith('https://')) {
      if (h.endsWith('/')) h = h.substring(0, h.length - 1);
      return h;
    }
    return 'http://$h:$port';
  }

  String _url(String endpointAndQuery) {
    final sep = endpointAndQuery.contains('?') ? '&' : '?';
    final tokenParam = authToken.isNotEmpty ? '${sep}token=$authToken' : '';
    return '$baseUrl$endpointAndQuery$tokenParam';
  }

  Map<String, String> get authHeaders => authToken.isNotEmpty
      ? {
          'Authorization': 'Bearer $authToken',
          'X-PCRemote-Token': authToken,
        }
      : {};

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
    await prefs.setString('pc_auto_wan_url', autoWanUrl);
    await prefs.setString('pc_auth_token', authToken);
    await prefs.setString('pc_device_id', deviceId);
    await prefs.setString('pc_device_name', deviceName);
    await prefs.setString('pc_master_email', masterEmail);
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
    autoWanUrl = prefs.getString('pc_auto_wan_url') ?? '';
    authToken = prefs.getString('pc_auth_token') ?? '';
    masterEmail = prefs.getString('pc_master_email') ?? 'admin@pcremote.local';

    deviceId = prefs.getString('pc_device_id') ?? '';
    if (deviceId.isEmpty) {
      final rand = math.Random().nextInt(999999);
      deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}_$rand';
      await prefs.setString('pc_device_id', deviceId);
    }

    deviceName = prefs.getString('pc_device_name') ?? '';
    if (deviceName.isEmpty) {
      if (kIsWeb) {
        deviceName = 'Web / Safari İstemci';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        deviceName = 'Apple iPhone';
      } else {
        deviceName = 'Android Cihaz';
      }
      await prefs.setString('pc_device_name', deviceName);
    }
  }

  /// Intelligently checks connection with seamless Wi-Fi <-> WAN auto fallback.
  Future<bool> checkConnection() async {
    if (isDemoMode || deskId.replaceAll(' ', '') == '000000000') {
      isDemoMode = true;
      isConnected = true;
      isAuthenticated = true;
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
        authRequired: false,
        isAuthenticated: true,
      );
      _connectionStreamController.add(true);
      return true;
    }

    final stopwatch = Stopwatch()..start();

    // 1. Try currently configured mode
    bool success = await _pingEndpoint(baseUrl, stopwatch);

    // 2. Seamless Auto-Fallback:
    // If we're on Wi-Fi mode and it fails, but we have an autoWanUrl or wanUrl, try WAN automatically!
    if (!success && !isWanMode && effectiveWanUrl.isNotEmpty) {
      debugPrint("🔄 Yerel Wi-Fi yanıt vermedi, otomatik Güvenli Bulut (WAN) deneniyor...");
      stopwatch.reset();
      stopwatch.start();
      isWanMode = true;
      success = await _pingEndpoint(baseUrl, stopwatch);
      if (!success) {
        // If WAN also failed, revert mode
        isWanMode = false;
      } else {
        debugPrint("🌐 Otomatik WAN bağlantısı başarıyla kuruldu!");
      }
    } else if (success && isWanMode && !kIsWeb) {
      // If we are currently on WAN mode, silently test if we are back home on Wi-Fi
      _testLocalReturn();
    }

    isConnected = success;
    _connectionStreamController.add(isConnected);
    return isConnected;
  }

  Future<bool> _pingEndpoint(String base, Stopwatch sw) async {
    try {
      final sep = base.contains('?') ? '&' : '?';
      final tokenQuery = authToken.isNotEmpty ? '${sep}token=$authToken' : '';
      final uri = Uri.parse('$base/api/status$tokenQuery');

      final res = await http.get(uri, headers: authHeaders).timeout(const Duration(milliseconds: 2800));
      sw.stop();
      latencyMs = sw.elapsedMilliseconds;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        lastStatus = HostStatus.fromJson(data);
        authRequired = data['auth_required'] ?? true;
        isAuthenticated = data['is_authenticated'] ?? false;

        // Cache live tunnel URL if reported by host
        final hostTunnelUrl = (data['tunnel_url'] as String?) ?? '';
        if (hostTunnelUrl.isNotEmpty && hostTunnelUrl != autoWanUrl) {
          autoWanUrl = hostTunnelUrl;
          SharedPreferences.getInstance().then((p) => p.setString('pc_auto_wan_url', autoWanUrl));
        }

        return true;
      }
    } catch (_) {}
    return false;
  }

  void _testLocalReturn() async {
    try {
      final localUrl = _localBaseUrl();
      final uri = Uri.parse('$localUrl/api/status?token=$authToken');
      final res = await http.get(uri, headers: authHeaders).timeout(const Duration(milliseconds: 1000));
      if (res.statusCode == 200) {
        debugPrint("🏠 Eve geri dönüldü, yerel Wi-Fi moduna (1ms) geçiliyor.");
        isWanMode = false;
      }
    } catch (_) {}
  }

  // --- ZERO-TRUST AUTHENTICATION APIS ---

  /// E-posta & Master Şifre ile Zero-Trust Giriş
  Future<Map<String, dynamic>> loginWithCredentials(String email, String password) async {
    if (isDemoMode) {
      isAuthenticated = true;
      authToken = 'demo_token';
      return {'success': true, 'token': authToken};
    }
    try {
      final url = _url('/api/auth/login?email=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}&device_id=$deviceId&device_name=${Uri.encodeComponent(deviceName)}');
      final res = await http.get(Uri.parse(url), headers: authHeaders).timeout(const Duration(seconds: 5));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        authToken = data['token'] ?? '';
        isAuthenticated = true;
        masterEmail = email;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pc_auth_token', authToken);
        await prefs.setString('pc_master_email', masterEmail);
        _connectionStreamController.add(true);
        return {'success': true, 'token': authToken};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Hatalı e-posta veya şifre'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Sunucuya bağlanılamadı: $e'};
    }
  }

  /// PC Ekranındaki QR / 6 Haneli OTP PIN ile Eşleşme
  Future<Map<String, dynamic>> pairWithOtp(String otp) async {
    if (isDemoMode) {
      isAuthenticated = true;
      authToken = 'demo_token';
      return {'success': true, 'token': authToken};
    }
    try {
      final cleanOtp = otp.replaceAll(' ', '');
      final url = _url('/api/auth/pair_qr?otp=${Uri.encodeComponent(cleanOtp)}&device_id=$deviceId&device_name=${Uri.encodeComponent(deviceName)}');
      final res = await http.get(Uri.parse(url), headers: authHeaders).timeout(const Duration(seconds: 5));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        authToken = data['token'] ?? '';
        isAuthenticated = true;
        pin = otp;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pc_auth_token', authToken);
        await prefs.setString('pc_pin', pin);
        _connectionStreamController.add(true);
        return {'success': true, 'token': authToken};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Geçersiz veya süresi dolmuş eşleşme PIN kodu'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Sunucuya bağlanılamadı: $e'};
    }
  }

  /// Oturumu kapatıp cihaz yetkisini sıfırlama
  Future<void> logout() async {
    authToken = '';
    isAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pc_auth_token');
    _connectionStreamController.add(false);
  }

  // --- Input APIs ---

  void sendMouseMove(double dx, double dy) {
    if (isDemoMode) return;
    http.get(
      Uri.parse(_url('/api/mouse/move?dx=${dx.round()}&dy=${dy.round()}')),
      headers: authHeaders,
    );
  }

  void sendMouseAbs(int x, int y, {String? click, int monitor = 0}) {
    if (isDemoMode) return;
    final clickParam = click != null ? '&click=$click' : '';
    http.get(
      Uri.parse(_url('/api/mouse/abs?x=$x&y=$y&monitor=$monitor$clickParam')),
      headers: authHeaders,
    );
  }

  void sendMouseDown(int x, int y, {String btn = 'left', int monitor = 0}) {
    if (isDemoMode) return;
    http.get(
      Uri.parse(_url('/api/mouse/down?x=$x&y=$y&btn=$btn&monitor=$monitor')),
      headers: authHeaders,
    );
  }

  void sendMouseUp(int x, int y, {String btn = 'left', int monitor = 0}) {
    if (isDemoMode) return;
    http.get(
      Uri.parse(_url('/api/mouse/up?x=$x&y=$y&btn=$btn&monitor=$monitor')),
      headers: authHeaders,
    );
  }

  void sendMouseClick(String btn) {
    if (isDemoMode) return;
    http.get(
      Uri.parse(_url('/api/mouse/click?btn=$btn')),
      headers: authHeaders,
    );
  }

  void sendMouseScroll(double dy) {
    if (isDemoMode) return;
    http.get(
      Uri.parse(_url('/api/mouse/scroll?dy=${dy.round()}')),
      headers: authHeaders,
    );
  }

  void sendText(String text) {
    if (isDemoMode) return;
    final encoded = Uri.encodeComponent(text);
    http.get(
      Uri.parse(_url('/api/keyboard/type?text=$encoded')),
      headers: authHeaders,
    );
  }

  void sendShortcut(String combo) {
    if (isDemoMode) return;
    http.get(
      Uri.parse(_url('/api/keyboard/shortcut?combo=$combo')),
      headers: authHeaders,
    );
  }

  Future<Uint8List?> fetchScreenFrame({int monitor = 0, double scale = 0.65, int quality = 75}) async {
    if (isDemoMode) return null;
    try {
      final res = await http
          .get(Uri.parse(_url('/api/screen/frame?monitor=$monitor&scale=$scale&q=$quality')), headers: authHeaders)
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
    http.get(
      Uri.parse(_url('/api/streamdeck/launch?app=$encoded')),
      headers: authHeaders,
    );
  }

  void sendStreamDeckCmd(String cmd) {
    if (isDemoMode) return;
    final encoded = Uri.encodeComponent(cmd);
    http.get(
      Uri.parse(_url('/api/streamdeck/command?cmd=$encoded')),
      headers: authHeaders,
    );
  }

  void moveAppToMonitor(String app, {int monitor = 2}) {
    if (isDemoMode) return;
    final encoded = Uri.encodeComponent(app);
    http.get(
      Uri.parse(_url('/api/monitors/move_app?app=$encoded&monitor=$monitor')),
      headers: authHeaders,
    );
  }

  Future<bool> enableVirtualMonitor() async {
    if (isDemoMode) return true;
    try {
      final res = await http
          .get(Uri.parse(_url('/api/monitors/virtual/enable')), headers: authHeaders)
          .timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await checkConnection();
        return data['virtual_active'] == true;
      }
    } catch (_) {}
    await checkConnection();
    return (lastStatus?.monitors.length ?? 0) >= 3;
  }

  Future<bool> disableVirtualMonitor() async {
    if (isDemoMode) return false;
    try {
      final res = await http
          .get(Uri.parse(_url('/api/monitors/virtual/disable')), headers: authHeaders)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        await checkConnection();
        return false;
      }
    } catch (_) {}
    await checkConnection();
    return (lastStatus?.monitors.length ?? 0) >= 3;
  }

  // --- Media & Power APIs ---

  void sendMediaAction(String act) {
    if (isDemoMode) return;
    http.get(
      Uri.parse(_url('/api/media/action?act=$act')),
      headers: authHeaders,
    );
  }

  void sendPowerAction(String act) {
    if (isDemoMode) return;
    http.get(
      Uri.parse(_url('/api/power/action?act=$act')),
      headers: authHeaders,
    );
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
