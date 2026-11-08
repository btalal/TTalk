import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttalk/ui/linux_startup_failure.dart';

void main() {
  testWidgets('locked keyring offers retry without creating another vault', (
    tester,
  ) async {
    final pending = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      LinuxStartupFailure(
        onRetry: () {
          attempts++;
          return pending.future;
        },
      ),
    );
    expect(find.text('Impossible d’ouvrir le coffre sécurisé'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    expect(attempts, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
