import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class UdpDiscoverySocket {
  RawDatagramSocket? _socket;

  Future<void> start(void Function(Uint8List data, String senderIp) onPacket) async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            onPacket(datagram.data, datagram.address.address);
          }
        }
      });
    } catch (e) {
      debugPrint("UDP bind error: $e");
    }
  }

  void sendScanPacket() {
    if (_socket == null) return;
    final msg = jsonEncode({
      "magic": "PC_REMOTE_DISCOVERY",
      "type": "SCAN",
    });
    try {
      _socket!.send(utf8.encode(msg), InternetAddress("255.255.255.255"), 8888);
    } catch (_) {}
  }

  void close() {
    _socket?.close();
    _socket = null;
  }
}

Future<void> sendUdpWakeOnLan(List<int> magicPacketBytes) async {
  try {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    socket.send(magicPacketBytes, InternetAddress('255.255.255.255'), 9);
    socket.send(magicPacketBytes, InternetAddress('255.255.255.255'), 7);
    socket.close();
  } catch (e) {
    debugPrint("WoL Error: $e");
  }
}
