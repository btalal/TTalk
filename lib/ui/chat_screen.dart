import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../crypto/e2e_crypto.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../state/app_state.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.app,
    this.conversation,
    this.group,
  });

  final AppState app;
  final Conversation? conversation;
  final Group? group;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  String get _chatId => widget.group?.id ?? widget.conversation!.id;
  bool get _isGroup => widget.group != null;
  String get _title => widget.group?.name ?? widget.conversation!.peerName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markVisibleRead());
    widget.app.addListener(_onAppChanged);
  }

  void _markVisibleRead() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!mounted ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    widget.app.markConversationRead(_chatId);
  }

  void _onAppChanged() => _markVisibleRead();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _markVisibleRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.app.removeListener(_onAppChanged);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(AppState app) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      if (_isGroup) {
        await app.sendGroupMessage(_chatId, text);
      } else {
        await app.sendMessage(_chatId, text);
      }
      if (!mounted) return;
      _controller.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Envoi non enregistré. Vérifie l’espace disponible dans la file d’envoi.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickFile(AppState app) async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;
    try {
      await app.sendFile(_chatId, f.path!, f.name, f.size, isGroup: _isGroup);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pièce jointe non envoyée. Vérifie la connexion et la limite de 5 Mo.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) =>
          _build(context, app, app.messagesByConv[_chatId] ?? []),
    );
  }

  Widget _build(BuildContext context, AppState app, List<ChatMessage> msgs) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              _isGroup
                  ? '${app.groups.where((g) => g.id == _chatId).firstOrNull?.memberIds.length ?? 0} membres — chiffré de bout en bout'
                  : 'Chiffré de bout en bout',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_isGroup && !widget.group!.requiresRecreation)
            IconButton(
              tooltip: 'Membres du groupe',
              icon: const Icon(Icons.group),
              onPressed: () => _showMembersSheet(context, app),
            )
          else
            IconButton(
              tooltip: 'Numéro de sécurité',
              icon: const Icon(Icons.verified_user_outlined),
              onPressed: () => _showSafetyNumber(context, app),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: msgs.length,
              itemBuilder: (context, i) {
                final m = msgs[i];
                if (m.isSystem) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      m.plaintext ?? '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                final mine = m.fromMe;
                return Align(
                  alignment: mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: mine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (m.isGroup && !mine)
                          Text(
                            m.senderName ?? '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        if (m.isFile)
                          InkWell(
                            onTap: m.filePath == null
                                ? null
                                : () => OpenFilex.open(m.filePath!),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_file),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.fileName ?? 'fichier',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${formatFileSize(m.fileSize ?? 0)} — chiffré',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(m.plaintext ?? '🔒 message chiffré'),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat.Hm().format(m.timestamp),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            if (mine) ...[
                              const SizedBox(width: 4),
                              Icon(
                                m.pending
                                    ? Icons.schedule
                                    : m.delivered
                                    ? Icons.done_all
                                    : Icons.check,
                                size: 14,
                                color: m.read
                                    ? Colors.blueAccent
                                    : Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.color,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isGroup && widget.group!.requiresRecreation)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Ce groupe vient d’une ancienne version. Son historique est conservé ; recrée le groupe pour envoyer de nouveaux messages.',
              ),
            )
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Pièce jointe chiffrée',
                      onPressed: () => _pickFile(app),
                      icon: const Icon(Icons.attach_file),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Message chiffré…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (_) => _send(app),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _send(app),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMembersSheet(BuildContext context, AppState app) {
    final g = widget.group!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListenableBuilder(
        listenable: app,
        builder: (ctx, _) {
          final group = app.groups.where((e) => e.id == g.id).toList();
          if (group.isEmpty) {
            return const SizedBox(
              height: 120,
              child: Center(child: Text('Tu as quitté ce groupe.')),
            );
          }
          final gg = group.first;
          final admin = app.amAdmin(gg.id);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gg.name, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('${gg.memberIds.length} membres — époque ${gg.epoch}'),
                  const Divider(),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: gg.memberIds.map((id) {
                        final name = id == app.myId
                            ? 'Moi'
                            : (app.peerNameOf(id));
                        final isAdmin = gg.isAdmin(id);
                        final isMe = id == app.myId;
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(
                              name.isEmpty ? '?' : name[0].toUpperCase(),
                            ),
                          ),
                          title: Text(name + (isAdmin ? '  👑' : '')),
                          subtitle: Text(
                            gg.isOwner(id)
                                ? 'Propriétaire'
                                : (!gg.joinedMemberIds.contains(id)
                                      ? 'Invitation en attente'
                                      : (isAdmin
                                            ? 'Administrateur'
                                            : 'Membre')),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (gg.ownerId == app.myId &&
                                  !isMe &&
                                  gg.joinedMemberIds.contains(id))
                                IconButton(
                                  tooltip: 'Transférer la propriété',
                                  icon: const Icon(Icons.manage_accounts),
                                  onPressed: () => _confirmOwnershipTransfer(
                                    ctx,
                                    app,
                                    gg.id,
                                    id,
                                  ),
                                ),
                              if (admin && !isMe && !gg.isOwner(id))
                                IconButton(
                                  tooltip: 'Retirer du groupe',
                                  icon: const Icon(
                                    Icons.person_remove,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => app.removeMember(gg.id, id),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(),
                  if (admin)
                    ListTile(
                      leading: const Icon(Icons.person_add),
                      title: const Text('Réinviter / ajouter un membre'),
                      subtitle: const Text('Depuis tes contacts appairés'),
                      onTap: () => _showReinviteDialog(ctx, app, gg.id),
                    ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Quitter le groupe',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await app.leaveGroup(gg.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmOwnershipTransfer(
    BuildContext context,
    AppState app,
    String groupId,
    String peerId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transférer la propriété ?'),
        content: Text(
          '${app.peerNameOf(peerId)} deviendra propriétaire du groupe. '
          'Tu resteras membre et perdras tes droits d’administration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Transférer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await app.transferGroupOwnership(groupId, peerId);
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _showReinviteDialog(BuildContext ctx, AppState app, String groupId) {
    final candidates = app.conversations
        .where(
          (c) => !app.groups
              .firstWhere((g) => g.id == groupId)
              .memberIds
              .contains(c.peerId),
        )
        .toList();
    showDialog<void>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Ajouter un membre'),
        content: candidates.isEmpty
            ? const Text('Tous tes contacts sont déjà membres.')
            : SizedBox(
                width: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: candidates
                      .map(
                        (c) => ListTile(
                          dense: true,
                          title: Text(c.peerName),
                          trailing: const Icon(Icons.add),
                          onTap: () {
                            app.reInviteMember(groupId, c.peerId);
                            Navigator.of(dctx).pop();
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showSafetyNumber(BuildContext context, AppState app) {
    final fp = app.safetyNumberFor(widget.conversation!.id);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Numéro de sécurité'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              fp,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Compare ce numéro avec celui affiché sur l\'appareil de ton contact. '
              'S\'ils sont identiques, personne n\'intercepte vos messages.',
              textAlign: TextAlign.center,
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
    );
  }
}
