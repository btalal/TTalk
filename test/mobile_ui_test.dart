import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttalk/main.dart';
import 'package:ttalk/state/app_state.dart';
import 'package:ttalk/ui/home_screen.dart';
import 'package:ttalk/ui/unlock_screen.dart';

import 'support/group_fakes.dart';

void main() {
  testWidgets('phone menu exposes settings without overflowing at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppState(
      store: MemoryStore(),
      relay: MemoryRelay('alice', 'Alice'),
    );
    await app.init();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(app: app)));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Menu TTalk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurer le serveur'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    app.dispose();
  });

  testWidgets('PIN screen scrolls with a phone keyboard and landscape height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final app = AppState(
      store: MemoryStore(),
      relay: MemoryRelay('alice', 'Alice'),
    );
    await tester.pumpWidget(MaterialApp(home: UnlockScreen(app: app)));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Créer'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('inactive mobile app covers the content then resumes', (
    tester,
  ) async {
    final app = AppState(
      store: MemoryStore(),
      relay: MemoryRelay('alice', 'Alice'),
    );
    await tester.pumpWidget(TTalkApp(app: app));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.bySemanticsLabel('TTalk'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.bySemanticsLabel('TTalk'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
}
