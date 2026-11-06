import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/backup_codec.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.app, this.embedded = false});
  final AppState app;
  final bool embedded;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError ? error.message : 'Opération non terminée. Vérifie le fichier, la phrase de passe ou l’autorisation système.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _password({required bool restoring}) async {
    final first = TextEditingController(), second = TextEditingController();
    bool accepted = false;
    String? validation;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(
            restoring
                ? 'Restaurer une sauvegarde'
                : 'Créer une sauvegarde chiffrée',
          ),
          scrollable: true,
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  restoring
                      ? 'Cette restauration est réservée à un coffre vide. Elle récupère l’identité sauvegardée : cesse d’utiliser l’ancien appareil avant de reconnecter cette identité.'
                      : 'La sauvegarde contient ton identité privée, tes contacts et ton historique. Conserve-la avec une phrase de passe indépendante du PIN. Les pièces jointes ne sont pas incluses.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: first,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Phrase de passe (16 caractères minimum)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (!restoring) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: second,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Confirmer la phrase de passe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: accepted,
                  onChanged: (v) => update(() => accepted = v ?? false),
                  title: Text(
                    restoring
                        ? 'J’ai cessé d’utiliser cette identité sur l’ancien appareil.'
                        : 'Je comprends qu’une phrase de passe perdue ne peut pas être récupérée.',
                  ),
                ),
                if (validation != null)
                  Text(
                    validation!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: accepted
                  ? () {
                      try {
                        BackupCodec.validatePassword(first.text);
                        if (!restoring && first.text != second.text) {
                          throw ArgumentError(
                            'Les phrases de passe ne correspondent pas.',
                          );
                        }
                        Navigator.pop(ctx, first.text);
                      } catch (e) {
                        update(
                          () => validation = e is ArgumentError
                              ? e.message.toString()
                              : 'Phrase de passe invalide.',
                        );
                      }
                    }
                  : null,
              child: Text(restoring ? 'Restaurer' : 'Continuer'),
            ),
          ],
        ),
      ),
    );
    first.clear();
    second.clear();
    first.dispose();
    second.dispose();
    return result;
  }

  Future<void> _backup() async {
    final pass = await _password(restoring: false);
    if (pass == null || !mounted) return;
    await _run(() async {
      final bytes = await widget.app.backup(pass);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la sauvegarde chiffrée',
        fileName:
            'ttalk-${DateTime.now().toIso8601String().substring(0, 10)}.ttalk',
        bytes: bytes,
      );
      if (path == null) return;
      if (!Platform.isIOS && !Platform.isAndroid) {
        await File(path).writeAsBytes(bytes, flush: true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sauvegarde chiffrée enregistrée.')),
        );
      }
    });
  }

  Future<void> _restore() async {
    if (widget.app.conversations.isNotEmpty || widget.app.groups.isNotEmpty) {
      throw StateError(
        'Utilise un coffre vide pour restaurer sans écraser tes conversations.',
      );
    }
    final result = await FilePicker.platform.pickFiles(
      withData: false,
      type: FileType.any,
    );
    if (result == null || result.files.single.path == null || !mounted) return;
    final file = File(result.files.single.path!);
    if (await file.length() > BackupCodec.maxBytes) {
      throw StateError('Fichier trop volumineux.');
    }
    if (!mounted) return;
    final pass = await _password(restoring: true);
    if (pass == null || !mounted) return;
    await widget.app.restoreBackup(await file.readAsBytes(), pass);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Historique restauré. Vérifie les numéros de sécurité avec tes contacts.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Confidentialité',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.lock_clock_outlined),
            title: const Text('Verrouillage automatique'),
            subtitle: const Text(
              'Le coffre et la connexion se ferment après inactivité.',
            ),
            trailing: DropdownButton<int>(
              value: app.store.autoLockSeconds,
              items: const [
                DropdownMenuItem(value: 30, child: Text('30 s')),
                DropdownMenuItem(value: 60, child: Text('1 min')),
                DropdownMenuItem(value: 300, child: Text('5 min')),
                DropdownMenuItem(value: 900, child: Text('15 min')),
              ],
              onChanged: _busy
                  ? null
                  : (v) => _run(() async {
                      await app.store.setAutoLockSeconds(v!);
                      setState(() {});
                    }),
            ),
          ),
          FutureBuilder<bool>(
            future: app.store.biometricAvailable(),
            builder: (ctx, snapshot) => SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Déverrouillage biométrique'),
              subtitle: Text(
                snapshot.data == true
                    ? 'Clé du coffre protégée par la biométrie du système. PIN de secours conservé.'
                    : 'Configure Face ID, Touch ID ou une empreinte sur un appareil pris en charge.',
              ),
              value: app.store.biometricsEnabled,
              onChanged: _busy || snapshot.data != true
                  ? null
                  : (v) => _run(() async {
                      if (v) {
                        await app.store.enableBiometrics();
                      } else {
                        await app.store.disableBiometrics();
                      }
                      setState(() {});
                    }),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Verrouiller maintenant'),
            onTap: _busy ? null : () => _run(app.lockVault),
          ),
          const Divider(height: 32),
          Text(
            'Sauvegarde et récupération',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Fichier chiffré local, sans envoi au relais. Historique et clés inclus ; pièces jointes et envois en attente exclus.',
          ),
          ListTile(
            leading: const Icon(Icons.enhanced_encryption_outlined),
            title: const Text('Créer une sauvegarde chiffrée'),
            onTap: _busy ? null : _backup,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restaurer dans un coffre vide'),
            onTap: _busy ? null : () => _run(_restore),
          ),
          if (_busy) const LinearProgressIndicator(),
          const Divider(height: 32),
          const ListTile(
            leading: Icon(Icons.notifications_off_outlined),
            title: Text('Notifications push'),
            subtitle: Text(
              'Reportées. Les messages sont récupérés lorsque TTalk est ouvert et déverrouillé.',
            ),
          ),
        ],
      ),
    );
  }
}
