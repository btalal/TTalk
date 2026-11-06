import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/e2e_crypto.dart';
import 'biometric_unlock.dart';
import 'backup_codec.dart';
import 'relay_client.dart';
import '../models/group.dart';
import '../models/outbound_packet.dart';
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
  Future<void> _saveQueue = Future.value();

  static Future<SecureStore> create({
    String? pin,
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
      wOptions: WindowsOptions(useBackwardCompatibility: false),
    );
    final store = SecureStore._(prefs, secure);
    await store._completeRestore();
    if (pin != null) await store.unlockWithPin(pin);
    return store;
  }

  String get relayUrl =>
      _prefs.getString('relay_url') ??
      const String.fromEnvironment('RELAY_URL');
  Future<void> setRelayUrl(String url) async {
    await _writePreference('relay_url', url);
  }

  String get displayName => _prefs.getString('display_name') ?? 'Utilisateur';

  Future<void> setDisplayName(String name) async {
    await _writePreference('display_name', name);
  }

  bool get isUnlocked => _pinKey != null;
  bool get hasPin => _prefs.containsKey(_pinSaltKey);

  Future<void> setupPin(String pin) async {
    final salt = randomBytes(saltLength);
    final key = await derivePinKey(pin, salt);
    final verifier = await encryptLocal(key, utf8.encode('ttalk-pin-verifier'));
    await _writePreference(_pinSaltKey, base64Encode(salt));
    await _writePreference(_pinVerifierKey, base64Encode(verifier));
    _pinKey = key;
  }

  Future<bool> unlockWithPin(String pin) async {
    _pinKey = null;
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
    final private = await keys.privateKey.extractPrivateKeyBytes();
    // Keep the identity in a single atomic secure-storage item.
    await _secure.write(
      key: 'identity_bundle_v2',
      value: jsonEncode({
        'publicKey': base64Encode(keys.publicKey),
        'privateKey': base64Encode(private),
      }),
    );
  }

  Future<IdentityKeys?> loadIdentity() async {
    final bundle = await _secure.read(key: 'identity_bundle_v2');
    String? pub, priv;
    if (bundle != null) {
      final json = jsonDecode(bundle) as Map<String, dynamic>;
      pub = json['publicKey'] as String;
      priv = json['privateKey'] as String;
    } else {
      pub = await _secure.read(key: _identityPubKey);
      priv = await _secure.read(key: _identityPrivKey);
    }
    if (pub == null && priv == null) return null;
    if (pub == null || priv == null) {
      throw StateError(
        'Identité locale incomplète : ne pas réinitialiser le coffre.',
      );
    }
    final pair = await X25519().newKeyPairFromSeed(base64Decode(priv));
    final actual = await pair.extractPublicKey();
    if (base64Encode(actual.bytes) != pub) {
      throw StateError(
        'Identité locale incohérente : ne pas réinitialiser le coffre.',
      );
    }
    return IdentityKeys(
      privateKey: pair,
      publicKey: Uint8List.fromList(actual.bytes),
    );
  }

  Future<IdentityKeys> loadOrCreateIdentity() async {
    return (await loadIdentity()) ?? await IdentityKeys.generate();
  }

  Future<void> _writePreference(String key, String value) async {
    if (!await _prefs.setString(key, value)) {
      throw StateError('Impossible d’enregistrer les données locales.');
    }
  }

  Future<void> saveData({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    List<Group> groups = const [],
    Map<String, SecretKey> groupKeys = const {},
    List<OutboundPacket> outbox = const [],
    List<GroupInvite> pendingInvites = const [],
  }) {
    final savedConversations = conversations
        .map((c) => Conversation.fromJson(c.toJson()))
        .toList();
    final savedMessages = messages
        .map((m) => ChatMessage.fromJson(m.toJson()))
        .toList();
    final savedGroups = groups.map((g) => Group.fromJson(g.toJson())).toList();
    final savedOutbox = outbox
        .map((o) => OutboundPacket.fromJson(o.toJson()))
        .toList();
    final savedInvites = pendingInvites
        .map(
          (i) => GroupInvite.fromJsonString(
            i.toJsonString(),
            fromId: i.fromId,
            fromName: i.fromName,
          ),
        )
        .toList();
    final savedGroupKeys = Map<String, SecretKey>.of(groupKeys);
    final pending = _saveQueue.then(
      (_) => _writeData(
        conversations: savedConversations,
        messages: savedMessages,
        groups: savedGroups,
        groupKeys: savedGroupKeys,
        outbox: savedOutbox,
        pendingInvites: savedInvites,
      ),
    );
    _saveQueue = pending.catchError((Object _) {});
    return pending;
  }

  Future<void> _writeData({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    List<Group> groups = const [],
    Map<String, SecretKey> groupKeys = const {},
    List<OutboundPacket> outbox = const [],
    List<GroupInvite> pendingInvites = const [],
  }) async {
    final key = _pinKey;
    if (key == null) throw StateError('Coffre verrouillé');
    final groupKeyMap = <String, String>{};
    for (final e in groupKeys.entries) {
      groupKeyMap[e.key] = base64Encode(await e.value.extractBytes());
    }
    final payload = utf8.encode(
      jsonEncode({
        'conversations': conversations.map((c) => c.toJson()).toList(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'groups': groups.map((g) => g.toJson()).toList(),
        'groupKeys': groupKeyMap,
        'outbox': outbox.map((p) => p.toJson()).toList(),
        'pendingInvites': pendingInvites
            .map((i) => jsonDecode(i.toJsonString()))
            .toList(),
      }),
    );
    final blob = await encryptLocal(key, Uint8List.fromList(payload));
    await _writePreference(_dataBlobKey, base64Encode(blob));
  }

  Future<
    ({
      List<Conversation> conversations,
      List<ChatMessage> messages,
      List<Group> groups,
      Map<String, List<int>> groupKeys,
      List<OutboundPacket> outbox,
      List<GroupInvite> pendingInvites,
    })
  >
  loadData() async {
    final key = _pinKey;
    final blobB64 = _prefs.getString(_dataBlobKey);
    if (key == null || blobB64 == null) {
      return (
        conversations: <Conversation>[],
        messages: <ChatMessage>[],
        groups: <Group>[],
        groupKeys: <String, List<int>>{},
        outbox: <OutboundPacket>[],
        pendingInvites: <GroupInvite>[],
      );
    }
    final clear = await decryptLocal(key, base64Decode(blobB64));
    final json = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    return _decodeData(json);
  }

  static ({
    List<Conversation> conversations,
    List<ChatMessage> messages,
    List<Group> groups,
    Map<String, List<int>> groupKeys,
    List<OutboundPacket> outbox,
    List<GroupInvite> pendingInvites,
  })
  _decodeData(Map<String, dynamic> json) {
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
      groupKeys: rawGroupKeys.map(
        (k, v) => MapEntry(k, base64Decode(v as String)),
      ),
      outbox: ((json['outbox'] as List?) ?? [])
          .map((p) => OutboundPacket.fromJson(p as Map<String, dynamic>))
          .toList(),
      pendingInvites: ((json['pendingInvites'] as List?) ?? [])
          .map(
            (i) => GroupInvite.fromJsonString(
              jsonEncode(i),
              fromId: i['fromId'] as String,
              fromName: i['fromName'] as String,
            ),
          )
          .toList(),
    );
  }

  int get autoLockSeconds => _prefs.getInt('auto_lock_seconds') ?? 300;
  Future<void> setAutoLockSeconds(int seconds) async {
    if (![30, 60, 300, 900].contains(seconds)) {
      throw ArgumentError('Délai invalide.');
    }
    if (!await _prefs.setInt('auto_lock_seconds', seconds)) {
      throw StateError('Réglage non enregistré.');
    }
  }

  bool get biometricsEnabled => _prefs.getBool('biometric_unlock') ?? false;
  Future<bool> biometricAvailable() => BiometricUnlock().available();
  Future<void> enableBiometrics() async {
    final key = _pinKey;
    if (key == null) throw StateError('Coffre verrouillé.');
    if (!await biometricAvailable()) {
      throw StateError('Aucune biométrie configurée.');
    }
    await BiometricUnlock().enable(base64Encode(await key.extractBytes()));
    if (!await _prefs.setBool('biometric_unlock', true)) {
      throw StateError('Réglage non enregistré.');
    }
  }

  Future<void> disableBiometrics() async {
    await BiometricUnlock().disable();
    if (!await _prefs.setBool('biometric_unlock', false)) {
      throw StateError('Réglage non enregistré.');
    }
  }

  Future<bool> unlockWithBiometrics() async {
    if (!biometricsEnabled) return false;
    final saved = await BiometricUnlock().read();
    if (saved == null) return false;
    final bytes = base64Decode(saved);
    if (bytes.length != 32) return false;
    final key = SecretKey(bytes);
    final verifier = _prefs.getString(_pinVerifierKey);
    if (verifier == null) return false;
    try {
      if (utf8.decode(await decryptLocal(key, base64Decode(verifier))) !=
          'ttalk-pin-verifier') {
        return false;
      }
      _pinKey = key;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> createBackup(String password) async {
    final key = _pinKey;
    if (key == null) throw StateError('Coffre verrouillé.');
    await _saveQueue;
    final encoded = _prefs.getString(_dataBlobKey);
    final data = encoded == null
        ? <String, dynamic>{
            'conversations': [],
            'messages': [],
            'groups': [],
            'groupKeys': {},
          }
        : jsonDecode(
            utf8.decode(await decryptLocal(key, base64Decode(encoded))),
          ) as Map<String, dynamic>;
    // Pending sends are not replayed on a recovered device. Attachments are not
    // copied: untrusted filesystem paths must never survive an import.
    data['outbox'] = [];
    for (final m in data['messages'] as List) {
      (m as Map).remove('filePath');
    }
    final identity = await loadIdentity();
    if (identity == null) throw StateError('Identité introuvable.');
    return BackupCodec.encode({
      'version': 1,
      'data': data,
      'identity': {
        'publicKey': base64Encode(identity.publicKey),
        'privateKey': base64Encode(
          await identity.privateKey.extractPrivateKeyBytes(),
        ),
      },
      'relay': relayUrl,
      'displayName': displayName,
    }, password);
  }

  Future<void> restoreBackup(Uint8List bytes, String password) async {
    final key = _pinKey;
    if (key == null) throw StateError('Coffre verrouillé.');
    await _saveQueue;
    final current = await loadData();
    if (current.conversations.isNotEmpty ||
        current.groups.isNotEmpty ||
        current.messages.isNotEmpty) {
      throw StateError(
        'Restauration autorisée uniquement dans un coffre vide.',
      );
    }
    final backup = await BackupCodec.decode(bytes, password);
    final data = backup['data'] as Map<String, dynamic>;
    data['outbox'] = [];
    for (final raw in data['messages'] as List) {
      (raw as Map).remove('filePath');
    }
    final parsed = _decodeData(data);
    if (parsed.messages.length > 50000 ||
        parsed.conversations.length > 10000 ||
        parsed.groupKeys.values.any((k) => k.length != 32)) {
      throw const FormatException('Sauvegarde hors limites.');
    }
    final identity = backup['identity'] as Map<String, dynamic>;
    final priv = base64Decode(identity['privateKey'] as String);
    final pub = base64Decode(identity['publicKey'] as String);
    if (priv.length != 32 || pub.length != 32) {
      throw const FormatException('Identité invalide.');
    }
    final actual = await (await X25519().newKeyPairFromSeed(priv))
        .extractPublicKey();
    if (base64Encode(actual.bytes) != base64Encode(pub)) {
      throw const FormatException('Identité incohérente.');
    }
    final relay = backup['relay'] as String;
    final name = backup['displayName'] as String;
    if (name.length > 40 || relay.length > 2048) {
      throw const FormatException('Profil invalide.');
    }
    if (relay.isNotEmpty) RelayClient.normalizeUrl(relay);
    final blob = await encryptLocal(
      key,
      Uint8List.fromList(utf8.encode(jsonEncode(data))),
    );
    // A recovery journal allows interrupted cross-store writes to complete on
    // next startup. The existing PIN still encrypts the recovered vault.
    await _secure.write(
      key: 'restore_pending_v1',
      value: jsonEncode({
        'identity': identity,
        'blob': base64Encode(blob),
        'relay': relay,
        'name': name,
      }),
    );
    await _completeRestore();
  }

  Future<void> _completeRestore() async {
    final pending = await _secure.read(key: 'restore_pending_v1');
    if (pending == null) return;
    final recovery = jsonDecode(pending) as Map<String, dynamic>;
    await _writePreference(_dataBlobKey, recovery['blob'] as String);
    await _secure.write(
      key: 'identity_bundle_v2',
      value: jsonEncode(recovery['identity']),
    );
    await setRelayUrl(recovery['relay'] as String);
    await setDisplayName(recovery['name'] as String);
    await _secure.delete(key: 'restore_pending_v1');
  }
}
