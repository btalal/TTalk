import 'package:flutter/material.dart';

/// A failed Secret Service or local vault must never become a plaintext fallback.
class LinuxStartupFailure extends StatefulWidget {
  const LinuxStartupFailure({super.key, required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  State<LinuxStartupFailure> createState() => _LinuxStartupFailureState();
}

class _LinuxStartupFailureState extends State<LinuxStartupFailure> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TTalk',
    theme: ThemeData(useMaterial3: true, fontFamily: 'Inter'),
    home: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Impossible d’ouvrir le coffre sécurisé',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Vérifie que ton trousseau de session est disponible et déverrouillé, '
                  'et que ton espace de stockage est accessible. '
                  'Aucun coffre de remplacement ne sera créé.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await widget.onRetry();
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: Text(_busy ? 'Ouverture…' : 'Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
