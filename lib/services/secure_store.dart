import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/e2e_crypto.dart';
import '../models/group.dart';
import '../models/message.dart';

class SecureStore {
  SecureStore._(this._prefs, this._secure);

  static const _pinSaltKey = 'pin_salt';
  static const _pinVerifierKey = 'pin_verifier';
  static const _identityPubKey = 'identity_pub';
  static const _identityPrivKey = 'identity_priv';
  static const _dataBlobKey = 'local_data_blob';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  SecretKey? _pinKey;

  static Future<SecureStore> create({String? pin}) async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      wOptions: WindowsOptions(useBackwardCompatibility: false),
    );
    final store = SecureStore._(prefs, secure);
    if (pin != null) await store.unlockWithPin(pin);
    return store;
  }

  bool get isUnlocked => _pinKey != null;
  bool get hasPin => _prefs.containsKey(_pinSaltKey);

  Future<void> setupPin(String pin) async {
    final salt = randomBytes(saltLength);
    final key = await derivePinKey(pin, salt);
    final verifier = await encryptLocal(key, utf8.encode('ttalk-pin-verifier'));
    await _prefs.setString(_pinSaltKey, base64Encode(salt));
    await _prefs.setString(_pinVerifierKey, base64Encode(verifier));
    _pinKey = key;
  }

  Future<bool> unlockWithPin(String pin) async {
    final saltB64 = _prefs.getString(_pinSaltKey);
    final verifierB64 = _prefs.getString(_pinVerifierKey);
    if (saltB64 == null || verifierB64 == null) return false;
    final key = await derivePinKey(pin, base64Decode(saltB64));
    try {
      final clear = await decryptLocal(key, base64Decode(verifierB64));
      if (utf8.decode(clear) != 'ttalk-pin-verifier') return false;
      _pinKey = key;
      return true;
    } catch (_) {
      return false;
    }
  }

  void lock() {
    _pinKey = null;
  }

  Future<void> saveIdentity(IdentityKeys keys) async {
    final privBytes = await keys.privateKey.extractPrivateKeyBytes();
    await _secure.write(key: _identityPubKey, value: base64Encode(keys.publicKey));
    await _secure.write(key: _identityPrivKey, value: base64Encode(privBytes));
  }

  Future<IdentityKeys?> loadIdentity() async {
    final pub = await _secure.read(key: _identityPubKey);
    final priv = await _secure.read(key: _identityPrivKey);
    if (pub == null || priv == null) return null;
    final kp = await X25519().newKeyPairFromSeed(base64Decode(priv));
    return IdentityKeys(
      privateKey: kp,
      publicKey: Uint8List.fromList(base64Decode(pub)),
    );
  }

  Future<IdentityKeys> loadOrCreateIdentity() async {
    return (await loadIdentity()) ?? await IdentityKeys.generate();
  }

  Future<void> saveData({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    List<Group> groups = const [],
    Map<String, SecretKey> groupKeys = const {},
  }) async {
    final key = _pinKey;
    if (key == null) throw StateError('Coffre verrouillé');
    final groupKeyMap = <String, String>{};
    for (final e in groupKeys.entries) {
      groupKeyMap[e.key] = base64Encode(await e.value.extractBytes());
    }
    final payload = utf8.encode(jsonEncode({
      'conversations': conversations.map((c) => c.toJson()).toList(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'groups': groups.map((g) => g.toJson()).toList(),
      'groupKeys': groupKeyMap,
    }));
    final blob = await encryptLocal(key, Uint8List.fromList(payload));
    await _prefs.setString(_dataBlobKey, base64Encode(blob));
  }

  Future<({List<Conversation> conversations, List<ChatMessage> messages, List<Group> groups, Map<String, List<int>> groupKeys})> loadData() async {
    final key = _pinKey;
    final blobB64 = _prefs.getString(_dataBlobKey);
    if (key == null || blobB64 == null) {
      return (
        conversations: <Conversation>[],
        messages: <ChatMessage>[],
        groups: <Group>[],
        groupKeys: <String, List<int>>{},
      );
    }
    final clear = await decryptLocal(key, base64Decode(blobB64));
    final json = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    final rawGroupKeys = (json['groupKeys'] as Map<String, dynamic>?) ?? {};
    return (
      conversations: (json['conversations'] as List)
          .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
          .toList(),
      messages: (json['messages'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      groups: ((json['groups'] as List?) ?? [])
          .map((g) => Group.fromJson(g as Map<String, dynamic>))
          .toList(),
      groupKeys: rawGroupKeys.map((k, v) => MapEntry(k, base64Decode(v as String))),
    );
  }
}
