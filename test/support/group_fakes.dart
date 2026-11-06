import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:ttalk/crypto/e2e_crypto.dart';
import 'package:ttalk/models/group.dart';
import 'package:ttalk/models/message.dart';
import 'package:ttalk/models/outbound_packet.dart';
import 'package:ttalk/services/relay_client.dart';
import 'package:ttalk/services/secure_store.dart';

class MemoryStore implements SecureStore {
  bool _unlocked = false;
  @override
  bool get isUnlocked => _unlocked;
  @override
  void lock() {
    _unlocked = false;
  }

  @override
  int get autoLockSeconds => 300;
  @override
  bool get biometricsEnabled => false;
  @override
  Future<bool> biometricAvailable() async => false;
  bool failWrites = false;
  List<Conversation> savedConversations = [];
  List<OutboundPacket> savedOutbox = [];
  List<GroupInvite> savedInvites = [];
  Map<String, List<int>> savedKeys = {};
  String _relayUrl = '';
  IdentityKeys? _identity;
  @override
  String get relayUrl => _relayUrl;
  @override
  Future<void> setRelayUrl(String value) async {
    _relayUrl = value;
  }

  @override
  String get displayName => 'Utilisateur';
  List<Group> savedGroups = [];
  List<ChatMessage> savedMessages = [];

  @override
  Future<IdentityKeys> loadOrCreateIdentity() async =>
      _identity ??= await IdentityKeys.generate();
  @override
  Future<void> saveIdentity(IdentityKeys keys) async {}
  bool _hasPin = false;
  String? _pin;
  @override
  bool get hasPin => _hasPin;
  @override
  Future<void> setupPin(String pin) async {
    _unlocked = true;
    _hasPin = true;
    _pin = pin;
  }

  @override
  Future<bool> unlockWithPin(String pin) async => _unlocked = _pin == pin;
  @override
  Future<void> saveData({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    List<Group> groups = const [],
    Map<String, SecretKey> groupKeys = const {},
    List<OutboundPacket> outbox = const [],
    List<GroupInvite> pendingInvites = const [],
  }) async {
    if (failWrites) throw StateError('Simulated storage failure');
    savedConversations = conversations
        .map((c) => Conversation.fromJson(c.toJson()))
        .toList();
    savedOutbox = outbox
        .map((p) => OutboundPacket.fromJson(p.toJson()))
        .toList();
    savedInvites = List.of(pendingInvites);
    savedKeys = {};
    for (final entry in groupKeys.entries) {
      savedKeys[entry.key] = await entry.value.extractBytes();
    }
    savedGroups = groups.map((g) => Group.fromJson(g.toJson())).toList();
    savedMessages = messages
        .map((m) => ChatMessage.fromJson(m.toJson()))
        .toList();
  }

  @override
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
  loadData() async => (
    conversations: savedConversations,
    messages: savedMessages,
    groups: savedGroups,
    groupKeys: savedKeys,
    outbox: savedOutbox,
    pendingInvites: savedInvites,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryRelay extends RelayClient {
  MemoryRelay(this.id, String name) {
    displayName = name;
  }
  final String id;
  final List<Map<String, dynamic>> outgoing = [];
  @override
  void sendPacket(OutboundPacket packet, List<String> targets) {
    outgoing.add({
      'type': packet.type,
      'from': id,
      'to': targets,
      'payload': base64Encode(packet.payload),
      'messageId': packet.id,
      'groupId': packet.groupId,
    });
  }

  @override
  String get myId => id;
  @override
  Future<void> connect(String url) async {}
  @override
  RelayState get state => RelayState.connected;
  final List<Map<String, dynamic>> receipts = [];
  @override
  void sendRead(String to, String messageId, {String? groupId}) {
    receipts.add({
      'type': 'read',
      'from': id,
      'to': to,
      'messageId': messageId,
      'groupId': groupId,
    });
  }

  @override
  void sendDelivered(String to, String messageId, {String? groupId}) {
    receipts.add({
      'type': 'delivered',
      'from': id,
      'to': to,
      'messageId': messageId,
      'groupId': groupId,
    });
  }

  @override
  void sendCipher(
    String to,
    Uint8List payload,
    String messageId, {
    String? groupId,
  }) {
    sendCipherToMany([to], payload, messageId, groupId: groupId!);
  }

  @override
  void sendCipherToMany(
    List<String> tos,
    Uint8List payload,
    String messageId, {
    required String groupId,
  }) {
    outgoing.add({
      'type': 'cipher',
      'from': id,
      'to': tos,
      'payload': base64Encode(payload),
      'messageId': messageId,
      'groupId': groupId,
    });
  }
}

Future<Uint8List> transportPacket(
  SecretKey key,
  String body,
  String from,
  String id, {
  String? groupId,
  String kind = 'text',
}) => encryptMessage(
  key,
  jsonEncode({
    'v': 2,
    'kind': kind,
    'id': id,
    'from': from,
    'groupId': groupId,
    'body': body,
    'sentAt': DateTime.now().toUtc().toIso8601String(),
  }),
);
Future<String> transportBody(
  SecretKey key,
  Map<String, dynamic> packet,
) async =>
    (jsonDecode(
          await decryptMessage(key, base64Decode(packet['payload'] as String)),
        ) as Map)['body']
        as String;
