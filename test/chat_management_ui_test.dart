import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttalk/models/group.dart';
import 'package:ttalk/models/message.dart';
import 'package:ttalk/state/app_state.dart';
import 'package:ttalk/ui/chat_screen.dart';
import 'package:ttalk/ui/home_screen.dart';

import 'support/group_fakes.dart';

AppState fixture() {
  final app = AppState(
    store: MemoryStore(),
    relay: MemoryRelay('alice', 'Alice'),
  );
  app.conversations.add(
    Conversation(
      id: 'chat',
      peerId: 'bob',
      peerName: 'Bob',
      peerPublicKey: [],
      createdAt: DateTime(2026),
    ),
  );
  return app;
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> close(WidgetTester tester, AppState app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  app.dispose();
}

void main() {
  testWidgets(
    'phone contact personalization shows the chosen name and icon in the chat',
    (tester) async {
      phone(tester);
      final app = fixture();
      await tester.pumpWidget(MaterialApp(home: HomeScreen(app: app)));
      await tester.tap(find.byTooltip('Actions du contact'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nom et icône'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Mon collègue');
      await tester.ensureVisible(find.text('🎓'));
      await tester.tap(find.text('🎓'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Mon collègue'), findsOneWidget);
      expect(find.text('🎓'), findsOneWidget);
      await tester.tap(find.text('Mon collègue'));
      await tester.pumpAndSettle();
      expect(find.text('Mon collègue'), findsOneWidget);
      expect(find.text('🎓'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester, app);
    },
  );

  testWidgets(
    'conversation deletion can be cancelled; contact remains available after confirmation',
    (tester) async {
      phone(tester);
      final app = fixture();
      await tester.pumpWidget(MaterialApp(home: HomeScreen(app: app)));
      Future<void> openDelete() async {
        await tester.tap(find.byTooltip('Actions du contact'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Supprimer la conversation'));
        await tester.pumpAndSettle();
      }

      await openDelete();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsOneWidget);
      await openDelete();
      await tester.tap(find.text('Confirmer la suppression'));
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsNothing);
      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester, app);
    },
  );

  testWidgets(
    'deleting an attachment from the message menu keeps its original file',
    (tester) async {
      phone(tester);
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('ttalk-file-delete-'),
      ))!;
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/original.txt');
      await tester.runAsync(() => file.writeAsString('original'));
      final app = fixture();
      app.messagesByConv['chat'] = [
        ChatMessage(
          id: 'file',
          conversationId: 'chat',
          fromMe: true,
          ciphertext: [],
          timestamp: DateTime(2026),
          kind: 'file',
          fileName: 'original.txt',
          fileSize: 8,
          filePath: file.path,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(app: app, conversation: app.conversations.single),
        ),
      );
      await tester.longPress(find.text('original.txt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer pour moi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer la suppression'));
      await tester.pumpAndSettle();
      expect(app.messagesByConv['chat'], isEmpty);
      expect(await tester.runAsync(() => file.readAsString()), 'original');
      expect(tester.takeException(), isNull);
      await close(tester, app);
    },
  );

  testWidgets(
    'legacy groups can be personalized and deleted from the group menu',
    (tester) async {
      phone(tester);
      final app = fixture();
      app.groups.add(
        Group(
          id: 'old',
          name: 'Ancien groupe',
          memberIds: ['alice'],
          createdBy: 'alice',
          createdAt: DateTime(2026),
          requiresRecreation: true,
        ),
      );
      await tester.pumpWidget(MaterialApp(home: HomeScreen(app: app)));
      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actions du groupe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nom et icône'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Souvenirs');
      await tester.ensureVisible(find.text('⭐'));
      await tester.tap(find.text('⭐'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Souvenirs'), findsOneWidget);
      expect(find.text('⭐'), findsOneWidget);
      await tester.tap(find.byTooltip('Actions du groupe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitter et supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer la suppression'));
      await tester.pumpAndSettle();
      expect(app.groups, isEmpty);
      expect(tester.takeException(), isNull);
      await close(tester, app);
    },
  );
}
