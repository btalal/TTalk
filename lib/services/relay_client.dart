import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

enum RelayState { disconnected, connecting, connected }

class RelayClient {
  RelayClient({this.onInbound, this.onStateChange});

  static const pairingCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  RelayState _state = RelayState.disconnected;
  String? _myId;
  String? _myPairingCode;

  final void Function(Map<String, dynamic> message)? onInbound;
  final void Function(RelayState state)? onStateChange;

  RelayState get state => _state;
  String? get myId => _myId;
  String? get myPairingCode => _myPairingCode;

  void _setState(RelayState s) {
    _state = s;
    onStateChange?.call(s);
  }

  Future<void> connect(String url) async {
    _setState(RelayState.connecting);
    _channel = WebSocketChannel.connect(Uri.parse(url));
    await _channel!.ready;
    _setState(RelayState.connected);
    _sub = _channel!.stream.listen(
      (data) {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        onInbound?.call(msg);
      },
      onDone: () => _setState(RelayState.disconnected),
      onError: (_) => _setState(RelayState.disconnected),
    );
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setState(RelayState.disconnected);
  }

  void _send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  void register({required String name, required Uint8List publicKey}) {
    _send({
      'type': 'register',
      'name': name,
      'publicKey': base64Encode(publicKey),
    });
  }

  void startPairing() {
    final rng = Random.secure();
    final code = String.fromCharCodes(List.generate(
      6,
      (_) => pairingCodeAlphabet.codeUnitAt(rng.nextInt(pairingCodeAlphabet.length)),
    ));
    _myPairingCode = code;
    _send({'type': 'pair_request', 'code': code});
  }

  void answerPairing(String code) {
    _send({'type': 'pair_answer', 'code': code});
  }

  void sendCipher(String to, Uint8List payload, String messageId) {
    _send({
      'type': 'cipher',
      'to': to,
      'messageId': messageId,
      'payload': base64Encode(payload),
    });
  }

  void sendRead(String to, String messageId) {
    _send({
      'type': 'read',
      'to': to,
      'messageId': messageId,
    });
  }
}
