import 'dart:typed_data';

class UdpDiscoverySocket {
  Future<void> start(void Function(Uint8List data, String senderIp) onPacket) async {}
  void sendScanPacket() {}
  void close() {}
}

Future<void> sendUdpWakeOnLan(List<int> magicPacketBytes) async {}
