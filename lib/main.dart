import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  Timer? _idleTimer;
  DateTime _lastActivity = DateTime.now();
  void _activity() {
    if (!widget.app.unlocked || widget.app.locking) return;
    _lastActivity = DateTime.now();
    _idleTimer?.cancel();
    _idleTimer = Timer(
      Duration(seconds: widget.app.store.autoLockSeconds),
      _lock,
    );
  }

  Future<void> _lock() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    try {
      await widget.app.lockVault();
    } catch (_) {
      widget.app.error = 'Une écriture n’a pas abouti avant le verrouillage. Vérifie ton stockage.';
    }
  }

  void _appChanged() {
    if (!widget.app.unlocked) {
      _idleTimer?.cancel();
      _idleTimer = null;
      return;
    }
    if (widget.app.unlocked && _idleTimer == null) _activity();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.app.addListener(_appChanged);
    _appChanged();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    widget.app.removeListener(_appChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _privacyCover = state != AppLifecycleState.resumed);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.app.relay.disconnect();
    } else if (state == AppLifecycleState.resumed) {
      if (widget.app.unlocked &&
          DateTime.now().difference(_lastActivity).inSeconds >=
              widget.app.store.autoLockSeconds) {
        unawaited(_lock());
      } else {
        unawaited(widget.app.connectSavedRelay());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        return MaterialApp(
          key: ValueKey(app.unlocked),
          title: 'TTalk',
          debugShowCheckedModeBanner: false,
          builder: (context, child) => Listener(
            onPointerDown: (_) => _activity(),
            onPointerSignal: (_) => _activity(),
            child: Focus(
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent) {
                  _activity();
                  if (event.logicalKey == LogicalKeyboardKey.keyL &&
                      (HardwareKeyboard.instance.isControlPressed ||
                          HardwareKeyboard.instance.isMetaPressed)) {
                    unawaited(_lock());
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (child != null) child,
                  if (_privacyCover || app.locking)
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
            ),
          ),
          // Inter is bundled so Windows, macOS, Android and iPhone render the
          // same text.
          theme: ThemeData(
            fontFamily: 'Inter',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4338CA),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            fontFamily: 'Inter',
            scaffoldBackgroundColor: const Color(0xFF14141B),
            colorScheme:
                ColorScheme.fromSeed(
                  seedColor: const Color(0xFF6C5CE7),
                  brightness: Brightness.dark,
                ).copyWith(
                  surface: const Color(0xFF14141B),
                  surfaceContainerLowest: const Color(0xFF0E0E13),
                  surfaceContainerLow: const Color(0xFF17171F),
                  surfaceContainer: const Color(0xFF1A1A23),
                  surfaceContainerHigh: const Color(0xFF1E1E29),
                  surfaceContainerHighest: const Color(0xFF262633),
                ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF14141B),
              surfaceTintColor: Colors.transparent,
            ),
            navigationBarTheme: const NavigationBarThemeData(
              backgroundColor: Color(0xFF121219),
              indicatorColor: Color(0xFF2E2E48),
            ),
            useMaterial3: true,
          ),
          home: app.unlocked ? HomeScreen(app: app) : UnlockScreen(app: app),
        );
      },
    );
  }
}
