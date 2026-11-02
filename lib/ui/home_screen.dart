import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/relay_client.dart';
import '../state/app_state.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.app});

  final AppState app;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _tab) {
        setState(() => _tab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('TTalk'),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              const Tab(
                  text: 'Conversations', icon: Icon(Icons.chat_bubble_outline)),
              Tab(
                text: 'Groupes',
                icon: Badge(
                  isLabelVisible: app.pendingInvites.isNotEmpty,
                  label: Text('${app.pendingInvites.length}'),
                  child: const Icon(Icons.groups_outlined),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Mon nom',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => _showProfile(context, app),
            ),
            if (_tab == 1)
              IconButton(
                tooltip: 'Nouveau groupe',
                icon: const Icon(Icons.group_add),
                onPressed: () => _showNewGroupDialog(context, app),
              ),
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
              child: _tab == 0
                  ? _buildConversations(context, app)
                  : _buildGroups(context, app),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversations(BuildContext context, AppState app) {
    if (app.conversations.isEmpty) {
      return const Center(
        child: Text(
          'Aucune conversation.\nAppuie sur l\'icône personne pour appairer un contact.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      itemCount: app.conversations.length,
      itemBuilder: (context, i) {
        final c = app.conversations[i];
        final msgs = app.messagesByConv[c.id] ?? [];
        final last = msgs.isEmpty ? null : msgs.last;
        return ListTile(
          leading: CircleAvatar(
              child:
                  Text(c.peerName.isEmpty ? '?' : c.peerName[0].toUpperCase())),
          title: Text(c.peerName),
          subtitle: Text(
            last == null
                ? 'Conversation chiffrée de bout en bout'
                : (last.fromMe ? 'Moi : ' : '') +
                    (last.isFile
                        ? '📎 ${last.fileName}'
                        : (last.plaintext ?? '•••')),
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
    );
  }

  Widget _buildGroups(BuildContext context, AppState app) {
    final children = <Widget>[];
    for (final inv in app.pendingInvites) {
      children.add(ListTile(
        leading: const CircleAvatar(child: Icon(Icons.mail_outline)),
        title: Text('Invitation au groupe « ${inv.name} »'),
        subtitle: Text('de ${inv.fromName} — ${inv.memberIds.length} membres'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => app.acceptInvite(inv)),
            IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => app.declineInvite(inv)),
          ],
        ),
      ));
    }
    for (final g in app.groups) {
      final msgs = app.messagesByConv[g.id] ?? [];
      final last = msgs.isEmpty ? null : msgs.last;
      children.add(ListTile(
        leading: const CircleAvatar(child: Icon(Icons.groups)),
        title: Text(g.name),
        subtitle: Text(
          last == null
              ? '${g.memberIds.length} membres — chiffré de bout en bout'
              : last.isSystem
                  ? (last.plaintext ?? '')
                  : '${last.fromMe ? 'Moi' : (last.senderName ?? '?')} : ${last.isFile ? '📎 ${last.fileName}' : (last.plaintext ?? '•••')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(app: app, group: g),
          ),
        ),
      ));
    }
    if (children.isEmpty) {
      return const Center(
        child: Text('Aucun groupe.\nCrée-en un avec l\'icône « groupe + ».',
            textAlign: TextAlign.center),
      );
    }
    return ListView(children: children);
  }

  Future<void> _showProfile(BuildContext context, AppState app) async {
    final controller =
        TextEditingController(text: app.myName ?? app.store.displayName);
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mon nom'),
          content:
              TextField(controller: controller, maxLength: 40, autofocus: true),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.of(ctx).pop(controller.text.trim());
                  }
                },
                child: const Text('Enregistrer')),
          ],
        ),
      );
      if (name != null) await app.setDisplayName(name);
    } finally {
      // Dialog dismissal animations can still reference its controller.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.dispose();
    }
  }

  void _showNewGroupDialog(BuildContext context, AppState app) {
    final nameController = TextEditingController();
    final selected = <String>{};
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Nouveau groupe chiffré'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nom du groupe', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                if (app.conversations.isEmpty)
                  const Text('Appaire d\'abord des contacts pour les inviter.')
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: app.conversations.map((c) {
                        final on = selected.contains(c.peerId);
                        return CheckboxListTile(
                          dense: true,
                          value: on,
                          title: Text(c.peerName),
                          onChanged: (v) => setStateDialog(() {
                            if (v == true) {
                              selected.add(c.peerId);
                            } else {
                              selected.remove(c.peerId);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || selected.isEmpty) {
                  return;
                }
                await app.createGroup(
                    nameController.text.trim(), selected.toList());
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyCode(BuildContext context, AppState app) {
    if (app.myId == null || app.relay.state != RelayState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Connecte-toi au relais pour t’appairer.')));
      return;
    }
    app.relay.startPairing();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mon code d\'appairage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              app.relay.myPairingCode ?? 'Génération…',
              style: const TextStyle(
                  fontSize: 32, letterSpacing: 6, fontWeight: FontWeight.bold),
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
                  const SnackBar(
                      content: Text(
                          'Code d\'appairage généré — partage-le à ton contact.')),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Nouveau code'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer')),
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
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final err =
                  await app.pairWithCode(controller.text.trim().toUpperCase());
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
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
            : (app.error ??
                'Relais déconnecté — reconnecte-toi pour envoyer des messages.'),
      ),
      actions: [
        TextButton(
          onPressed: connected || app.relay.state == RelayState.connecting
              ? null
              : () => app.connectRelay(const String.fromEnvironment(
                    'RELAY_URL',
                    defaultValue: 'ws://localhost:8080',
                  )),
          child: const Text('Reconnecter'),
        ),
      ],
    );
  }
}
