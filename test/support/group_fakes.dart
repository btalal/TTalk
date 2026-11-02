import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:ttalk/crypto/e2e_crypto.dart';
import 'package:ttalk/models/group.dart';
import 'package:ttalk/models/message.dart';
import 'package:ttalk/services/relay_client.dart';
import 'package:ttalk/services/secure_store.dart';

class MemoryStore implements SecureStore {
  List<Group> savedGroups = [];
  List<ChatMessage> savedMessages = [];

  @override
  Future<IdentityKeys> loadOrCreateIdentity() => IdentityKeys.generate();
  @override
  Future<void> saveIdentity(IdentityKeys keys) async {}
  @override
  bool get hasPin => false;
  @override
  Future<void> saveData({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    List<Group> groups = const [],
    Map<String, SecretKey> groupKeys = const {},
  }) async {
    savedGroups = groups.map((g) => Group.fromJson(g.toJson())).toList();
    savedMessages =
        messages.map((m) => ChatMessage.fromJson(m.toJson())).toList();
  }

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
  String get myId => id;
  @override
  void sendCipher(String to, Uint8List payload, String messageId,
      {String? groupId}) {
    sendCipherToMany([to], payload, messageId, groupId: groupId!);
  }

  @override
  void sendCipherToMany(List<String> tos, Uint8List payload, String messageId,
      {required String groupId}) {
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
