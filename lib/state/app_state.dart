import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../crypto/e2e_crypto.dart';
import '../models/message.dart';
import '../services/relay_client.dart';
import '../services/secure_store.dart';

class AppState extends ChangeNotifier {
  AppState({required this.store, required this.relay});

  final SecureStore store;
  final RelayClient relay;
  final _uuid = const Uuid();

  IdentityKeys? identity;
  final Map<String, SecretKey> _sessionKeys = {};
  final Map<String, Uint8List> _peerKeys = {};
  List<Conversation> conversations = [];
  final Map<String, List<ChatMessage>> messagesByConv = {};
  bool unlocked = false;
  String? error;

  Future<void> init({String? pin}) async {
    identity = await store.loadOrCreateIdentity();
    await store.saveIdentity(identity!);
    if (pin != null && store.hasPin) {
      unlocked = await store.unlockWithPin(pin);
    } else if (!store.hasPin && pin != null) {
      await store.setupPin(pin);
      unlocked = true;
    }
    if (unlocked) {
      final data = await store.loadData();
      conversations = data.conversations;
      messagesByConv.clear();
      for (final m in data.messages) {
        messagesByConv.putIfAbsent(m.conversationId, () => []).add(m);
      }
      for (final c in conversations) {
        _peerKeys[c.peerId] = Uint8List.fromList(c.peerPublicKey);
        _sessionKeys[c.peerId] = await identity!.deriveSessionKey(c.peerPublicKey);
      }
    }
    relay.onInbound = _handleInbound;
    relay.onStateChange = (_) => notifyListeners();
    notifyListeners();
  }

  Future<void> unlock(String pin) async {
    unlocked = await store.unlockWithPin(pin);
    if (unlocked) {
      final data = await store.loadData();
      conversations = data.conversations;
      messagesByConv.clear();
      for (final m in data.messages) {
        messagesByConv.putIfAbsent(m.conversationId, () => []).add(m);
      }
      for (final c in conversations) {
        _peerKeys[c.peerId] = Uint8List.fromList(c.peerPublicKey);
        _sessionKeys[c.peerId] = await identity!.deriveSessionKey(c.peerPublicKey);
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final all = messagesByConv.values.expand((l) => l).toList();
    await store.saveData(conversations: conversations, messages: all);
  }

  Future<String?> pairWithCode(String code) async {
    if (relay.state != RelayState.connected) return 'Non connecté au relais';
    relay.answerPairing(code);
    return null;
  }

  Future<void> _handleInbound(Map<String, dynamic> msg) async {
    switch (msg['type']) {
      case 'registered':
        break;
      case 'pairing_code':
        break;
      case 'peer_matched':
        final peerId = msg['peerId'] as String;
        final peerName = msg['peerName'] as String;
        final peerPubBytes = Uint8List.fromList(
          base64Decode(msg['peerPublicKey'] as String),
        );
        _peerKeys[peerId] = peerPubBytes;
        _sessionKeys[peerId] = await identity!.deriveSessionKey(peerPubBytes);
        final existing = conversations.where((c) => c.peerId == peerId);
        if (existing.isEmpty) {
          conversations.add(Conversation(
            id: _uuid.v4(),
            peerId: peerId,
            peerName: peerName,
            peerPublicKey: peerPubBytes,
            createdAt: DateTime.now(),
          ));
        } else {
          final c = existing.first;
          conversations[conversations.indexOf(c)] = Conversation(
            id: c.id,
            peerId: c.peerId,
            peerName: peerName,
            peerPublicKey: peerPubBytes,
            createdAt: c.createdAt,
            lastMessageAt: c.lastMessageAt,
          );
        }
        await _persist();
        notifyListeners();
        break;
      case 'cipher':
        final from = msg['from'] as String;
        final payload = Uint8List.fromList(base64Decode(msg['payload'] as String));
        final conv = conversations.where((c) => c.peerId == from).toList();
        if (conv.isEmpty) break;
        final key = _sessionKeys[from];
        if (key == null) break;
        final plain = await decryptMessage(key, payload);
        final m = ChatMessage(
          id: msg['messageId'] as String,
          conversationId: conv.first.id,
          fromMe: false,
          ciphertext: payload,
          timestamp: DateTime.now(),
          plaintext: plain,
        );
        messagesByConv.putIfAbsent(conv.first.id, () => []).add(m);
        relay.sendRead(from, m.id);
        final idx = conversations.indexOf(conv.first);
        conversations[idx] = Conversation(
          id: conv.first.id,
          peerId: conv.first.peerId,
          peerName: conv.first.peerName,
          peerPublicKey: conv.first.peerPublicKey,
          createdAt: conv.first.createdAt,
          lastMessageAt: m.timestamp,
        );
        await _persist();
        notifyListeners();
        break;
      case 'read':
        final fromId = msg['from'] as String;
        final messageId = msg['messageId'] as String;
        final convR = conversations.where((c) => c.peerId == fromId).toList();
        if (convR.isEmpty) break;
        final list = messagesByConv[convR.first.id];
        if (list == null) break;
        final target = list.where((m) => m.id == messageId).toList();
        if (target.isEmpty) break;
        target.first.read = true;
        await _persist();
        notifyListeners();
        break;
    }
  }

  Future<void> markConversationRead(String conversationId) async {
    final conv = conversations.where((c) => c.id == conversationId).toList();
    if (conv.isEmpty) return;
    final list = messagesByConv[conversationId];
    if (list == null) return;
    var changed = false;
    for (final m in list) {
      if (!m.fromMe && !m.read) {
        m.read = true;
        changed = true;
        relay.sendRead(conv.first.peerId, m.id);
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> sendMessage(String conversationId, String text) async {
    final conv = conversations.firstWhere((c) => c.id == conversationId);
    final key = _sessionKeys[conv.peerId]!;
    final cipher = await encryptMessage(key, text);
    final m = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      fromMe: true,
      ciphertext: cipher,
      timestamp: DateTime.now(),
      plaintext: text,
    );
    relay.sendCipher(conv.peerId, cipher, m.id);
    messagesByConv.putIfAbsent(conversationId, () => []).add(m);
    final idx = conversations.indexOf(conv);
    conversations[idx] = Conversation(
      id: conv.id,
      peerId: conv.peerId,
      peerName: conv.peerName,
      peerPublicKey: conv.peerPublicKey,
      createdAt: conv.createdAt,
      lastMessageAt: m.timestamp,
    );
    await _persist();
    notifyListeners();
  }

  String safetyNumberFor(String conversationId) {
    final conv = conversations.firstWhere((c) => c.id == conversationId);
    return safetyFingerprint(identity!.publicKey, Uint8List.fromList(conv.peerPublicKey));
  }
}
