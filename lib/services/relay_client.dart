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
  Future<void>? _connecting;
  String? _url;
  String? displayName;
  String? _myPairingCode;

  FutureOr<void> Function(Map<String, dynamic> message)? onInbound;
  void Function(RelayState state)? onStateChange;
  void Function(Object error)? onMessageError;

  RelayState get state => _state;
  String? get myId => _myId;
  String? get myPairingCode => _myPairingCode;

  void _setState(RelayState s) {
    _state = s;
    onStateChange?.call(s);
  }

  Future<void> connect(String url) {
    if (_state == RelayState.connected && _url == url) return Future.value();
    return _connecting ??= _connect(url).whenComplete(() => _connecting = null);
  }

  Future<void> _connect(String url) async {
    disconnect();
    _url = url;
    _setState(RelayState.connecting);
    late final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 10));
    } catch (_) {
      disconnect();
      rethrow;
    }
    _setState(RelayState.connected);
    _sub = channel.stream.asyncMap((data) async {
      try {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        if (msg['type'] == 'registered') _myId = msg['id'] as String;
        await onInbound?.call(msg);
      } catch (error) {
        onMessageError?.call(error);
      }
    }).listen(
      (_) {},
      onDone: () {
        _myId = null;
        _myPairingCode = null;
        _setState(RelayState.disconnected);
      },
      onError: (Object error) {
        disconnect();
      },
    );
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _myId = null;
    _myPairingCode = null;
    _setState(RelayState.disconnected);
  }

  void _send(Map<String, dynamic> msg) {
    if (_channel == null || _state != RelayState.connected) {
      throw StateError('Relais déconnecté');
    }
    _channel!.sink.add(jsonEncode(msg));
  }

  void register({required String name, required Uint8List publicKey}) {
    displayName = name;
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
      (_) => pairingCodeAlphabet
          .codeUnitAt(rng.nextInt(pairingCodeAlphabet.length)),
    ));
    _myPairingCode = code;
    _send({'type': 'pair_request', 'code': code});
  }

  void answerPairing(String code) {
    _send({'type': 'pair_answer', 'code': code});
  }

  void sendCipher(String to, Uint8List payload, String messageId,
      {String? groupId}) {
    _send({
      'type': 'cipher',
      'to': to,
      'messageId': messageId,
      if (groupId != null) 'groupId': groupId,
      'payload': base64Encode(payload),
    });
  }

  void sendCipherToMany(List<String> tos, Uint8List payload, String messageId,
      {required String groupId}) {
    _send({
      'type': 'cipher',
      'to': tos,
      'messageId': messageId,
      'groupId': groupId,
      'payload': base64Encode(payload),
    });
  }

  void sendDelivered(String to, String messageId, {String? groupId}) {
    _send({
      'type': 'delivered',
      'to': to,
      'messageId': messageId,
      if (groupId != null) 'groupId': groupId,
    });
  }

  void sendRead(String to, String messageId, {String? groupId}) {
    _send({
      'type': 'read',
      if (groupId != null) 'groupId': groupId,
      'to': to,
      'messageId': messageId,
    });
  }

  void sendGroupInvite(String to, Uint8List payload) {
    _send({
      'type': 'group_invite',
      'to': to,
      'payload': base64Encode(payload),
    });
  }
}
