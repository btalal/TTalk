import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttalk/crypto/e2e_crypto.dart';
import 'package:ttalk/models/group.dart';
import 'package:ttalk/models/message.dart';
import 'package:ttalk/services/relay_client.dart';
import 'package:ttalk/services/secure_store.dart';
import 'package:ttalk/state/app_state.dart';
import 'package:ttalk/ui/home_screen.dart';

import 'support/group_fakes.dart';

class RejectingPreferences implements SharedPreferences {
  RejectingPreferences(this.delegate);
  final SharedPreferences delegate;
  bool reject = false;
  @override
  String? getString(String key) => delegate.getString(key);
  @override
  bool containsKey(String key) => delegate.containsKey(key);
  @override
  Future<bool> setString(String key, String value) async =>
      reject ? false : delegate.setString(key, value);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'server addresses normalize HTTPS and reject plaintext remote transport',
    () {
      expect(
        RelayClient.normalizeUrl(' https://relay.example.com '),
        'wss://relay.example.com/ws',
      );
      expect(
        RelayClient.normalizeUrl('http://localhost:8080'),
        'ws://localhost:8080/ws',
      );
      expect(
        RelayClient.normalizeUrl('wss://relay.example.com/custom'),
        'wss://relay.example.com/custom',
      );
      for (final url in [
        'ws://relay.example.com',
        'http://relay.example.com',
        'https://user:password@example.com',
        'not-a-url',
        'https://example.com/?token=secret',
      ]) {
        expect(() => RelayClient.normalizeUrl(url), throwsFormatException);
      }
    },
  );
  testWidgets(
    'server can be configured in the Windows interface without recompiling',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore();
      final app = AppState(store: store, relay: MemoryRelay('alice', 'Alice'));
      await app.init();
      await tester.pumpWidget(MaterialApp(home: HomeScreen(app: app)));
      expect(
        find.text('Configure le serveur pour communiquer entre tes appareils.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Configurer le serveur'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'http://relay.example.com',
      );
      await tester.tap(find.text('Enregistrer et connecter'));
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTPS/WSS'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'https://relay.example.com',
      );
      await tester.tap(find.text('Enregistrer et connecter'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.relayUrl, 'wss://relay.example.com/ws');
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    },
  );
  test(
    'legacy contact IDs migrate by key and group history remains available',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final store = await SecureStore.create();
      final peer = await IdentityKeys.generate();
      final identity = await store.loadOrCreateIdentity();
      await store.saveIdentity(identity);
      await store.setupPin('1234');
      await store.saveData(
        conversations: [
          Conversation(
            id: 'chat',
            peerId: 'old-session',
            peerName: 'Bob',
            peerPublicKey: peer.publicKey,
            createdAt: DateTime(2026),
          ),
        ],
        messages: [
          ChatMessage(
            id: 'history',
            conversationId: 'legacy-group',
            fromMe: false,
            ciphertext: [],
            timestamp: DateTime(2026),
            plaintext: 'historique',
            isGroup: true,
          ),
        ],
        groups: [
          Group(
            id: 'legacy-group',
            name: 'Ancien',
            memberIds: ['old-session', 'old-self'],
            createdBy: 'old-self',
            createdAt: DateTime(2026),
            adminIds: ['old-self'],
          ),
        ],
      );
      final app = AppState(store: store, relay: MemoryRelay('alice', 'Alice'));
      await app.init(pin: '1234');
      expect(app.conversations.single.peerId, peer.stableId);
      expect(app.groups.single.requiresRecreation, isTrue);
      expect(
        app.messagesByConv['legacy-group']!.single.plaintext,
        'historique',
      );
      await expectLater(
        app.sendGroupMessage('legacy-group', 'test'),
        throwsStateError,
      );
      expect(app.identity!.publicKey, Uint8List.fromList(identity.publicKey));
      app.dispose();
    },
  );
  test(
    'a false storage result is a failure and the next write can recover',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = RejectingPreferences(
        await SharedPreferences.getInstance(),
      );
      final store = await SecureStore.create(preferences: preferences);
      await store.setupPin('1234');
      preferences.reject = true;
      await expectLater(
        store.saveData(conversations: [], messages: []),
        throwsStateError,
      );
      preferences.reject = false;
      await store.saveData(conversations: [], messages: []);
      expect((await store.loadData()).messages, isEmpty);
    },
  );
}
