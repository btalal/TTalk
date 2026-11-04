import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttalk/models/group.dart';
import 'package:ttalk/models/message.dart';
import 'package:ttalk/services/relay_client.dart';
import 'package:ttalk/services/secure_store.dart';
import 'package:ttalk/state/app_state.dart';
import 'package:ttalk/ui/chat_screen.dart';
import 'package:ttalk/ui/home_screen.dart';

import 'support/group_fakes.dart';

class PairingRelay extends MemoryRelay {
  PairingRelay() : super('alice', 'Alice');
  int generations = 0;
  final answers = <String>[];
  @override
  void answerPairing(String code) => answers.add(code);
  @override
  String? get myPairingCode => generations == 1 ? 'ABC234' : 'DEF567';
  @override
  void startPairing() => generations++;
}

class DelayedSendApp extends AppState {
  DelayedSendApp()
    : super(store: MemoryStore(), relay: MemoryRelay('alice', 'Alice'));
  final sent = <String>[];
  final completion = Completer<void>();
  @override
  Future<void> sendMessage(String conversationId, String text) {
    sent.add(text);
    return completion.future;
  }
}

class FailedGroupApp extends AppState {
  FailedGroupApp()
    : super(store: MemoryStore(), relay: MemoryRelay('alice', 'Alice'));
  @override
  Future<String> createGroup(String name, List<String> memberPeerIds) async {
    throw StateError('Échec de sauvegarde simulé');
  }
}

class FailedProfileApp extends AppState {
  FailedProfileApp()
    : super(store: MemoryStore(), relay: MemoryRelay('alice', 'Alice'));
  @override
  Future<void> setDisplayName(String name) async =>
      throw StateError('Échec de sauvegarde simulé');
}

Conversation contact() => Conversation(
  id: 'conversation',
  peerId: 'bob',
  peerName: 'Bob',
  peerPublicKey: const [],
  createdAt: DateTime(2026),
);

Future<void> closeApp(WidgetTester tester, AppState app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  app.dispose();
}

void main() {
  testWidgets('regenerated pairing code remains visible in its dialog', (
    tester,
  ) async {
    final relay = PairingRelay();
    final app = AppState(store: MemoryStore(), relay: relay);
    await app.init();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(app: app)));
    await tester.tap(find.byIcon(Icons.qr_code));
    await tester.pumpAndSettle();
    expect(find.text('ABC234'), findsOneWidget);
    await tester.tap(find.text('Nouveau code'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('DEF567'), findsOneWidget);
    expect(relay.generations, 2);
    await closeApp(tester, app);
  });

  testWidgets('legacy group never exposes a direct-contact safety action', (
    tester,
  ) async {
    final app = AppState(
      store: MemoryStore(),
      relay: MemoryRelay('alice', 'Alice'),
    );
    final group = Group(
      id: 'legacy',
      name: 'Ancien groupe',
      memberIds: ['alice', 'bob'],
      createdBy: 'alice',
      createdAt: DateTime(2026),
      requiresRecreation: true,
    );
    app.groups.add(group);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(app: app, group: group),
      ),
    );
    expect(find.byTooltip('Numéro de sécurité'), findsNothing);
    expect(find.textContaining('recrée le groupe'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await closeApp(tester, app);
  });

  testWidgets(
    'pending send cannot duplicate a message or erase a newer draft',
    (tester) async {
      final app = DelayedSendApp();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(app: app, conversation: contact()),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Premier message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Brouillon suivant');
      // A keyboard submit must also respect the send already in progress.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(app.sent, ['Premier message']);
      app.completion.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Brouillon suivant',
      );
      await closeApp(tester, app);
    },
  );

  testWidgets(
    'group creation reports storage failure without an uncaught exception',
    (tester) async {
      final app = FailedGroupApp();
      app.conversations.add(contact());
      await tester.pumpWidget(MaterialApp(home: HomeScreen(app: app)));
      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nouveau groupe'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Amis');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Impossible de créer le groupe'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      await closeApp(tester, app);
    },
  );

  testWidgets('invalid pairing code keeps the dialog open for correction', (
    tester,
  ) async {
    final relay = PairingRelay();
    final app = AppState(store: MemoryStore(), relay: relay);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(app: app)));
    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'AB');
    await tester.tap(find.text('Appairer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(relay.answers, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('6 lettres ou chiffres'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'abc234');
    await tester.tap(find.text('Appairer'));
    await tester.pumpAndSettle();
    expect(relay.answers, ['ABC234']);
    expect(find.byType(AlertDialog), findsNothing);
    await closeApp(tester, app);
  });

  testWidgets(
    'profile storage failure is reported without an uncaught exception',
    (tester) async {
      final app = FailedProfileApp();
      await tester.pumpWidget(MaterialApp(home: HomeScreen(app: app)));
      await tester.tap(find.byTooltip('Mon nom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nouveau nom');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Impossible d’enregistrer le nom'),
        findsOneWidget,
      );
      await closeApp(tester, app);
    },
  );

  testWidgets('phone group form scrolls with keyboard and many contacts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final app = AppState(store: MemoryStore(), relay: PairingRelay());
    app.conversations.addAll(List.generate(20, (_) => contact()));
    await tester.pumpWidget(MaterialApp(home: HomeScreen(app: app)));
    await tester.tap(find.text('Groupes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu TTalk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouveau groupe'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Créer'));
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('sélectionne au moins un contact'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await closeApp(tester, app);
  });

  test(
    'profile name changes immediately even without a relay connection',
    () async {
      SharedPreferences.setMockInitialValues({'display_name': 'Ancien nom'});
      FlutterSecureStorage.setMockInitialValues({});
      final store = await SecureStore.create();
      final relay = RelayClient()..displayName = 'Ancien nom';
      final app = AppState(store: store, relay: relay);
      await app.setDisplayName('Nouveau nom');
      expect(store.displayName, 'Nouveau nom');
      expect(app.myName, 'Nouveau nom');
      app.dispose();
    },
  );
}
