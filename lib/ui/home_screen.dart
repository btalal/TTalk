import 'dart:io';

import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/relay_client.dart';
import '../state/app_state.dart';
import 'chat_screen.dart';
import 'chat_actions.dart';
import 'settings_screen.dart';
import 'qr_scanner_screen.dart';
import '../services/pairing_invitation.dart';
import '../models/message.dart';
import '../models/group.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.app});

  final AppState app;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0, _nav = 0;
  String _query = '', _filter = 'all';
  Conversation? _selectedConversation;
  Group? _selectedGroup;
  bool get _wide => MediaQuery.sizeOf(context).width >= 960;
  void _openChat({Conversation? conversation, Group? group}) {
    if (_wide) {
      setState(() {
        _selectedConversation = conversation;
        _selectedGroup = group;
      });
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            app: widget.app,
            conversation: conversation,
            group: group,
          ),
        ),
      );
    }
  }

  Future<void> _scan() async {
    final value = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
    if (value == null || !mounted) return;
    await _pairInvitation(value);
  }

  Future<void> _pairInvitation(String value) async {
    try {
      final invitation = PairingInvitation.parse(value);
      if (invitation.relay.isNotEmpty &&
          RelayClient.normalizeUrl(widget.app.relayUrl) != invitation.relay) {
        throw StateError(
          'Cette invitation utilise ${invitation.relay}. Configure et vérifie ce relais avant de continuer.',
        );
      }
      final error = await widget.app.pairInvitation(value);
      if (error != null) throw StateError(error);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  void _navigate(int index) => setState(() {
    _nav = index;
    _tab = index == 1 ? 2 : 0;
    _filter = 'all';
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.app,
    builder: (context, _) {
      final app = widget.app;
      final settings = SettingsScreen(app: app, embedded: true);
      final list = Column(
        children: [
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            _RelayBanner(
              app: app,
              configure: () => _showRelaySettings(context, app),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Rechercher un contact, message ou fichier',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (_nav == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final choice in const [
                    ('all', 'Toutes'),
                    ('unread', 'Non lues'),
                    ('groups', 'Groupes'),
                    ('archive', 'Archives'),
                  ])
                    FilterChip(
                      label: Text(choice.$2),
                      selected: _filter == choice.$1,
                      onSelected: (_) => setState(() {
                        _filter = choice.$1;
                        _tab = _filter == 'groups' ? 1 : 0;
                      }),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _tab == 1
                ? _buildGroups(context, app)
                : _nav == 1
                ? _buildConversations(context, app, contactsOnly: true)
                : _buildOverview(context, app),
          ),
        ],
      );
      final title = _nav == 1
          ? 'Contacts'
          : _nav == 2
          ? 'Réglages'
          : 'TTalk';
      final toolbar = AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/ttalk.png',
              width: 30,
              height: 30,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Appairer un contact',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => _showPairDialog(context, app),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu TTalk',
            onSelected: (action) {
              switch (action) {
                case 'server':
                  _showRelaySettings(context, app);
                case 'profile':
                  _showProfile(context, app);
                case 'code':
                  _showMyCode(context, app);
                case 'group':
                  _showNewGroupDialog(context, app);
                case 'lock':
                  app.lockVault();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'code', child: Text('Mon code d’appairage')),
              PopupMenuItem(value: 'group', child: Text('Nouveau groupe')),
              PopupMenuItem(value: 'profile', child: Text('Mon nom')),
              PopupMenuItem(
                value: 'server',
                child: Text('Configurer le serveur'),
              ),
              PopupMenuItem(
                value: 'lock',
                child: Text('Verrouiller maintenant'),
              ),
            ],
          ),
        ],
      );
      if (!_wide) {
        return Scaffold(
          appBar: toolbar,
          body: _nav == 2 ? settings : list,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _nav,
            onDestinationSelected: _navigate,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Discussions',
              ),
              NavigationDestination(
                icon: Icon(Icons.contacts_outlined),
                selectedIcon: Icon(Icons.contacts),
                label: 'Contacts',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Réglages',
              ),
            ],
          ),
        );
      }
      final selectedId = _selectedConversation?.id ?? _selectedGroup?.id;
      final exists =
          app.conversations.any((c) => c.id == selectedId) ||
          app.groups.any((g) => g.id == selectedId);
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _nav,
              onDestinationSelected: _navigate,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Image.asset(
                  'assets/branding/ttalk.png',
                  width: 38,
                  height: 38,
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: Text('Discussions'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.contacts_outlined),
                  label: Text('Contacts'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: Text('Réglages'),
                ),
              ],
            ),
            SizedBox(
              width: 350,
              child: Scaffold(appBar: toolbar, body: list),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _nav == 2
                  ? settings
                  : exists
                  ? ChatScreen(
                      key: ValueKey(selectedId),
                      app: app,
                      conversation: _selectedConversation,
                      group: _selectedGroup,
                      embedded: true,
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Une conversation, en toute simplicité.',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Choisis un contact ou ajoute une nouvelle conversation.',
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildOverview(BuildContext context, AppState app) {
    final entries =
        <({String id, Conversation? contact, Group? group})>[
              for (final c in app.visibleConversations)
                (id: c.id, contact: c, group: null),
              for (final g in app.groups) (id: g.id, contact: null, group: g),
            ]
            .where(
              (e) =>
                  app.matchesSearch(e.id, _query) &&
                  app.settingsFor(e.id).archived == (_filter == 'archive') &&
                  (_filter != 'unread' || app.unreadCount(e.id) > 0),
            )
            .toList();
    DateTime lastAt(String id) =>
        app.messagesByConv[id]?.lastOrNull?.timestamp ?? DateTime(1970);
    entries.sort((a, b) {
      final ap = app.settingsFor(a.id).pinned,
          bp = app.settingsFor(b.id).pinned;
      if (ap != bp) return ap ? -1 : 1;
      return lastAt(b.id).compareTo(lastAt(a.id));
    });
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forum_outlined, size: 36),
              const SizedBox(height: 12),
              Text(
                _query.isNotEmpty
                    ? 'Aucun résultat sur cet appareil.'
                    : _filter == 'archive'
                    ? 'Aucune conversation archivée.'
                    : 'Aucune conversation à afficher.',
              ),
              if (_filter == 'all' && _query.isEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Ajouter un premier contact'),
                  onPressed: () => _showPairDialog(context, app),
                ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i], s = app.settingsFor(entries[i].id);
        final last = app.messagesByConv[e.id]?.lastOrNull;
        return ListTile(
          selected:
              _wide &&
              (_selectedConversation?.id ?? _selectedGroup?.id) == e.id,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer
              .withValues(alpha: .45),
          leading: ChatAvatar(
            name: app.chatName(e.id),
            symbol: app.chatIcon(e.id),
            isGroup: e.group != null,
          ),
          title: Row(
            children: [
              if (s.pinned)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin, size: 14),
                ),
              Expanded(
                child: Text(
                  app.chatName(e.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text(
            last == null
                ? 'Commencer la conversation'
                : (last.fromMe ? 'Moi : ' : '') +
                      (last.isFile
                          ? 'Pièce jointe : ${last.fileName}'
                          : last.plaintext ?? 'Message'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (last != null)
                    Text(
                      DateFormat.Hm().format(last.timestamp),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  if (app.unreadCount(e.id) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Badge(label: Text('${app.unreadCount(e.id)}')),
                    ),
                ],
              ),
              ChatActionsMenu(app: app, chatId: e.id, isGroup: e.group != null),
            ],
          ),
          onTap: () => _openChat(conversation: e.contact, group: e.group),
        );
      },
    );
  }

  Widget _buildConversations(
    BuildContext context,
    AppState app, {
    bool contactsOnly = false,
  }) {
    final contacts =
        (contactsOnly ? app.conversations : app.visibleConversations)
            .where(
              (c) =>
                  app.matchesSearch(c.id, _query) &&
                  (contactsOnly ||
                      (c.localSettings.archived == (_filter == 'archive') &&
                          (_filter != 'unread' || app.unreadCount(c.id) > 0))),
            )
            .toList()
          ..sort((a, b) {
            if (a.localSettings.pinned != b.localSettings.pinned) {
              return a.localSettings.pinned ? -1 : 1;
            }
            return (b.lastMessageAt ?? b.createdAt).compareTo(
              a.lastMessageAt ?? a.createdAt,
            );
          });
    if (contacts.isEmpty) {
      return const Center(
        child: Text(
          'Aucune conversation à afficher.\nAjoute un contact ou modifie les filtres.',
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
          selected: _wide && _selectedConversation?.id == c.id,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer
              .withValues(alpha: .45),
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
              if (c.localSettings.pinned)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin, size: 14),
                ),
              if (app.unreadCount(c.id) > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Badge(label: Text('${app.unreadCount(c.id)}')),
                ),
              if (!contactsOnly && last != null)
                Text(
                  DateFormat.Hm().format(last.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ChatActionsMenu(app: app, chatId: c.id),
            ],
          ),
          onTap: () => _openChat(conversation: c),
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
    final filteredGroups =
        app.groups
            .where(
              (g) =>
                  app.matchesSearch(g.id, _query) &&
                  g.localSettings.archived == (_filter == 'archive'),
            )
            .toList()
          ..sort(
            (a, b) => a.localSettings.pinned == b.localSettings.pinned
                ? a.displayName.compareTo(b.displayName)
                : (a.localSettings.pinned ? -1 : 1),
          );
    for (final g in filteredGroups) {
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
          onTap: () => _openChat(group: g),
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
                    hintText: 'https://votre-relais.onrender.com',
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
    app.startPairing();
    showDialog<void>(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: app,
        builder: (ctx, _) => AlertDialog(
          title: const Text('Mon code d\'appairage'),
          scrollable: true,
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
              if (app.relay.myPairingCode != null) ...[
                const SizedBox(height: 12),
                SizedBox.square(
                  dimension: 196,
                  child: QrImageView(
                    data: PairingInvitation(
                      code: app.relay.myPairingCode!,
                      relay: app.relayUrl,
                      peerId: app.myId,
                    ).link,
                    size: 196,
                    backgroundColor: Colors.white,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copier l’invitation'),
                  onPressed: () => Clipboard.setData(
                    ClipboardData(
                      text: PairingInvitation(
                        code: app.relay.myPairingCode!,
                        relay: app.relayUrl,
                        peerId: app.myId,
                      ).link,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Donne ce code à ton contact (par un autre canal) pour créer une conversation chiffrée.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  app.startPairing();
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
              autocorrect: false,
              maxLength: 2048,
              decoration: InputDecoration(
                labelText: 'Code ou lien reçu du contact',
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)
                TextButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scanner un QR code'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _scan();
                  },
                ),
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
                          final message = await app.pairInvitation(code);
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
