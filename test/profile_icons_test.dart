import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttalk/models/chat_settings.dart';
import 'package:ttalk/models/profile_icons.dart';
import 'package:ttalk/ui/chat_actions.dart';

import 'chat_management_ui_test.dart' as fixture;

void main() {
  test('approved IDs survive appearance serialization without replacing legacy icons', () {
    expect(ProfileIcons.all.length, 25);
    expect(ProfileIcons.all.map((i) => i.symbol).toSet().length, 25);
    for (final icon in ProfileIcons.all) {
      expect(ChatSettings.isValidIcon(icon.symbol), isTrue);
      expect(
        ChatSettings.fromJson(ChatSettings(icon: icon.symbol).toJson()).icon,
        icon.symbol,
      );
    }
    expect(ChatSettings.isValidIcon('icon:unknown'), isFalse);
    expect(ChatSettings.avatarIndex('avatar:19'), 19);
    expect(ChatSettings.isValidIcon('🐱'), isTrue);
  });

  testWidgets('all approved images load for contacts and groups', (
    tester,
  ) async {
    for (final group in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Wrap(
            children: [
              for (final icon in ProfileIcons.all)
                ChatAvatar(
                  name: icon.label,
                  symbol: icon.symbol,
                  isGroup: group,
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(25));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'phone selector saves a color icon and keeps the selection on reopen',
    (tester) async {
      fixture.phone(tester);
      final app = fixture.fixture();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showChatCustomization(ctx, app, 'chat'),
                child: const Text('Personnaliser'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Personnaliser'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fedora'));
      await tester.tap(find.text('Fedora'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(app.chatIcon('chat'), 'icon:fedora');
      await tester.tap(find.text('Personnaliser'));
      await tester.pumpAndSettle();
      final selected = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where(
            (w) =>
                w.properties.label == 'Fedora' && w.properties.selected == true,
          );
      expect(selected.length, 1);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await fixture.close(tester, app);
    },
  );
}
