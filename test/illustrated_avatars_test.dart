import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttalk/models/chat_settings.dart';
import 'package:ttalk/ui/avatar_art.dart';
import 'package:ttalk/ui/appearance_symbol.dart';

void main() {
  test('existing stored choices retain stable IDs and theme mapping', () {
    expect(AvatarArt.groupLabels.length, ChatSettings.avatarCount);
    expect(AvatarArt.groupLabels[2], 'Travail');
    for (var i = 0; i < ChatSettings.avatarCount; i++) {
      final id = ChatSettings.avatarIcon(i);
      expect(ChatSettings.fromJson(ChatSettings(icon: id).toJson()).icon, id);
    }
    expect(AppearanceSymbol.assetFor('💻'), 'assets/symbols/11.png');
    expect(AppearanceSymbol.labels[10], 'Fichiers');
    expect(AppearanceSymbol.assetFor('inconnu'), isNull);
  });
  testWidgets('all 40 portraits/groups and 20 modern symbols decode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (var i = 0; i < 20; i++) AvatarArt(index: i),
            for (var i = 0; i < 20; i++) AvatarArt(index: i, group: true),
            for (final icon in ChatSettings.icons)
              AppearanceSymbol(icon, size: 40),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(60));
    expect(tester.takeException(), isNull);
  });
}
