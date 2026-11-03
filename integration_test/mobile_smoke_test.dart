import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'dart:typed_data';

import 'package:ttalk/models/outbound_packet.dart';
import 'package:ttalk/main.dart';
import 'package:ttalk/services/relay_client.dart';
import 'package:ttalk/services/secure_store.dart';
import 'package:ttalk/state/app_state.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // XCTest enables native accessibility asynchronously. Prime the platform
  // handle before testWidgets records its baseline, and restore it afterward.
  setUpAll(() => binding.platformDispatcher.semanticsEnabledTestValue = true);
  tearDownAll(binding.platformDispatcher.clearSemanticsEnabledTestValue);

  testWidgets(
    'native identity survives reload; PIN, offline outbox and mobile menu',
    (tester) async {
      final store = await SecureStore.create();
      final app = AppState(store: store, relay: RelayClient());
      addTearDown(app.dispose);
      await app.init();
      final id = app.identity!.stableId;
      final reopened = await SecureStore.create();
      expect((await reopened.loadIdentity())!.stableId, id);
      const pin = '893017';
      await tester.pumpWidget(TTalkApp(app: app));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), pin);
      final submit = find.widgetWithText(
        FilledButton,
        store.hasPin ? 'Déverrouiller' : 'Créer',
      );
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      // Real PBKDF2 runs on-device; allow the asynchronous key derivation to finish.
      for (var i = 0; i < 120 && !app.unlocked; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(app.unlocked, isTrue);
      await tester.tap(find.byTooltip('Menu TTalk'));
      await tester.pumpAndSettle();
      expect(find.text('Appairer un contact'), findsOneWidget);
      await tester.tap(find.text('Mon nom'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      await store.saveData(
        conversations: [],
        messages: [],
        outbox: [
          OutboundPacket(
            id: 'mobile-offline',
            type: 'cipher',
            recipients: [id],
            payload: Uint8List.fromList([12, 24, 48]),
          ),
        ],
      );
      final restored = await SecureStore.create();
      expect(await restored.unlockWithPin('0000'), isFalse);
      expect(await restored.unlockWithPin(pin), isTrue);
      expect((await restored.loadData()).outbox.single.id, 'mobile-offline');
      expect((await store.loadIdentity())!.stableId, id);
      await store.setRelayUrl('wss://example.invalid/ws');
      expect((await SecureStore.create()).relayUrl, 'wss://example.invalid/ws');
      await store.setRelayUrl('');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
