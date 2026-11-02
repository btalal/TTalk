import 'dart:async';

import 'package:flutter/material.dart';

import 'services/relay_client.dart';
import 'services/secure_store.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/unlock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SecureStore.create();
  final relay = RelayClient();
  final app = AppState(store: store, relay: relay);
  await app.init();
  runApp(TTalkApp(app: app));
  unawaited(app.connectSavedRelay());
}

class TTalkApp extends StatelessWidget {
  const TTalkApp({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        return MaterialApp(
          title: 'TTalk',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4338CA),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4338CA),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: app.unlocked ? HomeScreen(app: app) : UnlockScreen(app: app),
        );
      },
    );
  }
}
