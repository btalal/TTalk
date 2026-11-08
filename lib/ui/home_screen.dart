import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/relay_client.dart';
import '../state/app_state.dart';
import 'chat_screen.dart';
import 'chat_actions.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/branding/ttalk.png',
                width: 40,
                height: 40,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 8),
              const Text('TTalk'),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: [
              const Tab(
                text: 'Conversations',
                icon: Icon(Icons.chat_bubble_outline),
              ),
              Tab(
                text: 'Groupes',
                icon: Badge(
                  isLabelVisible: app.pendingInvites.isNotEmpty,
                  label: Text('${app.pendingInvites.length}'),
                  child: const Icon(Icons.groups_outlined),
                ),
              ),
              const Tab(text: 'Contacts', icon: Icon(Icons.contacts_outlined)),
            ],
          ),
          actions: MediaQuery.sizeOf(context).width < 600
              ? [
                  PopupMenuButton<String>(
                    tooltip: 'Menu TTalk',
                    onSelected: (action) {
                      switch (action) {
                        case 'server':
                          _showRelaySettings(context, app);
                        case 'profile':
                          _showProfile(context, app);
                        case 'group':
                          _showNewGroupDialog(context, app);
                        case 'code':
                          _showMyCode(context, app);
                        case 'pair':
                          _showPairDialog(context, app);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'server',
                        child: Text('Configurer le serveur'),
                      ),
                      const PopupMenuItem(
                        value: 'profile',
                        child: Text('Mon nom'),
                      ),
                      const PopupMenuItem(
                        value: 'code',
                        child: Text("Mon code d’appairage"),
                      ),
                      const PopupMenuItem(
                        value: 'pair',
                        child: Text('Appairer un contact'),
                      ),
                      if (_tab == 1)
                        const PopupMenuItem(
                          value: 'group',
                          child: Text('Nouveau groupe'),
                        ),
                    ],
                  ),
                ]
              : [
                  IconButton(
                    tooltip: 'Configurer le serveur',
                    icon: const Icon(Icons.dns_outlined),
                    onPressed: () => _showRelaySettings(context, app),
                  ),
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
            _RelayBanner(
              app: app,
              configure: () => _showRelaySettings(context, app),
            ),
            Expanded(
              child: switch (_tab) {
                0 => _buildConversations(context, app),
                1 => _buildGroups(context, app),
                _ => _buildConversations(context, app, contactsOnly: true),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversations(
    BuildContext context,
    AppState app, {
    bool contactsOnly = false,
  }) {
    final contacts = contactsOnly
        ? app.conversations
        : app.visibleConversations;
    if (contacts.isEmpty) {
      return const Center(
        child: Text(
          'Aucune conversation.\nUtilise l’action d’appairage pour ajouter un contact.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, i) {
        final c = contacts[i];
        final msgs = app.messagesByConv[c.id] ?? [];
        final last = msgs.isEmpty ? null : msgs.last;
        return ListTile(
          leading: ChatAvatar(
            name: c.displayName,
            symbol: c.localSettings.icon,
          ),
          title: Text(
            c.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            contactsOnly
                ? (c.localSettings.alias == null
                      ? 'Contact appairé'
                      : 'Nom d’origine : ${c.peerName}')
                : last == null
                ? 'Conversation chiffrée de bout en bout'
                : (last.fromMe ? 'Moi : ' : '') +
                      (last.isFile
                          ? '📎 ${last.fileName}'
                          : (last.plaintext ?? '•••')),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!contactsOnly && last != null)
                Text(
                  DateFormat.Hm().format(last.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ChatActionsMenu(app: app, chatId: c.id),
            ],
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
      children.add(
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.mail_outline)),
          title: Text('Invitation au groupe « ${inv.name} »'),
          subtitle: Text(
            'de ${inv.fromName} — ${inv.memberIds.length} membres',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Accepter l’invitation',
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => app.acceptInvite(inv),
              ),
              IconButton(
                tooltip: 'Refuser l’invitation',
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => app.declineInvite(inv),
              ),
            ],
          ),
        ),
      );
    }
    for (final g in app.groups) {
      final msgs = app.messagesByConv[g.id] ?? [];
      final last = msgs.isEmpty ? null : msgs.last;
      children.add(
        ListTile(
          leading: ChatAvatar(
            name: g.displayName,
            symbol: g.localSettings.icon,
            isGroup: true,
          ),
          title: Text(
            g.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: ChatActionsMenu(app: app, chatId: g.id, isGroup: true),
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
        ),
      );
    }
    if (children.isEmpty) {
      return const Center(
        child: Text(
          'Aucun groupe.\nCrée-en un avec l\'icône « groupe + ».',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView(children: children);
  }

  Future<void> _showRelaySettings(BuildContext context, AppState app) async {
    final controller = TextEditingController(text: app.relayUrl);
    String? error;
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Serveur de messagerie'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Les deux personnes doivent utiliser la même adresse. Le serveur peut rester allumé chez un hébergeur.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Adresse du serveur',
                    hintText: "l'url de votre relais privé",
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      update(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await app.configureRelay(controller.text);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } on FormatException catch (e) {
                        if (ctx.mounted) {
                          update(() {
                            error = e.message;
                            busy = false;
                          });
                        }
                      } catch (_) {
                        if (ctx.mounted) {
                          update(() {
                            error = 'Impossible d’enregistrer le serveur.';
                            busy = false;
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Connexion…' : 'Enregistrer et connecter'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  Future<void> _showProfile(BuildContext context, AppState app) async {
    final controller = TextEditingController(
      text: app.myName ?? app.store.displayName,
    );
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mon nom'),
          content: TextField(
            controller: controller,
            maxLength: 40,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      );
      if (name != null) await app.setDisplayName(name);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d’enregistrer le nom. Réessaie.'),
          ),
        );
      }
    } finally {
      // Dialog dismissal animations can still reference its controller.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.dispose();
    }
  }

  Future<void> _showNewGroupDialog(BuildContext context, AppState app) async {
    final nameController = TextEditingController();
    final selected = <String>{};
    bool busy = false;
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: const Text('Nouveau groupe chiffré'),
            scrollable: true,
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Nom du groupe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (app.conversations.isEmpty)
                    const Text("Appaire d'abord des contacts pour les inviter.")
                  else
                    ...app.conversations.map(
                      (c) => CheckboxListTile(
                        dense: true,
                        value: selected.contains(c.peerId),
                        title: Text(c.displayName),
                        onChanged: busy
                            ? null
                            : (value) => update(() {
                                if (value == true) {
                                  selected.add(c.peerId);
                                } else {
                                  selected.remove(c.peerId);
                                }
                              }),
                      ),
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (busy) return;
                        final name = nameController.text.trim();
                        if (name.isEmpty || selected.isEmpty) {
                          update(
                            () => error = 'Indique un nom et sélectionne au moins un contact.',
                          );
                          return;
                        }
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await app.createGroup(name, selected.toList());
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } catch (_) {
                          if (ctx.mounted) {
                            update(() {
                              busy = false;
                              error = 'Impossible de créer le groupe. Vérifie le stockage et réessaie.';
                            });
                          }
                        }
                      },
                child: Text(busy ? 'Création…' : 'Créer'),
              ),
            ],
          ),
        ),
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      nameController.dispose();
    }
  }

  void _showMyCode(BuildContext context, AppState app) {
    if (!app.registered || app.relay.state != RelayState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecte-toi au relais pour t’appairer.'),
        ),
      );
      return;
    }
    app.relay.startPairing();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Mon code d\'appairage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                app.relay.myPairingCode ?? 'Génération…',
                style: const TextStyle(
                  fontSize: 32,
                  letterSpacing: 6,
                  fontWeight: FontWeight.bold,
                ),
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
                  update(() {});
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Nouveau code'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPairDialog(BuildContext context, AppState app) async {
    final controller = TextEditingController();
    String? error;
    bool busy = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: const Text('Appairer un contact'),
            scrollable: true,
            content: TextField(
              controller: controller,
              enabled: !busy,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Code reçu de ton contact',
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (busy) return;
                        final code = controller.text;
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          final message = await app.pairWithCode(code);
                          if (!ctx.mounted) return;
                          if (message == null) {
                            Navigator.of(ctx).pop();
                          } else {
                            update(() {
                              error = message;
                              busy = false;
                            });
                          }
                        } catch (_) {
                          if (ctx.mounted) {
                            update(() {
                              error = 'Appairage impossible. Vérifie la connexion au relais.';
                              busy = false;
                            });
                          }
                        }
                      },
                child: const Text('Appairer'),
              ),
            ],
          ),
        ),
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.dispose();
    }
  }
}

class _RelayBanner extends StatelessWidget {
  const _RelayBanner({required this.app, required this.configure});
  final AppState app;
  final VoidCallback configure;
  @override
  Widget build(BuildContext context) {
    final connected = app.registered;
    final configured = app.relayUrl.isNotEmpty;
    final pending = app.pendingCount;
    final text = !configured
        ? 'Configure le serveur pour communiquer entre tes appareils.'
        : connected
        ? (app.error ?? 'Connecté — messages chiffrés de bout en bout.')
        : (app.error ??
              'Connexion en cours. Les envois restent dans le coffre.');
    return MaterialBanner(
      forceActionsBelow: MediaQuery.sizeOf(context).width < 600,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      content: Text(
        '$text${pending > 0 ? ' $pending envoi(s) en attente.' : ''}',
      ),
      actions: [
        TextButton(onPressed: configure, child: const Text('Serveur')),
        if (configured && !connected)
          TextButton(
            onPressed: app.relay.state == RelayState.connecting
                ? null
                : app.connectSavedRelay,
            child: const Text('Réessayer'),
          ),
      ],
    );
  }
}
