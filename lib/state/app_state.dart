import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../crypto/e2e_crypto.dart';
import '../models/group.dart';
import '../models/outbound_packet.dart';
import '../models/message.dart';
import '../services/relay_client.dart';
import '../services/secure_store.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.store,
    required this.relay,
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

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
  String? get myId => relay.myId ?? identity?.stableId;
  String? get myName => relay.displayName;
  final List<OutboundPacket> _outbox = [];
  final Set<String> _inFlight = {};
  Timer? _outboxRetry;
  int get pendingCount => _outbox.length;
  String get relayUrl => store.relayUrl;
  bool get registered => relay.myId != null;

  Future<void> init({String? pin}) async {
    identity = await store.loadOrCreateIdentity();
    await store.saveIdentity(identity!);
    relay.configureIdentity(identity!);
    if (pin != null && store.hasPin) {
      unlocked = await store.unlockWithPin(pin);
    } else if (!store.hasPin && pin != null) {
      await store.setupPin(pin);
      unlocked = true;
    }
    if (unlocked) await _restoreState();
    relay.onInbound = _handleInbound;
    relay.onMessageError = (_) {
      error = 'Un message invalide n’a pas pu être traité.';
      notifyListeners();
    };
    relay.onStateChange = (state) {
      if (state != RelayState.connected) _inFlight.clear();
      notifyListeners();
    };
    notifyListeners();
  }

  Future<void> unlock(String pin) async {
    unlocked = await store.unlockWithPin(pin);
    if (unlocked) await _restoreState();
    await connectSavedRelay();
    _registerIfReady();
    notifyListeners();
  }

  Future<void> _restoreState() async {
    final data = await store.loadData();
    conversations = data.conversations
        .map(
          (c) => Conversation(
            id: c.id,
            peerId: identityId(Uint8List.fromList(c.peerPublicKey)),
            peerName: c.peerName,
            peerPublicKey: c.peerPublicKey,
            createdAt: c.createdAt,
            lastMessageAt: c.lastMessageAt,
          ),
        )
        .toList();
    messagesByConv.clear();
    _sessionKeys.clear();
    _peerKeys.clear();
    _peerNames.clear();
    for (final message in data.messages) {
      messagesByConv.putIfAbsent(message.conversationId, () => []).add(message);
    }
    for (final contact in conversations) {
      final publicKey = Uint8List.fromList(contact.peerPublicKey);
      _peerKeys[contact.peerId] = publicKey;
      _peerNames[contact.peerId] = contact.peerName;
      _sessionKeys[contact.peerId] = await identity!.deriveSessionKey(
        publicKey,
      );
    }
    _restoreGroups(data.groups, data.groupKeys);
    _outbox
      ..clear()
      ..addAll(data.outbox);
    _pendingInvites
      ..clear()
      ..addAll(data.pendingInvites);
  }

  Future<void> connectSavedRelay() async {
    if (unlocked && relayUrl.isNotEmpty) await connectRelay(relayUrl);
  }

  Future<void> configureRelay(String input) async {
    final url = RelayClient.normalizeUrl(input);
    relay.disconnect();
    _inFlight.clear();
    await store.setRelayUrl(url);
    await connectSavedRelay();
  }

  void _restoreGroups(List<Group> restored, Map<String, List<int>> keys) {
    groups = restored.map((group) {
      if (group.memberIds.every(
        (id) => RegExp(r'^[a-f0-9]{64}$').hasMatch(id),
      )) {
        return group;
      }
      return Group.fromJson({...group.toJson(), 'requiresRecreation': true});
    }).toList();
    _groupKeys.clear();
    for (final g in groups) {
      final raw = keys[g.id];
      if (raw != null) {
        _groupKeys[g.id] = SecretKey(Uint8List.fromList(raw));
      }
    }
  }

  Future<void> createPin(String pin) async {
    if (store.hasPin) throw StateError('Un code PIN existe déjà');
    await store.setupPin(pin);
    unlocked = true;
    await connectSavedRelay();
    _registerIfReady();
    notifyListeners();
  }

  Future<void> connectRelay(String url) async {
    error = null;
    try {
      await relay.connect(url);
      _registerIfReady();
    } catch (_) {
      error =
          'Relais indisponible. Tes messages restent accessibles hors ligne.';
    }
    notifyListeners();
  }

  void _registerIfReady() {
    if (unlocked && identity != null && relay.state == RelayState.connected) {
      relay.register(name: store.displayName, publicKey: identity!.publicKey);
    }
  }

  Future<void> setDisplayName(String name) async {
    final value = name.trim();
    if (value.isEmpty || value.length > 40) {
      throw ArgumentError('Nom : 1 à 40 caractères');
    }
    await store.setDisplayName(value);
    _registerIfReady();
    notifyListeners();
  }

  Future<void> _persist() async {
    final all = messagesByConv.values.expand((l) => l).toList();
    await store.saveData(
      conversations: conversations,
      messages: all,
      groups: groups,
      groupKeys: _groupKeys.map((k, v) => MapEntry(k, v)),
      outbox: List.of(_outbox),
      pendingInvites: List.of(_pendingInvites),
    );
    _flushOutbox();
  }

  void _enqueue(OutboundPacket packet) {
    if (packet.recipients.isEmpty) return;
    final bytes = _outbox.fold<int>(0, (n, p) => n + p.payload.length);
    if (_outbox.length >= 2000 ||
        bytes + packet.payload.length > 64 * 1024 * 1024) {
      throw StateError(
        'La file d’envoi est pleine. Reconnecte le relais avant de continuer.',
      );
    }
    _outbox.add(packet);
  }

  void _flushOutbox() {
    if (relay.state != RelayState.connected || relay.myId == null) return;
    for (final packet in _outbox) {
      final targets = packet.recipients
          .where((to) => !_inFlight.contains('${packet.id}:$to'))
          .take(16 - _inFlight.length)
          .toList();
      if (targets.isEmpty) continue;
      try {
        relay.sendPacket(packet, targets);
        for (final to in targets) {
          _inFlight.add('${packet.id}:$to');
        }
      } catch (_) {
        return;
      }
      if (_inFlight.length >= 16) break;
    }
  }

  Future<Uint8List> _seal(
    SecretKey key,
    String id,
    String body, {
    String? groupId,
    String kind = 'text',
  }) => encryptMessage(
    key,
    jsonEncode({
      'v': 2,
      'kind': kind,
      'id': id,
      'from': myId,
      'groupId': groupId,
      'body': body,
      'sentAt': DateTime.now().toUtc().toIso8601String(),
    }),
  );

  Future<({String body, DateTime sentAt, String kind})> _open(
    SecretKey key,
    Uint8List payload,
    String from,
    String id,
    String? groupId,
  ) async {
    final body = jsonDecode(await decryptMessage(key, payload));
    if (body is! Map ||
        body['v'] != 2 ||
        body['id'] != id ||
        body['from'] != from ||
        body['groupId'] != groupId ||
        body['body'] is! String ||
        ![
          'text',
          'file',
          'control',
          'receipt',
          'invite',
        ].contains(body['kind'])) {
      throw const FormatException('Métadonnées chiffrées incohérentes');
    }
    if (body['sentAt'] is! String) {
      throw const FormatException('Date du message invalide');
    }
    final sentAt = DateTime.tryParse(body['sentAt'] as String);
    if (sentAt == null) throw const FormatException('Date du message invalide');
    return (
      body: body['body'] as String,
      sentAt: sentAt.toLocal(),
      kind: body['kind'] as String,
    );
  }

  Future<void> _queueReceipt(
    String type,
    String recipient,
    String messageId,
    String? groupId,
  ) async {
    final key = groupId == null ? _sessionKeys[recipient] : _groupKeys[groupId];
    if (key == null) return;
    final id = _uuid.v4();
    final payload = await _seal(
      key,
      id,
      jsonEncode({'kind': 'receipt', 'type': type, 'messageId': messageId}),
      kind: 'receipt',
      groupId: groupId,
    );
    _enqueue(
      OutboundPacket(
        id: id,
        type: 'cipher',
        recipients: [recipient],
        payload: payload,
        groupId: groupId,
      ),
    );
  }

  Future<bool> _handleReceipt(
    String plain,
    String from,
    String? groupId,
  ) async {
    Object? body;
    try {
      body = jsonDecode(plain);
    } on FormatException {
      return false;
    }
    if (body is! Map || body['kind'] != 'receipt') return false;
    if (!['read', 'delivered'].contains(body['type']) ||
        body['messageId'] is! String) {
      throw const FormatException('Accusé invalide');
    }
    await _applyReceipt({
      'type': body['type'],
      'from': from,
      'messageId': body['messageId'],
      'groupId': groupId,
    });
    return true;
  }

  Future<String?> pairWithCode(String code) async {
    if (relay.state != RelayState.connected) return 'Non connecté au relais';
    relay.answerPairing(code);
    return null;
  }

  Future<void> _handleInbound(Map<String, dynamic> msg) async {
    switch (msg['type']) {
      case 'registered':
        error = null;
        _inFlight.clear();
        await _persist();
        notifyListeners();
        break;
      case 'accepted':
        final id = msg['messageId'] as String,
            recipient = msg['recipientId'] as String;
        final packet = _outbox.where((p) => p.id == id).firstOrNull;
        if (packet == null || !packet.recipients.remove(recipient)) break;
        _inFlight.remove('$id:$recipient');
        if (packet.recipients.isEmpty) {
          _outbox.remove(packet);
          for (final list in messagesByConv.values) {
            for (final message in list.where((m) => m.id == id && m.fromMe)) {
              message.pending = false;
            }
          }
        }
        await _persist();
        notifyListeners();
        break;
      case 'relay_error':
        error =
            msg['reason'] as String? ?? 'Le relais n’a pas accepté l’envoi.';
        _outboxRetry?.cancel();
        _outboxRetry = Timer(const Duration(seconds: 30), () {
          _inFlight.clear();
          _flushOutbox();
        });
        notifyListeners();
        break;
      case 'pair_error':
        error = msg['reason'] as String?;
        notifyListeners();
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
          conversations.add(
            Conversation(
              id: _uuid.v4(),
              peerId: peerId,
              peerName: peerName,
              peerPublicKey: peerPubBytes,
              createdAt: DateTime.now(),
            ),
          );
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
        final messageId = msg['messageId'] as String;
        final groupId = msg['groupId'] as String?;
        final encoded = msg['payload'] as String;
        if (encoded.length > 16 * 1024 * 1024) break;
        final payload = Uint8List.fromList(base64Decode(encoded));
        if (groupId != null) {
          final pending = _pendingInvites
              .where((i) => i.groupId == groupId)
              .firstOrNull;
          final gk =
              _groupKeys[groupId] ??
              (pending == null
                  ? null
                  : SecretKey(base64Decode(pending.groupKeyB64)));
          if (gk == null) break;
          final group = groups.where((g) => g.id == groupId).firstOrNull;
          if (group != null && !group.memberIds.contains(from)) break;
          if (messagesByConv[groupId]?.any((m) => m.id == messageId) ?? false) {
            await _persist();
            break;
          }
          final opened = await _open(gk, payload, from, messageId, groupId);
          final plain = opened.body;
          if (opened.kind == 'receipt') {
            await _handleReceipt(plain, from, groupId);
            break;
          }
          if (opened.kind == 'control') {
            late final GroupControl ctrl;
            try {
              ctrl = GroupControl.fromJsonString(
                (jsonDecode(plain) as Map<String, dynamic>)['data'] as String,
              );
            } on TypeError {
              throw const FormatException('Contrôle de groupe invalide');
            }
            if (ctrl.groupId == groupId) {
              if (_groupKeys.containsKey(groupId)) {
                await _applyControl(ctrl, from);
              } else if (pending != null) {
                await _applyPendingControl(pending, ctrl, from);
              }
            }
            break;
          }
          if (!_groupKeys.containsKey(groupId)) break;
          if (!['text', 'file'].contains(opened.kind)) {
            throw const FormatException('Type de message invalide');
          }
          final m = ChatMessage(
            id: msg['messageId'] as String,
            conversationId: groupId,
            fromMe: false,
            ciphertext: payload,
            timestamp: opened.sentAt,
            plaintext: plain,
            isGroup: true,
            senderId: from,
            senderName: _peerNames[from] ?? 'Membre',
          );
          if (opened.kind == 'file') await _applyInboundMeta(m, plain);
          messagesByConv.putIfAbsent(groupId, () => []).add(m);
          await _queueReceipt('delivered', from, m.id, groupId);
          await _persist();
          notifyListeners();
        } else {
          final conv = conversations.where((c) => c.peerId == from).toList();
          if (conv.isEmpty) break;
          if (messagesByConv[conv.first.id]?.any((m) => m.id == messageId) ??
              false) {
            await _persist();
            break;
          }
          final key = _sessionKeys[from];
          if (key == null) break;
          final opened = await _open(key, payload, from, messageId, null);
          final plain = opened.body;
          if (opened.kind == 'receipt') {
            await _handleReceipt(plain, from, null);
            break;
          }
          if (!['text', 'file'].contains(opened.kind)) {
            throw const FormatException('Type de message invalide');
          }
          final m = ChatMessage(
            id: msg['messageId'] as String,
            conversationId: conv.first.id,
            fromMe: false,
            ciphertext: payload,
            timestamp: opened.sentAt,
            plaintext: plain,
          );
          if (opened.kind == 'file') await _applyInboundMeta(m, plain);
          messagesByConv.putIfAbsent(conv.first.id, () => []).add(m);
          await _queueReceipt('delivered', from, m.id, groupId);
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
        final payload = Uint8List.fromList(
          base64Decode(msg['payload'] as String),
        );
        final key = _sessionKeys[fromId];
        if (key == null) break;
        final opened = await _open(
          key,
          payload,
          fromId,
          msg['messageId'] as String,
          null,
        );
        if (opened.kind != 'invite') {
          throw const FormatException('Invitation invalide');
        }
        late final GroupInvite invite;
        try {
          invite = GroupInvite.fromJsonString(
            opened.body,
            fromId: fromId,
            fromName: fromName,
          );
        } on TypeError {
          throw const FormatException('Invitation invalide');
        }
        _pendingInvites.removeWhere((i) => i.groupId == invite.groupId);
        if (!groups.any((g) => g.id == invite.groupId)) {
          _pendingInvites.add(invite);
        }
        await _persist();
        notifyListeners();
        break;
    }
  }

  Future<void> _applyReceipt(Map<String, dynamic> msg) async {
    final from = msg['from'] as String;
    final id = msg['messageId'] as String;
    final groupId = msg['groupId'] as String?;
    final conversation = conversations
        .where((c) => c.peerId == from)
        .firstOrNull;
    final group = groups.where((g) => g.id == groupId).firstOrNull;
    if (groupId != null && (group == null || !group.memberIds.contains(from))) {
      return;
    }
    final chatId = groupId ?? conversation?.id;
    final message = messagesByConv[chatId]
        ?.where((m) => m.id == id && m.fromMe)
        .firstOrNull;
    if (message == null) return;
    if (msg['type'] == 'read') {
      if (message.readBy.contains(from)) return;
      message.readBy = [...message.readBy, from];
      message.read =
          group == null ||
          group.memberIds
              .where((id) => id != myId)
              .every(message.readBy.contains);
    } else if (message.delivered) {
      return;
    }
    message.delivered = true;
    await _persist();
    notifyListeners();
  }

  Future<void> markConversationRead(String conversationId) async {
    final conversation = conversations
        .where((c) => c.id == conversationId)
        .firstOrNull;
    final group = groups.where((g) => g.id == conversationId).firstOrNull;
    final list = messagesByConv[conversationId];
    if ((conversation == null && group == null) || list == null) return;
    var changed = false;
    for (final message in list) {
      if (!message.fromMe && !message.isSystem && !message.read) {
        message.read = true;
        changed = true;
        final recipient = conversation?.peerId ?? message.senderId;
        if (recipient != null) {
          await _queueReceipt('read', recipient, message.id, group?.id);
        }
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _applyInboundMeta(ChatMessage message, String plain) async {
    Object? decoded;
    try {
      decoded = jsonDecode(plain);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic> || decoded['kind'] != 'file') {
      throw const FormatException('Pièce jointe invalide');
    }
    if (decoded['fileName'] is! String ||
        (decoded['fileName'] as String).length > 255 ||
        decoded['fileSize'] is! int ||
        (decoded['fileSize'] as int) < 0 ||
        (decoded['fileSize'] as int) > maxAttachmentBytes ||
        decoded['fileKey'] is! String ||
        decoded['data'] is! String) {
      throw const FormatException('Pièce jointe invalide');
    }
    message.kind = 'file';
    message.fileName = decoded['fileName'] as String;
    message.fileSize = decoded['fileSize'] as int;
    message.plaintext = null;
    await handleInboundFile(message, decoded);
  }

  final List<GroupInvite> _pendingInvites = [];
  List<GroupInvite> get pendingInvites => List.unmodifiable(_pendingInvites);

  Future<String> createGroup(String name, List<String> memberPeerIds) async {
    final groupId = _uuid.v4();
    final keyBytes = await generateFileKey();
    _groupKeys[groupId] = SecretKey(keyBytes);
    final me = myId ?? 'moi';
    final members = [...memberPeerIds, me];
    groups.add(
      Group(
        id: groupId,
        name: name,
        memberIds: members,
        createdBy: me,
        ownerId: me,
        joinedMemberIds: [me],
        createdAt: DateTime.now(),
        adminIds: [me],
        epoch: 1,
      ),
    );
    for (final peerId in memberPeerIds) {
      final key = _sessionKeys[peerId];
      if (key == null) continue;
      final invite = GroupInvite(
        groupId: groupId,
        name: name,
        groupKeyB64: base64Encode(keyBytes),
        memberIds: members,
        adminIds: [me],
        ownerId: me,
        joinedMemberIds: [me],
        epoch: 1,
        fromId: me,
        fromName: myName ?? 'Moi',
      );
      final id = _uuid.v4();
      final cipher = await _seal(
        key,
        id,
        invite.toJsonString(),
        kind: 'invite',
      );
      _enqueue(
        OutboundPacket(
          id: id,
          type: 'group_invite',
          recipients: [peerId],
          payload: cipher,
        ),
      );
    }
    await _persist();
    notifyListeners();
    return groupId;
  }

  Future<void> _applyPendingControl(
    GroupInvite invite,
    GroupControl control,
    String senderId,
  ) async {
    final group = Group(
      id: invite.groupId,
      name: invite.name,
      memberIds: invite.memberIds,
      createdBy: invite.fromId,
      ownerId: invite.ownerId ?? invite.fromId,
      ownershipVersion: invite.ownershipVersion,
      joinedMemberIds: invite.joinedMemberIds ?? [invite.fromId],
      createdAt: DateTime.now(),
      adminIds: invite.adminIds,
      epoch: invite.epoch,
    );
    final updated = group.applyControl(control, senderId: senderId);
    if (updated == null) return;
    final index = _pendingInvites.indexOf(invite);
    if (!updated.memberIds.contains(myId)) {
      _pendingInvites.removeAt(index);
    } else {
      _pendingInvites[index] = GroupInvite(
        groupId: updated.id,
        name: updated.name,
        groupKeyB64: control.kind == 'remove'
            ? control.newGroupKeyB64!
            : invite.groupKeyB64,
        memberIds: updated.memberIds,
        adminIds: updated.adminIds,
        ownerId: updated.ownerId,
        ownershipVersion: updated.ownershipVersion,
        joinedMemberIds: updated.joinedMemberIds,
        epoch: updated.epoch,
        fromId: invite.fromId,
        fromName: invite.fromName,
      );
    }
    await _persist();
    notifyListeners();
  }

  Future<void> acceptInvite(GroupInvite invite) async {
    invite =
        _pendingInvites.where((i) => i.groupId == invite.groupId).firstOrNull ??
        invite;
    final me = myId;
    if (me == null || !invite.memberIds.contains(me)) return;
    final existing = groups.where((g) => g.id == invite.groupId).toList();
    // Replayed invitations must not roll back a key, owner or membership state.
    if (existing.isNotEmpty) {
      _pendingInvites.removeWhere((i) => i.groupId == invite.groupId);
      notifyListeners();
      return;
    }
    final keyBytes = base64Decode(invite.groupKeyB64);
    _groupKeys[invite.groupId] = SecretKey(keyBytes);
    final group = Group(
      id: invite.groupId,
      name: invite.name,
      memberIds: invite.memberIds,
      createdBy: invite.fromId,
      ownerId: invite.ownerId ?? invite.fromId,
      ownershipVersion: invite.ownershipVersion,
      joinedMemberIds: (invite.joinedMemberIds ?? [invite.fromId])
          .where((id) => id != me)
          .toList(),
      createdAt: DateTime.now(),
      adminIds: invite.adminIds,
      epoch: invite.epoch,
    );
    groups.add(group);
    _pendingInvites.removeWhere((i) => i.groupId == invite.groupId);
    final control = GroupControl(
      kind: 'join',
      groupId: group.id,
      memberIds: group.memberIds,
      adminIds: group.adminIds,
      epoch: group.epoch,
      memberId: me,
      memberName: myName ?? 'Un membre',
    );
    await _broadcastControl(group.id, control);
    await _applyControl(control, me);
  }

  Future<void> transferGroupOwnership(String groupId, String newOwnerId) async {
    final group = groups.firstWhere((g) => g.id == groupId);
    final me = myId;
    if (me == null) throw StateError('Non connecté au relais');
    final control = GroupControl(
      kind: 'transfer',
      groupId: groupId,
      memberIds: group.memberIds,
      adminIds: group.adminIds,
      epoch: group.epoch,
      ownerId: newOwnerId,
      ownerVersion: group.ownershipVersion + 1,
    );
    if (group.applyControl(control, senderId: me) == null) {
      throw StateError(
        'Seul le propriétaire peut transférer le groupe à un membre actif.',
      );
    }
    await _broadcastControl(groupId, control);
    await _applyControl(control, me);
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
    await _broadcastControl(
      groupId,
      GroupControl(
        kind: 'leave',
        groupId: groupId,
        memberIds: remaining,
        adminIds: admins,
        epoch: g.epoch,
        removedId: me,
      ),
    );
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
    final members = g.memberIds.contains(peerId)
        ? g.memberIds
        : [...g.memberIds, peerId];
    final invite = GroupInvite(
      groupId: groupId,
      name: g.name,
      groupKeyB64: base64Encode(await _groupKeys[groupId]!.extractBytes()),
      memberIds: members,
      adminIds: g.adminIds,
      ownerId: g.ownerId,
      ownershipVersion: g.ownershipVersion,
      joinedMemberIds: g.joinedMemberIds,
      epoch: g.epoch,
      fromId: myId ?? 'moi',
      fromName: myName ?? 'Moi',
    );
    if (!g.memberIds.contains(peerId)) {
      final control = GroupControl(
        kind: 'members',
        groupId: groupId,
        memberIds: members,
        adminIds: g.adminIds,
        epoch: g.epoch,
      );
      await _broadcastControl(groupId, control);
      await _applyControl(control, myId!);
    }
    final id = _uuid.v4();
    final cipher = await _seal(key, id, invite.toJsonString(), kind: 'invite');
    _enqueue(
      OutboundPacket(
        id: id,
        type: 'group_invite',
        recipients: [peerId],
        payload: cipher,
      ),
    );
    await _persist();
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
    if (g.applyControl(control, senderId: myId!) == null) return;
    await _broadcastControl(groupId, control, toExcluded: peerId);
    await _applyControl(control, myId!);
  }

  Future<void> _broadcastControl(
    String groupId,
    GroupControl control, {
    String? toExcluded,
  }) async {
    final g = groups.firstWhere((e) => e.id == groupId);
    final key = _groupKeys[groupId];
    if (key == null) return;
    final id = _uuid.v4();
    final cipher = await _seal(
      key,
      id,
      jsonEncode({'kind': 'control', 'data': control.toJsonString()}),
      groupId: groupId,
      kind: 'control',
    );
    final targets = g.memberIds
        .where((id) => id != myId && id != toExcluded)
        .toList();
    if (targets.isNotEmpty) {
      _enqueue(
        OutboundPacket(
          id: id,
          type: 'cipher',
          recipients: targets,
          payload: cipher,
          groupId: groupId,
        ),
      );
    }
  }

  Future<void> _applyControl(GroupControl control, String senderId) async {
    final existing = groups.where((g) => g.id == control.groupId).toList();
    if (existing.isEmpty) return;
    final group = existing.first;
    final updated = group.applyControl(control, senderId: senderId);
    if (updated == null) return;
    if (control.newGroupKeyB64 != null && control.kind == 'remove') {
      _groupKeys[group.id] = SecretKey(base64Decode(control.newGroupKeyB64!));
    }
    groups[groups.indexOf(group)] = updated;
    if (!updated.memberIds.contains(myId)) {
      groups.remove(updated);
      _groupKeys.remove(group.id);
      messagesByConv.remove(group.id);
    } else if (control.kind == 'join') {
      final name = _peerNames[senderId] ?? control.memberName ?? 'Un membre';
      _peerNames[senderId] = name;
      _addGroupEvent(group.id, '$name a rejoint le groupe.');
      // Invitations may predate other members' acceptance. The owner supplies
      // the accepted roster so a newcomer can validate later ownership changes.
      if (updated.ownerId == myId && senderId != myId) {
        final sync = GroupControl(
          kind: 'sync',
          groupId: updated.id,
          memberIds: updated.memberIds,
          adminIds: updated.adminIds,
          epoch: updated.epoch,
          joinedMemberIds: updated.joinedMemberIds,
        );
        final id = _uuid.v4();
        final payload = await _seal(
          _groupKeys[group.id]!,
          id,
          jsonEncode({'kind': 'control', 'data': sync.toJsonString()}),
          groupId: group.id,
          kind: 'control',
        );
        _enqueue(
          OutboundPacket(
            id: id,
            type: 'cipher',
            recipients: [senderId],
            payload: payload,
            groupId: group.id,
          ),
        );
      }
    } else if (control.kind == 'transfer') {
      _addGroupEvent(
        group.id,
        '${peerNameOf(updated.ownerId)} est maintenant propriétaire du groupe.',
      );
    }
    await _persist();
    notifyListeners();
  }

  void _addGroupEvent(String groupId, String text) {
    messagesByConv
        .putIfAbsent(groupId, () => [])
        .add(
          ChatMessage(
            id: _uuid.v4(),
            conversationId: groupId,
            fromMe: false,
            ciphertext: const [],
            timestamp: DateTime.now(),
            plaintext: text,
            isGroup: true,
            kind: 'system',
            read: true,
          ),
        );
  }

  Future<void> declineInvite(GroupInvite invite) async {
    _pendingInvites.removeWhere((i) => i.groupId == invite.groupId);
    await _persist();
    notifyListeners();
  }

  SecretKey? groupKey(String groupId) => _groupKeys[groupId];

  String peerNameOf(String peerId) => peerId == myId
      ? (myName ?? 'Moi')
      : (_peerNames[peerId] ??
            peerId.substring(0, peerId.length < 8 ? peerId.length : 8));

  static const maxAttachmentBytes = 5 * 1024 * 1024;

  Future<void> sendGroupMessage(String groupId, String text) async {
    final g = groups.firstWhere((e) => e.id == groupId);
    if (g.requiresRecreation) {
      throw StateError('Ce groupe ancien doit être recréé.');
    }
    final key = _groupKeys[groupId];
    if (key == null) throw StateError('Clé du groupe indisponible.');
    final id = _uuid.v4();
    final cipher = await _seal(key, id, text, groupId: groupId);
    final m = ChatMessage(
      id: id,
      pending: true,
      conversationId: groupId,
      fromMe: true,
      ciphertext: cipher,
      timestamp: DateTime.now(),
      plaintext: text,
      isGroup: true,
      senderName: myName ?? 'Moi',
    );
    final targets = g.memberIds.where((id) => id != myId).toList();
    _enqueue(
      OutboundPacket(
        id: m.id,
        type: 'cipher',
        recipients: targets,
        payload: cipher,
        groupId: groupId,
      ),
    );
    messagesByConv.putIfAbsent(groupId, () => []).add(m);
    await _persist();
    notifyListeners();
  }

  Future<ChatMessage> sendFile(
    String conversationId,
    String filePath,
    String fileName,
    int fileSize, {
    bool isGroup = false,
  }) async {
    final file = File(filePath);
    if (await file.length() > maxAttachmentBytes) {
      throw ArgumentError('Pièce jointe limitée à 5 Mo.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxAttachmentBytes) {
      throw ArgumentError('Pièce jointe limitée à 5 Mo.');
    }
    final fileKey = SecretKey(await generateFileKey());
    final encFile = await encryptFile(fileKey, bytes);
    final sessionKey = isGroup
        ? _groupKeys[conversationId]!
        : _sessionKeys[conversations
              .firstWhere((c) => c.id == conversationId)
              .peerId]!;
    final meta = jsonEncode({
      'kind': 'file',
      'fileName': fileName,
      'fileSize': fileSize,
      'fileKey': base64Encode(await fileKey.extractBytes()),
      'data': base64Encode(encFile),
    });
    final id = _uuid.v4();
    if (isGroup &&
        groups.firstWhere((g) => g.id == conversationId).requiresRecreation) {
      throw StateError('Ce groupe ancien doit être recréé.');
    }
    final cipher = await _seal(
      sessionKey,
      id,
      meta,
      groupId: isGroup ? conversationId : null,
      kind: 'file',
    );
    final m = ChatMessage(
      id: id,
      pending: true,
      conversationId: conversationId,
      fromMe: true,
      ciphertext: cipher,
      timestamp: DateTime.now(),
      isGroup: isGroup,
      kind: 'file',
      fileName: fileName,
      fileSize: bytes.length,
      filePath: file.path,
      senderName: myName ?? 'Moi',
    );
    if (isGroup) {
      final g = groups.firstWhere((e) => e.id == conversationId);
      final targets = g.memberIds.where((id) => id != myId).toList();
      _enqueue(
        OutboundPacket(
          id: m.id,
          type: 'cipher',
          recipients: targets,
          payload: cipher,
          groupId: conversationId,
        ),
      );
    } else {
      final conv = conversations.firstWhere((c) => c.id == conversationId);
      _enqueue(
        OutboundPacket(
          id: m.id,
          type: 'cipher',
          recipients: [conv.peerId],
          payload: cipher,
        ),
      );
    }
    messagesByConv.putIfAbsent(conversationId, () => []).add(m);
    await _persist();
    notifyListeners();
    return m;
  }

  Future<void> handleInboundFile(
    ChatMessage m,
    Map<String, dynamic> meta,
  ) async {
    final keyBytes = base64Decode(meta['fileKey'] as String);
    if (keyBytes.length != aesKeyLength) {
      throw const FormatException('Clé de fichier invalide');
    }
    final fileKey = SecretKey(keyBytes);
    final data = meta['data'] as String;
    if (data.length > (maxAttachmentBytes + 64) * 4 ~/ 3 + 4) {
      throw const FormatException('Pièce jointe trop grande');
    }
    final encData = base64Decode(data);
    final clear = await decryptFile(fileKey, Uint8List.fromList(encData));
    if (clear.length > maxAttachmentBytes) {
      throw const FormatException('Pièce jointe trop grande');
    }
    final dir = await _documentsDirectory();
    final safeName = (meta['fileName'] as String).replaceAll(
      RegExp(r'[^\w.\-]'),
      '_',
    );
    final outPath = '${dir.path}/ttalk_files/${_uuid.v4()}_$safeName';
    await File(outPath).parent.create(recursive: true);
    await File(outPath).writeAsBytes(clear);
    m.filePath = outPath;
    m.fileSize = clear.length;
    m.plaintext = null;
  }

  Future<void> sendMessage(String conversationId, String text) async {
    final conv = conversations.firstWhere((c) => c.id == conversationId);
    final key = _sessionKeys[conv.peerId]!;
    final id = _uuid.v4();
    final cipher = await _seal(key, id, text);
    final m = ChatMessage(
      id: id,
      pending: true,
      conversationId: conversationId,
      fromMe: true,
      ciphertext: cipher,
      timestamp: DateTime.now(),
      plaintext: text,
    );
    _enqueue(
      OutboundPacket(
        id: m.id,
        type: 'cipher',
        recipients: [conv.peerId],
        payload: cipher,
      ),
    );
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

  @override
  void dispose() {
    _outboxRetry?.cancel();
    relay.onStateChange = null;
    relay.onMessageError = null;
    relay.onInbound = null;
    relay.disconnect();
    super.dispose();
  }

  String safetyNumberFor(String conversationId) {
    final conv = conversations.firstWhere((c) => c.id == conversationId);
    return safetyFingerprint(
      identity!.publicKey,
      Uint8List.fromList(conv.peerPublicKey),
    );
  }
}
