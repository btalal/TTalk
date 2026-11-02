import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../crypto/e2e_crypto.dart';
import '../models/outbound_packet.dart';

enum RelayState { disconnected, connecting, connected }

class RelayClient {
  RelayClient({this.onInbound, this.onStateChange});
  static const pairingCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  RelayState _state = RelayState.disconnected;
  String? _myId;
  String? _url;
  String? _myPairingCode;
  String? displayName;
  IdentityKeys? _identity;
  Map<String, dynamic>? _challenge;
  bool _registrationRequested = false;
  bool _desired = false;
  int _generation = 0;
  int _attempt = 0;
  Timer? _retry;
  Timer? _authenticationDeadline;
  Future<void>? _connecting;

  FutureOr<void> Function(Map<String, dynamic> message)? onInbound;
  void Function(RelayState state)? onStateChange;
  void Function(Object error)? onMessageError;
  RelayState get state => _state;
  String? get myId => _myId;
  String? get myPairingCode => _myPairingCode;
  void configureIdentity(IdentityKeys identity) {
    _identity = identity;
  }

  static String normalizeUrl(String input) {
    var uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery) {
      throw const FormatException('Adresse de relais invalide');
    }
    if (uri.scheme == 'https') uri = uri.replace(scheme: 'wss');
    if (uri.scheme == 'http') uri = uri.replace(scheme: 'ws');
    final local = ['localhost', '127.0.0.1', '::1'].contains(uri.host);
    if (uri.scheme != 'wss' && !(uri.scheme == 'ws' && local)) {
      throw const FormatException('Le relais distant doit utiliser HTTPS/WSS');
    }
    if (uri.path.isEmpty || uri.path == '/') uri = uri.replace(path: '/ws');
    return uri.toString();
  }

  void _setState(RelayState state) {
    _state = state;
    onStateChange?.call(state);
  }

  Future<void> connect(String input) {
    final url = normalizeUrl(input);
    if (_desired && _url == url && _state == RelayState.connected) {
      return Future.value();
    }
    if (_connecting != null && _url == url) return _connecting!;
    disconnect();
    _desired = true;
    _url = url;
    return _startConnection();
  }

  Future<void> _startConnection() {
    final operation = _connect();
    _connecting = operation;
    operation.then(
      (_) {
        if (identical(_connecting, operation)) _connecting = null;
      },
      onError: (Object _) {
        if (identical(_connecting, operation)) _connecting = null;
      },
    );
    return operation;
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    _challenge = null;
    _myId = null;
    _setState(RelayState.connecting);
    try {
      final channel = WebSocketChannel.connect(Uri.parse(_url!));
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 10));
      if (!_desired || generation != _generation) {
        await channel.sink.close();
        return;
      }
      _setState(RelayState.connected);
      _authenticationDeadline?.cancel();
      _authenticationDeadline = Timer(const Duration(seconds: 12), () {
        if (generation == _generation && _myId == null) {
          onMessageError?.call(
            const FormatException(
              'Ce serveur doit être mis à jour pour TTalk 0.4.',
            ),
          );
          _lost(generation);
        }
      });
      _sub = channel.stream
          .asyncMap((raw) async {
            if (generation != _generation) return;
            Map<String, dynamic>? message;
            try {
              message = jsonDecode(raw as String) as Map<String, dynamic>;
              if (['cipher', 'group_invite'].contains(message['type']) &&
                  (message['from'] is! String ||
                      message['messageId'] is! String ||
                      message['payload'] is! String ||
                      (message['groupId'] != null &&
                          message['groupId'] is! String))) {
                throw const FormatException('Trame de message invalide');
              }
              if (message['type'] == 'auth_challenge') {
                if (message['protocol'] != 2) {
                  throw const FormatException('Relais incompatible');
                }
                _challenge = message;
                if (_registrationRequested) await _authenticate();
                return;
              }
              if (message['type'] == 'peer_matched' &&
                  identityId(
                        base64Decode(message['peerPublicKey'] as String),
                      ) !=
                      message['peerId']) {
                throw const FormatException('Identité du contact incohérente');
              }
              if (message['type'] == 'registered') {
                if (_identity == null ||
                    message['id'] != _identity!.stableId ||
                    message['protocol'] != 2) {
                  throw const FormatException('Identité du relais incohérente');
                }
                _authenticationDeadline?.cancel();
                _myId = message['id'] as String;
              }
              await onInbound?.call(message);
              if (message['type'] == 'registered') _attempt = 0;
              if (message['relayId'] is String) {
                _send({'type': 'delivery_ack', 'relayId': message['relayId']});
              }
            } catch (error) {
              onMessageError?.call(error);
              // Invalid authenticated ciphertext cannot be repaired by replaying it.
              // Storage failures, in contrast, remain unacknowledged for retry.
              if (message?['relayId'] is String &&
                  (error is FormatException ||
                      error is SecretBoxAuthenticationError)) {
                _send({'type': 'delivery_ack', 'relayId': message!['relayId']});
              } else if (message?['relayId'] is String ||
                  message?['type'] == 'registered') {
                _lost(generation);
              }
            }
          })
          .listen(
            (_) {},
            onDone: () {
              if (channel.closeCode == 4001 && generation == _generation) {
                _desired = false;
                onMessageError?.call(
                  StateError(
                    'Cette identité est déjà ouverte sur un autre appareil.',
                  ),
                );
              }
              _lost(generation);
            },
            onError: (Object _) => _lost(generation),
          );
    } catch (_) {
      _lost(generation);
      rethrow;
    }
  }

  void _lost(int generation) {
    if (generation != _generation) return;
    _authenticationDeadline?.cancel();
    _myId = null;
    _challenge = null;
    _myPairingCode = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _setState(RelayState.disconnected);
    if (_desired && _retry == null) {
      final seconds = min(30, 1 << min(_attempt++, 5));
      _retry = Timer(Duration(seconds: seconds), () {
        _retry = null;
        if (_desired) unawaited(_startConnection().catchError((Object _) {}));
      });
    }
  }

  void disconnect() {
    _desired = false;
    _authenticationDeadline?.cancel();
    _generation++;
    _retry?.cancel();
    _retry = null;
    _connecting = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _myId = null;
    _myPairingCode = null;
    _challenge = null;
    _setState(RelayState.disconnected);
  }

  void _send(Map<String, dynamic> message) {
    if (_channel == null || _state != RelayState.connected) {
      throw StateError('Relais déconnecté');
    }
    _channel!.sink.add(jsonEncode(message));
  }

  void register({required String name, required Uint8List publicKey}) {
    displayName = name;
    _registrationRequested = true;
    if (_challenge != null) {
      unawaited(
        _authenticate().catchError((Object error) {
          onMessageError?.call(error);
        }),
      );
    }
  }

  Future<void> _authenticate() async {
    final identity = _identity, challenge = _challenge;
    if (identity == null || challenge == null) return;
    final generation = _generation;
    final key = await identity.deriveSessionKey(
      base64Decode(challenge['publicKey'] as String),
      context: 'ttalk-auth-v2',
    );
    final publicKey = base64Encode(identity.publicKey);
    final mac = await Hmac.sha256().calculateMac(
      utf8.encode('ttalk-register-v2\n${challenge['nonce']}\n$publicKey'),
      secretKey: key,
    );
    if (generation != _generation || _state != RelayState.connected) return;
    _send({
      'type': 'register',
      'name': displayName,
      'publicKey': publicKey,
      'proof': base64Encode(mac.bytes),
    });
  }

  void sendPacket(OutboundPacket packet, List<String> targets) {
    _send({
      'type': packet.type,
      'to': targets,
      'messageId': packet.id,
      'groupId': packet.groupId,
      'payload': base64Encode(packet.payload),
    });
  }

  void startPairing() {
    final rng = Random.secure();
    final code = String.fromCharCodes(
      List.generate(
        6,
        (_) => pairingCodeAlphabet.codeUnitAt(
          rng.nextInt(pairingCodeAlphabet.length),
        ),
      ),
    );
    _myPairingCode = code;
    _send({'type': 'pair_request', 'code': code});
  }

  void answerPairing(String code) {
    _send({'type': 'pair_answer', 'code': code});
  }

  void sendCipher(
    String to,
    Uint8List payload,
    String messageId, {
    String? groupId,
  }) {
    _send({
      'type': 'cipher',
      'to': to,
      'messageId': messageId,
      if (groupId != null) 'groupId': groupId,
      'payload': base64Encode(payload),
    });
  }

  void sendCipherToMany(
    List<String> tos,
    Uint8List payload,
    String messageId, {
    required String groupId,
  }) {
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
    _send({'type': 'group_invite', 'to': to, 'payload': base64Encode(payload)});
  }
}
