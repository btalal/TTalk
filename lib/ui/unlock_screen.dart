import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, required this.app});

  final AppState app;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _pinController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = widget.app;
    final pin = _pinController.text.trim();
    if (!RegExp(widget.app.store.hasPin ? r'^\d{4,12}$' : r'^\d{6,12}$')
        .hasMatch(pin)) {
      setState(() {
        _error = widget.app.store.hasPin
            ? 'Code PIN invalide.'
            : 'Choisis de 6 à 12 chiffres pour ton nouveau PIN.';
        _busy = false;
      });
      return;
    }
    try {
      if (app.store.hasPin) {
        await app.unlock(pin);
        if (!app.unlocked && mounted) {
          setState(() {
            _error = 'Code PIN incorrect.';
            _busy = false;
          });
        }
      } else {
        await app.createPin(pin);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible d’ouvrir le coffre. Réessaie.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creating = !widget.app.store.hasPin;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/branding/ttalk.png',
                      width: 112,
                      height: 112,
                      semanticLabel: 'TTalk, messagerie chiffrée',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      creating ? 'Créer un code PIN' : 'Déverrouiller TTalk',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ce code chiffre tes messages sur cet appareil. Ne l\'oublie pas.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Code PIN',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    if (!creating && widget.app.store.biometricsEnabled)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Déverrouiller avec la biométrie'),
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  if (!await widget.app.unlockBiometrics() &&
                                      mounted) {
                                    setState(
                                      () => _error = 'Utilise ton PIN pour déverrouiller le coffre.',
                                    );
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    setState(
                                      () => _error = 'Biométrie annulée ou indisponible. Utilise ton PIN.',
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(creating ? 'Créer' : 'Déverrouiller'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
