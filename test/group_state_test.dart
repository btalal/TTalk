import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttalk/crypto/e2e_crypto.dart';
import 'package:ttalk/models/group.dart';
import 'package:ttalk/state/app_state.dart';

import 'support/group_fakes.dart';

void main() {
  test('pending invitation follows membership and ownership changes before acceptance', () async {
    final aliceRelay = MemoryRelay('alice', 'Alice');
    final bobRelay = MemoryRelay('bob', 'Bob');
    final carolRelay = MemoryRelay('carol', 'Carole');
    final alice = AppState(store: MemoryStore(), relay: aliceRelay);
    final bob = AppState(store: MemoryStore(), relay: bobRelay);
    final carol = AppState(store: MemoryStore(), relay: carolRelay);
    for (final app in [alice, bob, carol]) {
      await app.init(pin: '123456');
    }
    final id = await alice.createGroup('Amis', ['bob', 'carol']);
    final key = base64Encode(await alice.groupKey(id)!.extractBytes());
    final invite = GroupInvite(
      groupId: id,
      name: 'Amis',
      groupKeyB64: key,
      memberIds: ['alice', 'bob', 'carol'],
      adminIds: ['alice'],
      ownerId: 'alice',
      joinedMemberIds: ['alice'],
      fromId: 'alice',
      fromName: 'Alice',
    );
    // Carole receives the invitation over her existing encrypted contact session.
    await carolRelay.onInbound!({
      'type': 'peer_matched',
      'peerId': 'alice',
      'peerName': 'Alice',
      'peerPublicKey': base64Encode(alice.identity!.publicKey),
    });
    final session = await carol.identity!.deriveSessionKey(
      alice.identity!.publicKey,
    );
    final payload = await transportPacket(
      session,
      invite.toJsonString(),
      'alice',
      'invite',
      kind: 'invite',
    );
    await carolRelay.onInbound!({
      'type': 'group_invite',
      'messageId': 'invite',
      'from': 'alice',
      'fromName': 'Alice',
      'payload': base64Encode(payload),
    });
    final staleInvitation = carol.pendingInvites.single;
    await bob.acceptInvite(invite);
    await aliceRelay.onInbound!(bobRelay.outgoing.single);
    await carolRelay.onInbound!(bobRelay.outgoing.single);
    await bobRelay.onInbound!(aliceRelay.outgoing.single);
    expect(carol.groups, isEmpty);
    expect(carol.pendingInvites.single.joinedMemberIds, contains('bob'));
    await alice.transferGroupOwnership(id, 'bob');
    await bobRelay.onInbound!(aliceRelay.outgoing.last);
    await carolRelay.onInbound!(aliceRelay.outgoing.last);
    expect(carol.pendingInvites.single.ownerId, 'bob');
    await carol.acceptInvite(staleInvitation);
    expect(carol.groups.single.ownerId, 'bob');
    expect(
      carol.messagesByConv[id]!.single.plaintext,
      'Carole a rejoint le groupe.',
    );
    await bobRelay.onInbound!(carolRelay.outgoing.single);
    expect(
      bob.messagesByConv[id]!.last.plaintext,
      'Carole a rejoint le groupe.',
    );
    for (final app in [alice, bob, carol]) {
      app.dispose();
    }
  });

  test('accepted invitation notifies both clients; encrypted ownership transfer persists', () async {
    final aliceRelay = MemoryRelay('alice', 'Alice');
    final bobRelay = MemoryRelay('bob', 'Bob');
    final aliceStore = MemoryStore(), bobStore = MemoryStore();
    final alice = AppState(store: aliceStore, relay: aliceRelay);
    final bob = AppState(store: bobStore, relay: bobRelay);
    await alice.init(pin: '123456');
    await bob.init(pin: '123456');
    final id = await alice.createGroup('Amis', ['bob']);
    final key = alice.groupKey(id)!;
    final invite = GroupInvite(
      groupId: id,
      name: 'Amis',
      groupKeyB64: base64Encode(await key.extractBytes()),
      memberIds: ['alice', 'bob'],
      adminIds: ['alice'],
      ownerId: 'alice',
      joinedMemberIds: ['alice'],
      fromId: 'alice',
      fromName: 'Alice',
    );
    expect(alice.messagesByConv[id], isNull);
    await bob.acceptInvite(invite);
    expect(bobRelay.outgoing, hasLength(1));
    final join = bobRelay.outgoing.single;
    expect(join['to'], ['alice']);
    final clear = await decryptMessage(
      key,
      Uint8List.fromList(base64Decode(join['payload'] as String)),
    );
    expect(jsonDecode(jsonDecode(clear)['body'] as String)['kind'], 'control');
    expect(clear, contains('join'));
    await aliceRelay.onInbound!(join);
    expect(
      alice.messagesByConv[id]!.single.plaintext,
      'Bob a rejoint le groupe.',
    );
    expect(
      bob.messagesByConv[id]!.single.plaintext,
      'Bob a rejoint le groupe.',
    );
    await aliceRelay.onInbound!(join);
    await bob.acceptInvite(invite);
    expect(alice.messagesByConv[id], hasLength(1));
    expect(bobRelay.outgoing, hasLength(1));

    await bobRelay.onInbound!(aliceRelay.outgoing.single);
    aliceRelay.outgoing.clear();
    await alice.transferGroupOwnership(id, 'bob');
    await bobRelay.onInbound!(aliceRelay.outgoing.last);
    for (final store in [aliceStore, bobStore]) {
      expect(store.savedGroups.single.ownerId, 'bob');
      expect(store.savedGroups.single.isAdmin('alice'), isFalse);
      expect(store.savedGroups.single.isAdmin('bob'), isTrue);
      expect(store.savedMessages.last.isSystem, isTrue);
    }
    await expectLater(
      alice.transferGroupOwnership(id, 'bob'),
      throwsStateError,
    );
    expect(aliceRelay.outgoing, hasLength(1));
    alice.dispose();
    bob.dispose();
  });
}
