import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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

class TTalkApp extends StatefulWidget {
  const TTalkApp({super.key, required this.app});

  final AppState app;

  @override
  State<TTalkApp> createState() => _TTalkAppState();
}

class _TTalkAppState extends State<TTalkApp> with WidgetsBindingObserver {
  bool _privacyCover = false;
  bool get _mobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_mobile) return;
    setState(() => _privacyCover = state != AppLifecycleState.resumed);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.app.relay.disconnect();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(widget.app.connectSavedRelay());
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        return MaterialApp(
          title: 'TTalk',
          debugShowCheckedModeBanner: false,
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              if (child != null) child,
              if (_privacyCover)
                ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: Center(
                    child: Image.asset(
                      'assets/branding/ttalk.png',
                      width: 120,
                      height: 120,
                      semanticLabel: 'TTalk',
                    ),
                  ),
                ),
            ],
          ),
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
