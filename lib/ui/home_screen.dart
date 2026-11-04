import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../services/relay_client.dart';
import '../state/app_state.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.app});

  final AppState app;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TalMessenger'),
        actions: [
          IconButton(
            tooltip: 'Mon code d\'appairage',
            icon: const Icon(Icons.qr_code),
            onPressed: () => _showMyCode(context, app),
          ),
          IconButton(
            tooltip: 'Appairer avec un code',
            icon: const Icon(Icons.person_add),
            onPressed: () => _showPairDialog(context, app),
          ),
        ],
      ),
      body: Column(
        children: [
          _RelayBanner(app: app),
          Expanded(
            child: app.conversations.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune conversation.\nAppuie sur l\'icône personne pour appairer un contact.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: app.conversations.length,
                    itemBuilder: (context, i) {
                      final c = app.conversations[i];
                      final msgs = app.messagesByConv[c.id] ?? [];
                      final last = msgs.isEmpty ? null : msgs.last;
                      return ListTile(
                        leading: CircleAvatar(child: Text(c.peerName.isEmpty ? '?' : c.peerName[0].toUpperCase())),
                        title: Text(c.peerName),
                        subtitle: Text(
                          last == null
                              ? 'Conversation chiffrée de bout en bout'
                              : (last.fromMe ? 'Moi : ' : '') + (last.plaintext ?? '•••'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: last == null
                            ? null
                            : Text(
                                DateFormat.Hm().format(last.timestamp),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(app: app, conversation: c),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showMyCode(BuildContext context, AppState app) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mon code d\'appairage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              app.relay.myPairingCode ?? 'Génération…',
              style: const TextStyle(fontSize: 32, letterSpacing: 6, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Donne ce code à ton contact (par un autre canal) pour créer une conversation chiffrée.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                app.relay.startPairing();
                setState(() {});
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code d\'appairage généré — partage-le à ton contact.')),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Nouveau code'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
        ],
      ),
    );
  }

  void _showPairDialog(BuildContext context, AppState app) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appairer un contact'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Code reçu par ton contact',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final err = await app.pairWithCode(controller.text.trim().toUpperCase());
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              }
            },
            child: const Text('Appairer'),
          ),
        ],
      ),
    );
  }
}

class _RelayBanner extends StatelessWidget {
  const _RelayBanner({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final connected = app.relay.state == RelayState.connected;
    return MaterialBanner(
      backgroundColor: connected ? Colors.green.shade50 : Colors.orange.shade50,
      content: Text(
        connected
            ? 'Connecté au relais — les messages restent chiffrés de bout en bout.'
            : 'Relais déconnecté — reconnecte-toi pour envoyer des messages.',
      ),
      actions: [
        TextButton(
          onPressed: () => app.relay.connect(const String.fromEnvironment(
            'RELAY_URL',
            defaultValue: 'ws://localhost:8080',
          )),
          child: const Text('Reconnecter'),
        ),
      ],
    );
  }
}
