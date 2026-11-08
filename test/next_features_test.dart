import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';
import 'package:ttalk/crypto/e2e_crypto.dart';
import 'package:ttalk/models/message.dart';
import 'package:ttalk/models/group.dart';
import 'package:ttalk/services/backup_codec.dart';
import 'package:ttalk/services/pairing_invitation.dart';
import 'package:ttalk/services/secure_store.dart';
import 'package:ttalk/state/app_state.dart';

import 'support/group_fakes.dart';

Future<AppState> client(String id) async {
  final app = AppState(store: MemoryStore(), relay: MemoryRelay(id, id));
  await app.init(pin: '123456');
  return app;
}

Future<void> pair(AppState a, AppState b) async {
  for (final peers in [(a, b), (b, a)]) {
    await peers.$1.relay.onInbound!({
      'type': 'peer_matched',
      'peerId': peers.$2.myId,
      'peerName': peers.$2.myName,
      'peerPublicKey': base64Encode(peers.$2.identity!.publicKey),
    });
  }
}

Future<void> deliverLast(AppState from, AppState to) async {
  final packet = (from.relay as MemoryRelay).outgoing.last;
  await to.relay.onInbound!(packet);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'session derivation rejects malformed and low-order public keys',
    () async {
      final identity = await IdentityKeys.generate();
      await expectLater(
        identity.deriveSessionKey(Uint8List(31)),
        throwsFormatException,
      );
      await expectLater(
        identity.deriveSessionKey(Uint8List(32)),
        throwsA(isA<Exception>()),
      );
      final lowOrder = Uint8List(32)..[0] = 1;
      await expectLater(
        identity.deriveSessionKey(lowOrder),
        throwsA(isA<Exception>()),
      );
    },
  );
  test('invitation roundtrip binds relay and identity; malformed and duplicate inputs rejected', () {
    final peer = 'a' * 64;
    final invite = PairingInvitation(
      code: 'ABC234',
      relay: 'https://relais.example.invalid',
      peerId: peer,
    );
    final parsed = PairingInvitation.parse(invite.link);
    expect(parsed.code, 'ABC234');
    expect(parsed.peerId, peer);
    expect(parsed.relay, 'wss://relais.example.invalid/ws');
    expect(PairingInvitation.parse('abc234').code, 'ABC234');
    for (final value in [
      '${invite.link}&code=DEF567',
      'https://attacker.test/?code=ABC234',
      'ttalk://pair?v=1&code=ABC234&relay=http%3A%2F%2Fevil.test',
      'x' * 2050,
    ]) {
      expect(() => PairingInvitation.parse(value), throwsFormatException);
    }
  });
  test(
    'search, pin and archive persist without deleting messages or contacts',
    () async {
      final a = await client('alice'), b = await client('bob');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await pair(a, b);
      final id = a.conversations.single.id;
      await a.sendMessage(id, 'Rendez-vous jardin');
      expect(a.matchesSearch(id, 'JARDIN'), isTrue);
      expect(a.matchesSearch(id, 'inconnu'), isFalse);
      await a.setChatFlag(id, pinned: true, archived: true);
      final stored = (a.store as MemoryStore).savedConversations.single;
      expect(stored.localSettings.pinned, isTrue);
      expect(stored.localSettings.archived, isTrue);
      expect(
        (a.store as MemoryStore).savedMessages.single.plaintext,
        'Rendez-vous jardin',
      );
      (a.store as MemoryStore).failWrites = true;
      await expectLater(a.setChatFlag(id, pinned: false), throwsStateError);
      expect(a.settingsFor(id).pinned, isTrue);
    },
  );
  test('quoted replies preserve legacy text and negotiated reactions are authenticated and idempotent', () async {
    final a = await client('alice'), b = await client('bob');
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await pair(a, b);
    final aid = a.conversations.single.id, bid = b.conversations.single.id;
    expect(a.canReact(aid), isFalse);
    await a.sendMessage(aid, 'Bonjour');
    await deliverLast(a, b);
    final original = b.messagesByConv[bid]!.single;
    await b.sendMessage(bid, 'Salut', replyTo: original);
    await deliverLast(b, a);
    expect(a.messagesByConv[aid]!.last.plaintext, 'Salut');
    expect(
      a.messagesByConv[aid]!.last.replyToId,
      a.messagesByConv[aid]!.first.id,
    );
    expect(a.messagesByConv[aid]!.last.replyPreview, 'Bonjour');
    expect(a.canReact(aid), isTrue);
    await a.react(aid, original.id, '👍');
    final reaction = (a.relay as MemoryRelay).outgoing.last;
    await b.relay.onInbound!(reaction);
    await b.relay.onInbound!(reaction);
    expect(original.reactions, {'alice': '👍'});
    expect(original.reactionVersions['alice'], 1);
    await a.react(aid, original.id, '👍');
    await deliverLast(a, b);
    expect(original.reactions, isEmpty);
    expect(original.reactionVersions['alice'], 2);
    await b.relay.onInbound!(reaction);
    expect(original.reactions, isEmpty);
  });
  test('group rotation sends new key only in recipient-specific ciphertext and fails closed for older clients', () async {
    final a = await client('alice'),
        b = await client('bob'),
        c = await client('carol');
    for (final app in [a, b, c]) {
      addTearDown(app.dispose);
    }
    await pair(a, b);
    await pair(a, c);
    final id = await a.createGroup('Amis', ['bob', 'carol']);
    final oldKey = a.groupKey(id)!;
    final before = base64Encode(await oldKey.extractBytes());
    await expectLater(a.removeMember(id, 'carol'), throwsStateError);
    expect(base64Encode(await a.groupKey(id)!.extractBytes()), before);
    await b.sendMessage(b.conversations.single.id, 'Version compatible');
    await deliverLast(b, a);
    (a.store as MemoryStore).failWrites = true;
    final pending = a.pendingCount;
    await expectLater(a.removeMember(id, 'carol'), throwsStateError);
    expect(a.groups.single.memberIds, contains('carol'));
    expect(base64Encode(await a.groupKey(id)!.extractBytes()), before);
    expect(a.pendingCount, pending);
    (a.store as MemoryStore).failWrites = false;
    final count = (a.relay as MemoryRelay).outgoing.length;
    await a.removeMember(id, 'carol');
    final packets = (a.relay as MemoryRelay).outgoing.skip(count).toList();
    expect(packets, hasLength(1));
    expect(packets.single['to'], ['bob']);
    expect(packets.single['groupId'], isNull);
    final bytes = Uint8List.fromList(
      base64Decode(packets.single['payload'] as String),
    );
    await expectLater(
      decryptMessage(oldKey, bytes),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    final key = await b.identity!.deriveSessionKey(a.identity!.publicKey);
    final envelope = jsonDecode(await decryptMessage(key, bytes)) as Map;
    final control = jsonDecode(
      (jsonDecode(envelope['body'] as String) as Map)['data'] as String,
    ) as Map;
    expect(control['kind'], 'remove');
    expect(control['removedId'], 'carol');
    expect(
      control['newGroupKeyB64'],
      base64Encode(await a.groupKey(id)!.extractBytes()),
    );
    expect(control['newGroupKeyB64'], isNot(before));
    final carolKey = await c.identity!.deriveSessionKey(a.identity!.publicKey);
    await expectLater(
      decryptMessage(carolKey, bytes),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
  test('old shared-key remove controls cannot rotate a group key in the upgraded client', () async {
    final a = await client('alice');
    addTearDown(a.dispose);
    final id = await a.createGroup('Amis', ['bob']);
    final key = a.groupKey(id)!;
    final ctrl = GroupControl(
      kind: 'remove',
      groupId: id,
      memberIds: ['alice'],
      adminIds: ['alice'],
      epoch: 2,
      removedId: 'bob',
      newGroupKeyB64: base64Encode(randomBytes(32)),
    );
    final packet = await transportPacket(
      key,
      jsonEncode({'kind': 'control', 'data': ctrl.toJsonString()}),
      'alice',
      'forged',
      kind: 'control',
      groupId: id,
    );
    await expectLater(
      a.relay.onInbound!({
        'type': 'cipher',
        'from': 'alice',
        'messageId': 'forged',
        'groupId': id,
        'payload': base64Encode(packet),
      }),
      throwsFormatException,
    );
    expect(a.groups.single.memberIds, contains('bob'));
  });
  test(
    'backup is independently encrypted, rejects tampering and wrong passwords',
    () async {
      const password = 'une longue phrase de passe indépendante';
      final data = {'version': 1, 'private': 'ne doit pas être visible'};
      final bytes = await BackupCodec.encode(data, password);
      expect(utf8.decode(bytes), isNot(contains('ne doit pas être visible')));
      expect(await BackupCodec.decode(bytes, password), data);
      await expectLater(
        BackupCodec.decode(bytes, 'une autre phrase suffisamment longue'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final outer = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final cipher = base64Decode(outer['ciphertext'] as String);
      cipher.last ^= 1;
      outer['ciphertext'] = base64Encode(cipher);
      await expectLater(
        BackupCodec.decode(
          Uint8List.fromList(utf8.encode(jsonEncode(outer))),
          password,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );
  test('portable recovery into empty vault restores identity and history, never paths or pending sends', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final source = await SecureStore.create();
    await source.setupPin('123456');
    final identity = await IdentityKeys.generate();
    await source.saveIdentity(identity);
    await source.saveData(
      conversations: [],
      messages: [
        ChatMessage(
          id: '1',
          conversationId: 'old',
          fromMe: true,
          ciphertext: [],
          timestamp: DateTime(2026),
          plaintext: 'Historique',
          kind: 'file',
          filePath: '/private/secret',
        ),
      ],
    );
    const password = 'sauvegarde de test avec phrase longue';
    final bytes = await source.createBackup(password);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final target = await SecureStore.create();
    await target.setupPin('654321');
    await target.restoreBackup(bytes, password);
    expect((await target.loadIdentity())!.stableId, identity.stableId);
    final saved = await target.loadData();
    expect(saved.messages.single.plaintext, 'Historique');
    expect(saved.messages.single.filePath, isNull);
    expect(saved.outbox, isEmpty);
    await expectLater(target.restoreBackup(bytes, password), throwsStateError);
    target.lock();
    expect(await target.unlockWithPin('654321'), isTrue);
    expect((await target.loadData()).messages, hasLength(1));
  });
  test('lock removes clear history and refuses new sends, even when the last write fails', () async {
    final a = await client('alice'), b = await client('bob');
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await pair(a, b);
    final id = a.conversations.single.id;
    await a.sendMessage(id, 'secret local');
    (a.store as MemoryStore).failWrites = true;
    await expectLater(a.lockVault(), throwsStateError);
    expect(a.unlocked, isFalse);
    expect(a.store.isUnlocked, isFalse);
    expect(a.messagesByConv, isEmpty);
    await expectLater(a.sendMessage(id, 'interdit'), throwsStateError);
    await a.unlock('123456');
    expect(a.unlocked, isTrue);
    expect(a.messagesByConv[id]!.single.plaintext, 'secret local');
  });
}
