import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttalk/models/message.dart';
import 'package:ttalk/state/app_state.dart';
import 'package:ttalk/ui/home_screen.dart';
import 'package:ttalk/ui/chat_screen.dart';

import 'support/group_fakes.dart';

AppState fixture() {
  final app = AppState(
    store: MemoryStore(),
    relay: MemoryRelay('alice', 'Alice'),
  );
  app.unlocked = true;
  for (final name in ['Camille', 'Léa']) {
    app.conversations.add(
      Conversation(
        id: name,
        peerId: name,
        peerName: name,
        peerPublicKey: [],
        createdAt: DateTime(2026),
      ),
    );
  }
  app.messagesByConv['Camille'] = [
    ChatMessage(
      id: '1',
      conversationId: 'Camille',
      fromMe: false,
      ciphertext: [],
      timestamp: DateTime(2026, 11, 6, 11, 38),
      plaintext: 'J’ai testé TTalk sur mon Mac. Tout fonctionne !',
    ),
    ChatMessage(
      id: '2',
      conversationId: 'Camille',
      fromMe: true,
      ciphertext: [],
      timestamp: DateTime(2026, 11, 6, 11, 39),
      plaintext: 'Super, je reçois bien tes messages sur l’iPhone.',
      read: true,
    ),
    ChatMessage(
      id: '3',
      conversationId: 'Camille',
      fromMe: false,
      ciphertext: [],
      timestamp: DateTime(2026, 11, 6, 11, 42),
      plaintext: 'On se retrouve au jardin à 18 h ?',
    ),
  ];
  return app;
}

void main() {
  testWidgets(
    'desktop keeps list and conversation together; local search finds message content',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capturing = Platform.environment['TTALK_CAPTURE'] == '1';
      if (capturing) {
        await tester.runAsync(() async {
          final font = Platform.environment['TTALK_PREVIEW_FONT'];
          if (font != null) {
            final loader = FontLoader('TTalkPreview');
            loader.addFont(
              Future.value(
                (await File(font).readAsBytes()).buffer.asByteData(),
              ),
            );
            await loader.load();
          }
          final icons = Platform.environment['TTALK_ICON_FONT'];
          if (icons != null) {
            final loader = FontLoader('MaterialIcons');
            loader.addFont(
              Future.value(
                (await File(icons).readAsBytes()).buffer.asByteData(),
              ),
            );
            await loader.load();
          }
        });
      }
      final app = fixture();
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: capturing ? 'TTalkPreview' : null,
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF4338CA),
              ),
            ),
            home: HomeScreen(app: app),
          ),
        ),
      );
      await tester.tap(find.text('Camille'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('On se retrouve au jardin à 18 h ?'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      if (Platform.environment['TTALK_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build').create(recursive: true);
          await File('build/next-desktop.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.enterText(find.byType(TextField).first, 'jardin');
      await tester.pumpAndSettle();
      expect(find.text('Léa'), findsNothing);
      expect(find.text('Camille'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    },
  );
  testWidgets(
    'phone retains bottom navigation, a single chat and quoted reply without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = fixture();
      await tester.pumpWidget(MaterialApp(home: HomeScreen(app: app)));
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('Camille'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('On se retrouve au jardin à 18 h ?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();
      expect(find.text('Répondre au message'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Annuler la réponse'));
      await tester.pumpAndSettle();
      expect(find.text('Répondre au message'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    },
  );
}
