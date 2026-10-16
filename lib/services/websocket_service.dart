import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _controlChannel;
  bool isConnected = false;
  String currentHost = "";
  String currentPin = "";
  String currentToken = "";

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStateController.stream;

  Future<void> connect(String hostUrl, String pin) async {
    currentHost = hostUrl.replaceAll("http://", "").replaceAll("https://", "").split("?")[0];
    currentPin = pin;

    final isSsl = hostUrl.startsWith("https://");
    final proto = isSsl ? "wss" : "ws";
    final uri = Uri.parse("$proto://$currentHost/ws/control?pin=$pin");

    try {
      _controlChannel = WebSocketChannel.connect(uri);
      isConnected = true;
      _connectionStateController.add(true);

      _controlChannel!.stream.listen((message) {
        try {
          final data = jsonDecode(message);
          _messageController.add(data);
        } catch (e) {}
      }, onDone: () {
        isConnected = false;
        _connectionStateController.add(false);
      }, onError: (e) {
        isConnected = false;
        _connectionStateController.add(false);
      });
    } catch (e) {
      isConnected = false;
      _connectionStateController.add(false);
    }
  }

  void send(Map<String, dynamic> data) {
    if (_controlChannel != null && isConnected) {
      _controlChannel!.sink.add(jsonEncode(data));
    }
  }

  void disconnect() {
    _controlChannel?.sink.close();
    isConnected = false;
    _connectionStateController.add(false);
  }
}
