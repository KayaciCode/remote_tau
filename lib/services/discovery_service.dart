import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'udp_helper.dart';

class DiscoveredDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String os;
  DateTime lastSeen;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.os,
    required this.lastSeen,
  });

  String get baseUrl => "http://$ip:$port";
}

class MobileDiscoveryService {
  static final MobileDiscoveryService _instance =
      MobileDiscoveryService._internal();
  factory MobileDiscoveryService() => _instance;
  MobileDiscoveryService._internal();

  UdpDiscoverySocket? _socket;
  bool isScanning = false;
  final Map<String, DiscoveredDevice> _devices = {};

  final StreamController<List<DiscoveredDevice>> _deviceStreamController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  Stream<List<DiscoveredDevice>> get devicesStream =>
      _deviceStreamController.stream;

  Future<void> startDiscovery() async {
    if (isScanning) return;
    isScanning = true;
    _devices.clear();

    // 1. Start UDP Discovery Socket (Native iOS & Android)
    if (!kIsWeb) {
      _socket = UdpDiscoverySocket();
      await _socket!.start(_handlePacket);
      sendScanPacket();
    }

    // 2. Start Subnet HTTP Sweep (Guaranteed fallback for routers blocking UDP broadcast & iOS Web)
    _performSubnetSweep();

    // Periodic scanner
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!isScanning) {
        timer.cancel();
        return;
      }
      sendScanPacket();
      _performSubnetSweep();
      _cleanOldDevices();
    });
  }

  void sendScanPacket() {
    _socket?.sendScanPacket();
  }

  void _handlePacket(Uint8List data, String senderIp) {
    try {
      final text = utf8.decode(data);
      final json = jsonDecode(text);
      if (json["magic"] == "PC_REMOTE_DISCOVERY" || json["magic"] == "PC_REMOTE_PAIR") {
        final id = json["device_id"] ?? senderIp;
        final dev = DiscoveredDevice(
          id: id,
          name: json["device_name"] ?? "Windows PC",
          ip: json["ip"] ?? senderIp,
          port: json["port"] ?? 8000,
          os: json["os"] ?? "Windows 11 PRO",
          lastSeen: DateTime.now(),
        );

        _devices[id] = dev;
        _deviceStreamController.add(_devices.values.toList());
      }
    } catch (_) {}
  }

  // Fast Async Subnet HTTP Sweep
  Future<void> _performSubnetSweep() async {
    if (kIsWeb && Uri.base.host.isNotEmpty) {
      final webPort = Uri.base.hasPort ? Uri.base.port : 8000;
      await _probeIp(Uri.base.host, webPort);
      return;
    }

    final subnets = ['192.168.1', '192.168.0', '10.0.0'];
    for (final subnet in subnets) {
      final futures = <Future>[];
      for (int i = 2; i <= 60; i++) {
        final ip = '$subnet.$i';
        futures.add(_probeIp(ip, 8000));
      }
      futures.add(_probeIp('$subnet.20', 8000));
      futures.add(_probeIp('$subnet.100', 8000));
      futures.add(_probeIp('$subnet.145', 8000));
      futures.add(_probeIp('127.0.0.1', 8000));

      await Future.wait(futures);
    }
  }

  Future<void> _probeIp(String ip, int port) async {
    try {
      final uri = Uri.parse('http://$ip:$port/api/status');
      final res = await http.get(uri).timeout(const Duration(milliseconds: 600));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final id = json['desk_id'] ?? ip;
        final dev = DiscoveredDevice(
          id: id,
          name: json['device_name'] ?? 'Windows PC',
          ip: json['ip'] ?? ip,
          port: json['port'] ?? port,
          os: json['os'] ?? 'Windows',
          lastSeen: DateTime.now(),
        );
        _devices[id] = dev;
        _deviceStreamController.add(_devices.values.toList());
      }
    } catch (_) {}
  }

  void _cleanOldDevices() {
    final now = DateTime.now();
    _devices.removeWhere(
        (key, dev) => now.difference(dev.lastSeen).inSeconds > 10);
    _deviceStreamController.add(_devices.values.toList());
  }

  void stopDiscovery() {
    isScanning = false;
    _socket?.close();
    _socket = null;
  }
}
