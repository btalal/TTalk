import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttalk/models/group.dart';
import 'package:ttalk/models/message.dart';
import 'package:ttalk/state/app_state.dart';
import 'package:ttalk/ui/chat_screen.dart';

import 'support/group_fakes.dart';

void main() {
  testWidgets(
      'owner confirms transfer; system notice and new roles are rendered',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app =
        AppState(store: MemoryStore(), relay: MemoryRelay('alice', 'Alice'));
    await app.init();
    final id = await app.createGroup('Amis', ['bob']);
    final g = app.groups.single;
    app.groups[0] = g.applyControl(
        GroupControl(
          kind: 'join',
          groupId: id,
          memberIds: g.memberIds,
          adminIds: g.adminIds,
          epoch: g.epoch,
          memberId: 'bob',
        ),
        senderId: 'bob')!;
    app.messagesByConv[id] = [
      ChatMessage(
        id: 'event',
        conversationId: id,
        fromMe: false,
        ciphertext: [],
        timestamp: DateTime(2026),
        plaintext: 'Bob a rejoint le groupe.',
        kind: 'system',
        isGroup: true,
      )
    ];
    await tester.pumpWidget(
        MaterialApp(home: ChatScreen(app: app, group: app.groups.single)));
    expect(find.text('Bob a rejoint le groupe.'), findsOneWidget);
    await tester.tap(find.byTooltip('Membres du groupe'));
    await tester.pumpAndSettle();
    expect(find.text('Propriétaire'), findsOneWidget);
    await tester.tap(find.byTooltip('Transférer la propriété'));
    await tester.pumpAndSettle();
    expect(find.text('Transférer la propriété ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(app.groups.single.ownerId, 'alice');
    await tester.tap(find.byTooltip('Transférer la propriété'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transférer'));
    await tester.pumpAndSettle();
    expect(app.groups.single.ownerId, 'bob');
    expect(find.byTooltip('Transférer la propriété'), findsNothing);
    expect(find.byTooltip('Retirer du groupe'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
}
