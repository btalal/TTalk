import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ttalk/crypto/e2e_crypto.dart';
import 'package:ttalk/main.dart';
import 'package:ttalk/services/relay_client.dart';
import 'package:ttalk/services/secure_store.dart';
import 'package:ttalk/state/app_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Linux keyring preserves identity, PIN gate and native navigation',
    (tester) async {
      final store = await SecureStore.create();
      final identity = await IdentityKeys.generate();
      await store.saveIdentity(identity);
      await store.setupPin('839104');
      await store.setDisplayName('Linux CI fictif');
      store.lock();
      final reopened = await SecureStore.create();
      expect((await reopened.loadIdentity())!.stableId, identity.stableId);
      expect(await reopened.unlockWithPin('000000'), isFalse);
      expect(await reopened.unlockWithPin('839104'), isTrue);
      expect(reopened.displayName, 'Linux CI fictif');
      final app = AppState(store: reopened, relay: RelayClient());
      addTearDown(app.dispose);
      await app.init();
      await app.unlock('839104');
      await tester.pumpWidget(TTalkApp(app: app));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Discussions'), findsWidgets);
      expect(find.text('Contacts'), findsWidgets);
      expect(find.text('Réglages'), findsWidgets);
      expect(tester.takeException(), isNull);
      await app.lockVault();
      expect(reopened.isUnlocked, isFalse);
    },
    skip: !Platform.isLinux,
  );
}
