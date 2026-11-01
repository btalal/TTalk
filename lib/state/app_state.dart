import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../crypto/e2e_crypto.dart';
import '../models/group.dart';
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
  List<Group> groups = [];
  final Map<String, SecretKey> _groupKeys = {};
  final Map<String, String> _peerNames = {};
  final Map<String, List<ChatMessage>> messagesByConv = {};
  bool unlocked = false;
  String? error;
  String? get myId => relay.myId;
  String? get myName => _myName;
  String? _myName;

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
        _peerNames[c.peerId] = c.peerName;
        _sessionKeys[c.peerId] = await identity!.deriveSessionKey(Uint8List.fromList(c.peerPublicKey));
      }
      await _restoreGroups();
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
        _peerNames[c.peerId] = c.peerName;
        _sessionKeys[c.peerId] = await identity!.deriveSessionKey(Uint8List.fromList(c.peerPublicKey));
      }
      await _restoreGroups();
    }
    notifyListeners();
  }

  Future<void> _restoreGroups() async {
    final data = await store.loadData();
    groups = data.groups;
    for (final g in groups) {
      final raw = data.groupKeys[g.id];
      if (raw != null) {
        _groupKeys[g.id] = SecretKey(Uint8List.fromList(raw));
      }
    }
  }

  Future<void> _persist() async {
    final all = messagesByConv.values.expand((l) => l).toList();
    await store.saveData(
      conversations: conversations,
      messages: all,
      groups: groups,
      groupKeys: _groupKeys.map((k, v) => MapEntry(k, v)),
    );
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
        _peerNames[peerId] = peerName;
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
        final groupId = msg['groupId'] as String?;
        final payload = Uint8List.fromList(base64Decode(msg['payload'] as String));
        if (groupId != null) {
          final gk = _groupKeys[groupId];
          if (gk == null) break;
          final plain = await decryptMessage(gk, payload);
          if (plain.startsWith('{"kind":"control"')) {
            try {
              final ctrl = GroupControl.fromJsonString(
                (jsonDecode(plain) as Map<String, dynamic>)['data'] as String,
              );
              await _applyControl(ctrl);
            } catch (_) {}
            break;
          }
          final m = ChatMessage(
            id: msg['messageId'] as String,
            conversationId: groupId,
            fromMe: false,
            ciphertext: payload,
            timestamp: DateTime.now(),
            plaintext: plain,
            isGroup: true,
            senderName: _peerNames[from] ?? 'Membre',
          );
          await _applyInboundMeta(m, plain);
          messagesByConv.putIfAbsent(groupId, () => []).add(m);
          relay.sendRead(from, m.id);
          await _persist();
          notifyListeners();
        } else {
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
          await _applyInboundMeta(m, plain);
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
        }
        break;
      case 'group_invite':
        final fromId = msg['from'] as String;
        final fromName = (msg['fromName'] as String?) ?? 'Un contact';
        final payload = Uint8List.fromList(base64Decode(msg['payload'] as String));
        final key = _sessionKeys[fromId];
        if (key == null) break;
        final plain = await decryptMessage(key, payload);
        final invite = GroupInvite.fromJsonString(plain, fromId: fromId, fromName: fromName);
        _pendingInvites.add(invite);
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

  Future<void> _applyInboundMeta(ChatMessage m, String plain) async {
    try {
      final meta = jsonDecode(plain) as Map<String, dynamic>;
      if (meta['kind'] == 'file') {
        m.kind = 'file';
        m.fileName = meta['fileName'] as String?;
        m.fileSize = meta['fileSize'] as int?;
        m.plaintext = null;
        await handleInboundFile(m, meta);
      }
    } catch (_) {
      m.kind = 'text';
    }
  }

  final List<GroupInvite> _pendingInvites = [];
  List<GroupInvite> get pendingInvites => List.unmodifiable(_pendingInvites);

  Future<String> createGroup(String name, List<String> memberPeerIds) async {
    final groupId = _uuid.v4();
    final keyBytes = await generateFileKey();
    _groupKeys[groupId] = SecretKey(keyBytes);
    final me = myId ?? 'moi';
    final members = [...memberPeerIds, me];
    groups.add(Group(
      id: groupId,
      name: name,
      memberIds: members,
      createdBy: me,
      createdAt: DateTime.now(),
      adminIds: [me],
      epoch: 1,
    ));
    for (final peerId in memberPeerIds) {
      final key = _sessionKeys[peerId];
      if (key == null) continue;
      final invite = GroupInvite(
        groupId: groupId,
        name: name,
        groupKeyB64: base64Encode(keyBytes),
        memberIds: members,
        adminIds: [me],
        epoch: 1,
        fromId: me,
        fromName: _myName ?? 'Moi',
      );
      final cipher = await encryptMessage(key, invite.toJsonString());
      relay.sendGroupInvite(peerId, cipher);
    }
    await _persist();
    notifyListeners();
    return groupId;
  }

  Future<void> acceptInvite(GroupInvite invite) async {
    final keyBytes = base64Decode(invite.groupKeyB64);
    _groupKeys[invite.groupId] = SecretKey(keyBytes);
    final existing = groups.where((g) => g.id == invite.groupId).toList();
    if (existing.isEmpty) {
      groups.add(Group(
        id: invite.groupId,
        name: invite.name,
        memberIds: invite.memberIds,
        createdBy: invite.fromId,
        createdAt: DateTime.now(),
        adminIds: invite.adminIds,
        epoch: invite.epoch,
      ));
    } else {
      final g = existing.first;
      groups[groups.indexOf(g)] = Group(
        id: g.id,
        name: invite.name,
        memberIds: invite.memberIds,
        createdBy: g.createdBy,
        createdAt: g.createdAt,
        adminIds: invite.adminIds,
        epoch: invite.epoch,
      );
    }
    _pendingInvites.removeWhere((i) => i.groupId == invite.groupId);
    await _persist();
    notifyListeners();
  }

  bool amAdmin(String groupId) {
    final me = myId;
    if (me == null) return false;
    final g = groups.where((e) => e.id == groupId).toList();
    if (g.isEmpty) return false;
    return g.first.isAdmin(me);
  }

  Future<void> leaveGroup(String groupId) async {
    final g = groups.firstWhere((e) => e.id == groupId);
    final me = myId;
    if (me == null) return;
    final remaining = g.memberIds.where((id) => id != me).toList();
    final admins = g.adminIds.where((id) => id != me).toList();
    if (g.isAdmin(me) && admins.isEmpty && remaining.isNotEmpty) {
      admins.add(remaining.first);
    }
    await _broadcastControl(groupId, GroupControl(
      kind: 'leave',
      groupId: groupId,
      memberIds: remaining,
      adminIds: admins,
      epoch: g.epoch,
      removedId: me,
    ));
    groups.removeWhere((e) => e.id == groupId);
    _groupKeys.remove(groupId);
    messagesByConv.remove(groupId);
    await _persist();
    notifyListeners();
  }

  Future<void> reInviteMember(String groupId, String peerId) async {
    final g = groups.firstWhere((e) => e.id == groupId);
    if (!amAdmin(groupId)) return;
    final key = _sessionKeys[peerId];
    if (key == null) return;
    final members = g.memberIds.contains(peerId) ? g.memberIds : [...g.memberIds, peerId];
    final invite = GroupInvite(
      groupId: groupId,
      name: g.name,
      groupKeyB64: base64Encode(await _groupKeys[groupId]!.extractBytes()),
      memberIds: members,
      adminIds: g.adminIds,
      epoch: g.epoch,
      fromId: myId ?? 'moi',
      fromName: _myName ?? 'Moi',
    );
    final cipher = await encryptMessage(key, invite.toJsonString());
    relay.sendGroupInvite(peerId, cipher);
    if (!g.memberIds.contains(peerId)) {
      groups[groups.indexOf(g)] = Group(
        id: g.id,
        name: g.name,
        memberIds: members,
        createdBy: g.createdBy,
        createdAt: g.createdAt,
        adminIds: g.adminIds,
        epoch: g.epoch,
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> removeMember(String groupId, String peerId) async {
    final g = groups.firstWhere((e) => e.id == groupId);
    if (!amAdmin(groupId) || peerId == myId) return;
    final newKeyBytes = await generateFileKey();
    final remaining = g.memberIds.where((id) => id != peerId).toList();
    final admins = g.adminIds.where((id) => id != peerId).toList();
    final control = GroupControl(
      kind: 'remove',
      groupId: groupId,
      memberIds: remaining,
      adminIds: admins,
      epoch: g.epoch + 1,
      newGroupKeyB64: base64Encode(newKeyBytes),
      removedId: peerId,
    );
    _groupKeys[groupId] = SecretKey(newKeyBytes);
    groups[groups.indexOf(g)] = Group(
      id: g.id,
      name: g.name,
      memberIds: remaining,
      createdBy: g.createdBy,
      createdAt: g.createdAt,
      adminIds: admins,
      epoch: g.epoch + 1,
    );
    await _broadcastControl(groupId, control, toExcluded: peerId);
    await _persist();
    notifyListeners();
  }

  Future<void> _broadcastControl(String groupId, GroupControl control, {String? toExcluded}) async {
    final g = groups.firstWhere((e) => e.id == groupId);
    final key = _groupKeys[groupId];
    if (key == null) return;
    final cipher = await encryptMessage(key, jsonEncode({'kind': 'control', 'data': control.toJsonString()}));
    final targets = g.memberIds.where((id) => id != myId && id != toExcluded).toList();
    if (targets.isNotEmpty) {
      relay.sendCipherToMany(targets, cipher, _uuid.v4(), groupId: groupId);
    }
  }

  Future<void> _applyControl(GroupControl c) async {
    if (c.kind == 'remove' && c.removedId == myId) {
      groups.removeWhere((e) => e.id == c.groupId);
      _groupKeys.remove(c.groupId);
      messagesByConv.remove(c.groupId);
      await _persist();
      notifyListeners();
      return;
    }
    final existing = groups.where((e) => e.id == c.groupId).toList();
    if (existing.isEmpty) return;
    final g = existing.first;
    if (c.epoch <= g.epoch && c.kind != 'remove') return;
    if (c.newGroupKeyB64 != null) {
      _groupKeys[c.groupId] = SecretKey(Uint8List.fromList(base64Decode(c.newGroupKeyB64!)));
    }
    groups[groups.indexOf(g)] = Group(
      id: g.id,
      name: g.name,
      memberIds: c.memberIds,
      createdBy: g.createdBy,
      createdAt: g.createdAt,
      adminIds: c.adminIds,
      epoch: c.epoch > g.epoch ? c.epoch : g.epoch,
    );
    await _persist();
    notifyListeners();
  }

  void declineInvite(GroupInvite invite) {
    _pendingInvites.removeWhere((i) => i.groupId == invite.groupId);
    notifyListeners();
  }

  SecretKey? groupKey(String groupId) => _groupKeys[groupId];

  String peerNameOf(String peerId) => _peerNames[peerId] ?? peerId.substring(0, 8);

  Future<void> sendGroupMessage(String groupId, String text) async {
    final g = groups.firstWhere((e) => e.id == groupId);
    final key = _groupKeys[groupId];
    if (key == null) return;
    final cipher = await encryptMessage(key, text);
    final m = ChatMessage(
      id: _uuid.v4(),
      conversationId: groupId,
      fromMe: true,
      ciphertext: cipher,
      timestamp: DateTime.now(),
      plaintext: text,
      isGroup: true,
      senderName: _myName ?? 'Moi',
    );
    final targets = g.memberIds.where((id) => id != myId).toList();
    relay.sendCipherToMany(targets, cipher, m.id, groupId: groupId);
    messagesByConv.putIfAbsent(groupId, () => []).add(m);
    await _persist();
    notifyListeners();
  }

  Future<ChatMessage> sendFile(String conversationId, String filePath, String fileName, int fileSize, {bool isGroup = false}) async {
    final bytes = await File(filePath).readAsBytes();
    final fileKey = SecretKey(await generateFileKey());
    final encFile = await encryptFile(fileKey, bytes);
    final sessionKey = isGroup
        ? _groupKeys[conversationId]!
        : _sessionKeys[conversations.firstWhere((c) => c.id == conversationId).peerId]!;
    final meta = jsonEncode({
      'kind': 'file',
      'fileName': fileName,
      'fileSize': fileSize,
      'fileKey': base64Encode(await fileKey.extractBytes()),
      'data': base64Encode(encFile),
    });
    final cipher = await encryptMessage(sessionKey, meta);
    final m = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      fromMe: true,
      ciphertext: cipher,
      timestamp: DateTime.now(),
      isGroup: isGroup,
      kind: 'file',
      fileName: fileName,
      fileSize: fileSize,
      senderName: _myName ?? 'Moi',
    );
    if (isGroup) {
      final g = groups.firstWhere((e) => e.id == conversationId);
      final targets = g.memberIds.where((id) => id != myId).toList();
      relay.sendCipherToMany(targets, cipher, m.id, groupId: conversationId);
    } else {
      final conv = conversations.firstWhere((c) => c.id == conversationId);
      relay.sendCipher(conv.peerId, cipher, m.id);
    }
    messagesByConv.putIfAbsent(conversationId, () => []).add(m);
    await _persist();
    notifyListeners();
    return m;
  }

  Future<void> handleInboundFile(ChatMessage m, Map<String, dynamic> meta) async {
    final fileKey = SecretKey(Uint8List.fromList(base64Decode(meta['fileKey'] as String)));
    final encData = base64Decode(meta['data'] as String);
    final clear = await decryptFile(fileKey, Uint8List.fromList(encData));
    final dir = await getApplicationDocumentsDirectory();
    final safeName = (meta['fileName'] as String).replaceAll(RegExp(r'[^\w.\-]'), '_');
    final outPath = '${dir.path}/talmessenger_files/$safeName';
    await File(outPath).parent.create(recursive: true);
    await File(outPath).writeAsBytes(clear);
    m.filePath = outPath;
    m.plaintext = null;
    await _persist();
    notifyListeners();
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
