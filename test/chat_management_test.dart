import 'dart:convert';
import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:ttalk/models/message.dart';
import 'package:ttalk/models/outbound_packet.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttalk/crypto/e2e_crypto.dart';
import 'package:ttalk/models/group.dart';
import 'package:ttalk/state/app_state.dart';

import 'support/group_fakes.dart';

class PausingStore extends MemoryStore {
  Completer<void>? failAfterRelease;
  Completer<void>? writeStarted;
  @override
  Future<void> saveData({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    List<Group> groups = const [],
    Map<String, SecretKey> groupKeys = const {},
    List<OutboundPacket> outbox = const [],
    List<GroupInvite> pendingInvites = const [],
  }) async {
    final release = failAfterRelease;
    failAfterRelease = null;
    if (release != null) {
      writeStarted!.complete();
      await release.future;
      throw StateError('Simulated delayed write failure');
    }
    await super.saveData(
      conversations: conversations,
      messages: messages,
      groups: groups,
      groupKeys: groupKeys,
      outbox: outbox,
      pendingInvites: pendingInvites,
    );
  }
}

class Fixture {
  Fixture(this.app, this.store, this.relay, this.peer);
  final AppState app;
  final MemoryStore store;
  final MemoryRelay relay;
  final IdentityKeys peer;
  String get chatId => app.conversations.single.id;
  String get peerId => peer.stableId;
  Future<Map<String, dynamic>> incoming(String id, String body) async {
    final key = await peer.deriveSessionKey(app.identity!.publicKey);
    return {
      'type': 'cipher',
      'from': peerId,
      'messageId': id,
      'payload': base64Encode(await transportPacket(key, body, peerId, id)),
    };
  }

  static Future<Fixture> create({MemoryStore? memoryStore}) async {
    final store = memoryStore ?? MemoryStore();
    final relay = MemoryRelay('alice', 'Alice');
    final app = AppState(store: store, relay: relay);
    await app.init(pin: '1234');
    final peer = await IdentityKeys.generate();
    await relay.onInbound!({
      'type': 'peer_matched',
      'peerId': peer.stableId,
      'peerName': 'Bob',
      'peerPublicKey': base64Encode(peer.publicKey),
    });
    return Fixture(app, store, relay, peer);
  }
}

void main() {
  test(
    'clearing history or leaving preserves pending ownership controls',
    () async {
      final store = MemoryStore();
      final app = AppState(store: store, relay: MemoryRelay('alice', 'Alice'));
      addTearDown(app.dispose);
      await app.init(pin: '123456');
      final id = await app.createGroup('Amis', ['bob']);
      final group = app.groups.single;
      app.groups[0] = group.applyControl(
        GroupControl(
          kind: 'join',
          groupId: id,
          memberIds: group.memberIds,
          adminIds: group.adminIds,
          epoch: 1,
          memberId: 'bob',
        ),
        senderId: 'bob',
      )!;
      await app.transferGroupOwnership(id, 'bob');
      final transferId = store.savedOutbox.single.id;
      await app.sendGroupMessage(id, 'à effacer');
      final messageId = app.messagesByConv[id]!.last.id;
      await app.clearHistory(id);
      expect(store.savedOutbox.any((p) => p.id == transferId), isTrue);
      expect(store.savedOutbox.any((p) => p.id == messageId), isFalse);
      await app.deleteGroup(id);
      expect(store.savedOutbox.any((p) => p.id == transferId), isTrue);
    },
  );

  test('a message arriving during failed contact deletion is processed after rollback', () async {
    final store = PausingStore();
    final f = await Fixture.create(memoryStore: store);
    addTearDown(f.app.dispose);
    final packet = await f.incoming('during-delete', 'à conserver');
    final release = Completer<void>();
    store.failAfterRelease = release;
    store.writeStarted = Completer<void>();
    final deletion = expectLater(
      f.app.deleteContact(f.chatId),
      throwsStateError,
    );
    await store.writeStarted!.future;
    final delivery = f.relay.onInbound!(packet);
    release.complete();
    await deletion;
    await delivery;
    expect(f.app.conversations, hasLength(1));
    expect(f.store.savedMessages.single.plaintext, 'à conserver');
  });

  test(
    'failed group deletion restores membership, key and pending messages',
    () async {
      final f = await Fixture.create();
      addTearDown(f.app.dispose);
      final id = await f.app.createGroup('Équipe', [f.peerId]);
      await f.app.sendGroupMessage(id, 'à conserver');
      final key = await f.app.groupKey(id)!.extractBytes();
      final message = f.app.messagesByConv[id]!.single;
      f.store.failWrites = true;
      await expectLater(f.app.deleteGroup(id), throwsStateError);
      expect(f.app.groups.single.id, id);
      expect(await f.app.groupKey(id)!.extractBytes(), key);
      expect(f.app.messagesByConv[id]!.single.id, message.id);
      f.store.failWrites = false;
      await f.app.sendGroupMessage(id, 'après reprise');
      expect(
        f.store.savedMessages.where((m) => m.conversationId == id),
        hasLength(2),
      );
    },
  );

  test(
    'personal names and icons survive a reload and a refreshed contact name',
    () async {
      final f = await Fixture.create();
      addTearDown(f.app.dispose);
      await f.app.setChatAppearance(f.chatId, name: 'Mon collègue', icon: '🎓');
      await f.app.sendMessage(f.chatId, 'bonjour');
      await f.app.unlock('1234');
      expect(f.app.conversations.single.displayName, 'Mon collègue');
      expect(f.app.chatIcon(f.chatId), '🎓');
      await f.relay.onInbound!({
        'type': 'peer_matched',
        'peerId': f.peerId,
        'peerName': 'Robert',
        'peerPublicKey': base64Encode(f.peer.publicKey),
      });
      expect(f.app.conversations.single.peerName, 'Robert');
      expect(f.app.chatName(f.chatId), 'Mon collègue');
      expect(f.app.peerNameOf(f.peerId), 'Mon collègue');
    },
  );

  test(
    'deletion cancels a local pending message without deleting the contact',
    () async {
      final f = await Fixture.create();
      addTearDown(f.app.dispose);
      await f.app.sendMessage(f.chatId, 'à annuler');
      final id = f.app.messagesByConv[f.chatId]!.single.id;
      expect(f.store.savedOutbox.any((packet) => packet.id == id), isTrue);
      await f.app.deleteMessage(f.chatId, id);
      expect(f.app.messagesByConv[f.chatId], isEmpty);
      expect(f.store.savedOutbox.any((packet) => packet.id == id), isFalse);
      expect(f.app.conversations, hasLength(1));
    },
  );

  test(
    'deleted received messages do not reappear after replay and vault reload',
    () async {
      final f = await Fixture.create();
      addTearDown(f.app.dispose);
      final packet = await f.incoming('message-replayed', 'secret');
      await f.relay.onInbound!(packet);
      await f.app.deleteMessage(f.chatId, 'message-replayed');
      await f.app.unlock('1234');
      await f.relay.onInbound!(packet);
      expect(f.app.messagesByConv[f.chatId] ?? [], isEmpty);
      expect(
        f.app.conversations.single.localSettings.deletedMessageIds,
        contains('message-replayed'),
      );
    },
  );

  test('deleting a conversation hides its history but preserves contact and new delivery', () async {
    final f = await Fixture.create();
    addTearDown(f.app.dispose);
    final old = await f.incoming('old', 'ancien message');
    await f.relay.onInbound!(old);
    await f.app.deleteConversation(f.chatId);
    expect(f.app.visibleConversations, isEmpty);
    expect(f.app.conversations, hasLength(1));
    await f.app.unlock('1234');
    await f.relay.onInbound!(old);
    expect(f.app.visibleConversations, isEmpty);
    await f.relay.onInbound!(await f.incoming('new', 'nouveau message'));
    expect(f.app.visibleConversations, hasLength(1));
    expect(f.app.messagesByConv[f.chatId]!.single.plaintext, 'nouveau message');
  });

  test('contact removal keeps common groups and group keys', () async {
    final f = await Fixture.create();
    addTearDown(f.app.dispose);
    final groupId = await f.app.createGroup('Équipe', [f.peerId]);
    await f.app.sendMessage(f.chatId, 'direct');
    await f.app.deleteContact(f.chatId);
    expect(f.app.conversations, isEmpty);
    expect(f.app.groups.single.id, groupId);
    expect(f.app.groups.single.memberIds, contains(f.peerId));
    expect(f.app.groupKey(groupId), isNotNull);
    expect(f.store.savedConversations, isEmpty);
    // No filesystem operation is involved in deleting a message/contact.
  });

  test(
    'local personalization and deletions roll back if saving fails',
    () async {
      final f = await Fixture.create();
      addTearDown(f.app.dispose);
      await f.app.sendMessage(f.chatId, 'à conserver');
      final id = f.app.messagesByConv[f.chatId]!.single.id;
      f.store.failWrites = true;
      await expectLater(
        f.app.setChatAppearance(f.chatId, name: 'Alias', icon: '⭐'),
        throwsStateError,
      );
      expect(f.app.chatName(f.chatId), 'Bob');
      await expectLater(f.app.deleteMessage(f.chatId, id), throwsStateError);
      expect(f.app.messagesByConv[f.chatId]!.single.id, id);
      await expectLater(f.app.deleteConversation(f.chatId), throwsStateError);
      expect(f.app.visibleConversations, hasLength(1));
      expect(f.app.messagesByConv[f.chatId]!.single.id, id);
      await expectLater(f.app.deleteContact(f.chatId), throwsStateError);
      expect(f.app.conversations, hasLength(1));
      expect(f.app.messagesByConv[f.chatId]!.single.id, id);
      f.store.failWrites = false;
      await f.app.sendMessage(f.chatId, 'toujours fonctionnel');
      expect(f.store.savedMessages, hasLength(2));
    },
  );

  test(
    'group personalization is preserved through control updates and JSON',
    () async {
      final group = Group(
        id: 'g',
        name: 'Équipe',
        memberIds: ['alice', 'bob'],
        createdBy: 'alice',
        adminIds: ['alice'],
        joinedMemberIds: ['alice'],
        createdAt: DateTime(2026),
      );
      group.localSettings.alias = 'Mon équipe';
      group.localSettings.icon = '💼';
      final updated = group.applyControl(
        GroupControl(
          kind: 'join',
          groupId: 'g',
          memberIds: group.memberIds,
          adminIds: group.adminIds,
          epoch: 1,
          memberId: 'bob',
        ),
        senderId: 'bob',
      )!;
      final restored = Group.fromJson(
        jsonDecode(jsonEncode(updated.toJson())) as Map<String, dynamic>,
      );
      expect(restored.displayName, 'Mon équipe');
      expect(restored.localSettings.icon, '💼');
      expect(restored.name, 'Équipe');
    },
  );

  test('leaving a group cancels pending texts and transfers ownership to a remaining member', () async {
    final aliceStore = MemoryStore(), bobStore = MemoryStore();
    final aliceRelay = MemoryRelay('alice', 'Alice'),
        bobRelay = MemoryRelay('bob', 'Bob');
    final alice = AppState(store: aliceStore, relay: aliceRelay);
    final bob = AppState(store: bobStore, relay: bobRelay);
    addTearDown(alice.dispose);
    addTearDown(bob.dispose);
    await alice.init(pin: '123456');
    await bob.init(pin: '123456');
    final id = await alice.createGroup('Amis', ['bob']);
    await bob.acceptInvite(
      GroupInvite(
        groupId: id,
        name: 'Amis',
        groupKeyB64: base64Encode(await alice.groupKey(id)!.extractBytes()),
        memberIds: ['alice', 'bob'],
        adminIds: ['alice'],
        ownerId: 'alice',
        joinedMemberIds: ['alice'],
        fromId: 'alice',
        fromName: 'Alice',
      ),
    );
    await aliceRelay.onInbound!(bobRelay.outgoing.single);
    await alice.sendGroupMessage(id, 'en attente');
    final oldMessage = alice.messagesByConv[id]!.last.id;
    await alice.deleteGroup(id);
    expect(alice.groups, isEmpty);
    expect(alice.groupKey(id), isNull);
    expect(
      aliceStore.savedOutbox.any((packet) => packet.id == oldMessage),
      isFalse,
    );
    await bobRelay.onInbound!(aliceRelay.outgoing.last);
    expect(bob.groups.single.ownerId, 'bob');
    expect(bob.groups.single.memberIds, ['bob']);
  });
}
