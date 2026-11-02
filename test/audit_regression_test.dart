import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttalk/crypto/e2e_crypto.dart';
import 'package:ttalk/main.dart';
import 'package:ttalk/models/message.dart';
import 'package:ttalk/services/relay_client.dart';
import 'package:ttalk/services/secure_store.dart';
import 'package:ttalk/state/app_state.dart';

import 'support/group_fakes.dart';

class OfflineRelay extends RelayClient {
  @override
  Future<void> connect(String url) async =>
      throw const SocketException('offline');
}

class RecordingRelay extends RelayClient {
  final names = <String>[];
  @override
  RelayState get state => RelayState.connected;
  @override
  Future<void> connect(String url) async {}
  @override
  void register({required String name, required Uint8List publicKey}) {
    names.add(name);
    displayName = name;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'unlock window remains accessible when the relay cannot connect',
    (tester) async {
      final app = AppState(store: MemoryStore(), relay: OfflineRelay());
      await app.init();
      await tester.pumpWidget(TTalkApp(app: app));
      await app.connectRelay('ws://localhost:1');
      await tester.pump();
      expect(find.text('Créer un code PIN'), findsOneWidget);
      expect(app.error, contains('indisponible'));
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    },
  );

  test(
    'registration waits for vault unlock and uses the saved profile',
    () async {
      SharedPreferences.setMockInitialValues({'display_name': 'Alice'});
      FlutterSecureStorage.setMockInitialValues({});
      final store = await SecureStore.create();
      final relay = RecordingRelay();
      final app = AppState(store: store, relay: relay);
      await app.init();
      await app.connectRelay('ws://localhost:8080');
      expect(relay.names, isEmpty);
      await app.createPin('1234');
      expect(relay.names, ['Alice']);
      await app.setDisplayName('Alice mise à jour');
      expect(relay.names.last, 'Alice mise à jour');
      expect(store.displayName, 'Alice mise à jour');
      app.dispose();
    },
  );

  test('profile, identity and queued vault writes survive reload; bad PIN locks the key', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final store = await SecureStore.create();
    final identity = await store.loadOrCreateIdentity();
    await store.saveIdentity(identity);
    await store.setDisplayName('Alice');
    await store.setupPin('1234');
    ChatMessage message(String id) => ChatMessage(
      id: id,
      conversationId: 'c',
      fromMe: true,
      ciphertext: [],
      timestamp: DateTime(2026),
      plaintext: id,
    );
    await Future.wait([
      store.saveData(conversations: [], messages: [message('first')]),
      store.saveData(conversations: [], messages: [message('last')]),
    ]);
    final restored = await SecureStore.create();
    expect(restored.displayName, 'Alice');
    expect((await restored.loadIdentity())!.publicKey, identity.publicKey);
    expect(await restored.unlockWithPin('1234'), isTrue);
    expect((await restored.loadData()).messages.single.id, 'last');
    expect(await restored.unlockWithPin('9999'), isFalse);
    expect(restored.isUnlocked, isFalse);
  });

  test('arrival does not mark a message read, duplicate frames do not duplicate history', () async {
    final alice = await IdentityKeys.generate();
    final relay = MemoryRelay('bob', 'Bob');
    final bob = AppState(store: MemoryStore(), relay: relay);
    await bob.init();
    await relay.onInbound!({
      'type': 'peer_matched',
      'peerId': 'alice',
      'peerName': 'Alice',
      'peerPublicKey': base64Encode(alice.publicKey),
    });
    final key = await alice.deriveSessionKey(bob.identity!.publicKey);
    final frame = {
      'type': 'cipher',
      'from': 'alice',
      'messageId': 'm1',
      'payload': base64Encode(
        await transportPacket(key, 'Bonjour', 'alice', 'm1'),
      ),
    };
    await relay.onInbound!(frame);
    await relay.onInbound!(frame);
    final chat = bob.conversations.single.id;
    expect(bob.messagesByConv[chat], hasLength(1));
    expect(bob.messagesByConv[chat]!.single.read, isFalse);
    expect(
      jsonDecode(await transportBody(key, relay.outgoing.single))['type'],
      'delivered',
    );
    await bob.markConversationRead(chat);
    expect(
      jsonDecode(await transportBody(key, relay.outgoing.last))['type'],
      'read',
    );
    expect(bob.messagesByConv[chat]!.single.read, isTrue);
    bob.dispose();
  });

  test('group read receipts update only sent messages in that group', () async {
    final relay = MemoryRelay('alice', 'Alice');
    final app = AppState(store: MemoryStore(), relay: relay);
    await app.init();
    final id = await app.createGroup('Amis', ['bob']);
    final message = ChatMessage(
      id: 'm',
      conversationId: id,
      fromMe: true,
      ciphertext: [],
      timestamp: DateTime(2026),
      isGroup: true,
    );
    app.messagesByConv[id] = [message];
    final key = app.groupKey(id)!;
    Future<void> receipt(String type, String from, String packetId) async {
      final payload = await transportPacket(
        key,
        jsonEncode({'kind': 'receipt', 'type': type, 'messageId': 'm'}),
        from,
        packetId,
        groupId: id,
        kind: 'receipt',
      );
      await relay.onInbound!({
        'type': 'cipher',
        'from': from,
        'messageId': packetId,
        'groupId': id,
        'payload': base64Encode(payload),
      });
    }

    await receipt('delivered', 'bob', 'receipt-1');
    expect(message.delivered, isTrue);
    expect(message.read, isFalse);
    await receipt('read', 'outsider', 'receipt-2');
    expect(message.read, isFalse);
    await receipt('read', 'bob', 'receipt-3');
    expect(message.read, isTrue);
    expect(message.readBy, ['bob']);
    app.dispose();
  });

  test('attachments with identical names use different paths without extra vault writes', () async {
    final directory = await Directory.systemTemp.createTemp('ttalk-files-');
    final store = MemoryStore();
    final app = AppState(
      store: store,
      relay: MemoryRelay('alice', 'Alice'),
      documentsDirectory: () async => directory,
    );
    try {
      final key = SecretKey(await generateFileKey());
      final bytes = Uint8List.fromList([1, 2, 3]);
      final metadata = {
        'fileKey': base64Encode(await key.extractBytes()),
        'data': base64Encode(await encryptFile(key, bytes)),
        'fileName': '../same.txt',
      };
      ChatMessage file(String id) => ChatMessage(
        id: id,
        conversationId: 'c',
        fromMe: false,
        ciphertext: [],
        timestamp: DateTime(2026),
        kind: 'file',
      );
      final first = file('first'), second = file('second');
      await app.handleInboundFile(first, metadata);
      await app.handleInboundFile(second, metadata);
      expect(first.filePath, isNot(second.filePath));
      expect(await File(first.filePath!).readAsBytes(), bytes);
      expect(await File(second.filePath!).readAsBytes(), bytes);
      expect(store.savedMessages, isEmpty);
    } finally {
      await directory.delete(recursive: true);
      app.dispose();
    }
  });

  test(
    'all encrypted packet types reject truncation and modified nonce prefixes',
    () async {
      final key = SecretKey(await generateFileKey());
      final packet = await encryptMessage(key, 'secret');
      final modified = Uint8List.fromList(packet)..[0] ^= 1;
      for (final payload in [Uint8List(3), modified]) {
        await expectLater(decryptMessage(key, payload), throwsFormatException);
        await expectLater(decryptLocal(key, payload), throwsFormatException);
        await expectLater(decryptFile(key, payload), throwsFormatException);
      }
    },
  );
  test(
    'JSON-looking user text remains text instead of becoming a file or command',
    () async {
      final peer = await IdentityKeys.generate();
      final relay = MemoryRelay('bob', 'Bob');
      final app = AppState(store: MemoryStore(), relay: relay);
      await app.init();
      await relay.onInbound!({
        'type': 'peer_matched',
        'peerId': 'alice',
        'peerName': 'Alice',
        'peerPublicKey': base64Encode(peer.publicKey),
      });
      final key = await peer.deriveSessionKey(app.identity!.publicKey);
      const text = '{"kind":"file","fileName":"example.txt"}';
      final payload = await transportPacket(key, text, 'alice', 'json-text');
      await relay.onInbound!({
        'type': 'cipher',
        'from': 'alice',
        'messageId': 'json-text',
        'payload': base64Encode(payload),
      });
      final message = app.messagesByConv.values.single.single;
      expect(message.plaintext, text);
      expect(message.isFile, isFalse);
      app.dispose();
    },
  );
}
