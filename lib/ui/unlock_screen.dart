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
    if (!RegExp(r'^\d{4,12}$').hasMatch(pin)) {
      setState(() {
        _error = 'Le code PIN doit contenir au moins 4 chiffres.';
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64),
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
    );
  }
}
