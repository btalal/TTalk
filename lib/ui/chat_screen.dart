import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../crypto/e2e_crypto.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../state/app_state.dart';
import 'chat_actions.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.app,
    this.conversation,
    this.group,
    this.embedded = false,
  });

  final AppState app;
  final Conversation? conversation;
  final Group? group;
  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  ChatMessage? _replyTo;
  bool _searching = false;
  String _search = '';

  String get _chatId => widget.group?.id ?? widget.conversation!.id;
  bool get _isGroup => widget.group != null;
  String get _title => widget.app.chatName(
    _chatId,
    fallback: widget.group?.displayName ?? widget.conversation!.displayName,
  );

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
    if (_sending) return;
    final draft = _controller.text;
    final text = draft.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (_isGroup) {
        await app.sendGroupMessage(_chatId, text, replyTo: _replyTo);
      } else {
        await app.sendMessage(_chatId, text, replyTo: _replyTo);
      }
      if (!mounted) return;
      if (_controller.text == draft) {
        _controller.clear();
        setState(() => _replyTo = null);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
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
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _messageAction(ChatMessage message, String action) async {
    if (action == 'reply') {
      setState(() => _replyTo = message);
      return;
    }
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.plaintext ?? ''));
      return;
    }
    final confirmed = await confirmChatDeletion(
      context,
      'Supprimer ce message ?',
      'Le message sera supprimé uniquement sur cet appareil. Les copies des autres participants et les fichiers déjà enregistrés seront conservés. Un envoi déjà transmis au relais peut encore être livré.',
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.app.deleteMessage(_chatId, message.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de supprimer ce message. Réessaie.'),
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
    final visible = msgs
        .where(
          (m) =>
              _search.isEmpty ||
              (m.plaintext ?? '').toLowerCase().contains(
                _search.toLowerCase(),
              ) ||
              (m.fileName ?? '').toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Row(
          children: [
            ChatAvatar(
              name: _title,
              symbol: app.chatIcon(_chatId),
              isGroup: _isGroup,
              seed: _chatId,
              size: 38,
              verified: !_isGroup && app.isVerified(_chatId),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    _isGroup
                        ? '${app.groups.where((g) => g.id == _chatId).firstOrNull?.memberIds.length ?? 0} membres — chiffré de bout en bout'
                        : (app.isVerified(_chatId)
                              ? 'Contact vérifié · Chiffré de bout en bout'
                              : 'Chiffré · Contact à vérifier'),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Rechercher dans cette conversation',
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = !_searching),
          ),
          if (_isGroup && !widget.group!.requiresRecreation)
            IconButton(
              tooltip: 'Membres du groupe',
              icon: const Icon(Icons.group),
              onPressed: () => _showMembersSheet(context, app),
            )
          else if (!_isGroup)
            IconButton(
              tooltip: 'Numéro de sécurité',
              icon: const Icon(Icons.verified_user_outlined),
              onPressed: () => _showSafetyNumber(context, app),
            ),
          ChatActionsMenu(
            app: app,
            chatId: _chatId,
            isGroup: _isGroup,
            onRemoved: () {
              if (mounted && !widget.embedded) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searching)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Rechercher dans les messages',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Fermer la recherche',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _search = '';
                      _searching = false;
                    }),
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final m = visible[i];
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
                final scheme = Theme.of(context).colorScheme;
                final dark = Theme.of(context).brightness == Brightness.dark;
                final bubble = mine
                    ? (dark ? const Color(0xFF5B4FE0) : scheme.primary)
                    : scheme.surfaceContainerHigh;
                final ink = mine ? Colors.white : scheme.onSurface;
                final faint = mine
                    ? Colors.white.withValues(alpha: .78)
                    : scheme.onSurfaceVariant;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (i == 0 ||
                        DateUtils.dateOnly(visible[i - 1].timestamp) !=
                            DateUtils.dateOnly(m.timestamp))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(m.timestamp),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ),
                    Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => _showMessageMenu(m),
                        onSecondaryTap: () => _showMessageMenu(m),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: (MediaQuery.sizeOf(context).width * 0.75)
                                .clamp(200.0, 620.0),
                          ),
                          decoration: BoxDecoration(
                            color: bubble,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(mine ? 18 : 6),
                              bottomRight: Radius.circular(mine ? 6 : 18),
                            ),
                          ),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(color: ink),
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (m.isGroup && !mine)
                                Text(
                                  app.conversations
                                          .where((c) => c.peerId == m.senderId)
                                          .firstOrNull
                                          ?.displayName ??
                                      m.senderName ??
                                      '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              if (m.replyToId != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface
                                        .withValues(alpha: .55),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border(
                                      left: BorderSide(
                                        width: 3,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    m.replyPreview ?? 'Message cité',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
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
                                      Icon(Icons.attach_file, color: ink),
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
                                              '${formatFileSize(m.fileSize ?? 0)} — transfert chiffré',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(color: faint),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Text(m.plaintext ?? '🔒 message chiffré'),
                              if (m.reactions.isNotEmpty)
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    for (final emoji
                                        in m.reactions.values.toSet())
                                      ActionChip(
                                        label: Text(
                                          '$emoji ${m.reactions.values.where((v) => v == emoji).length}',
                                        ),
                                        onPressed:
                                            app.canReact(
                                              _chatId,
                                              isGroup: _isGroup,
                                            )
                                            ? () => _react(m, emoji)
                                            : null,
                                      ),
                                  ],
                                ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat.Hm().format(m.timestamp),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: faint),
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
                                          ? const Color(0xFF7DD3FC)
                                          : faint,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyTo != null)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.reply),
                    title: const Text('Répondre au message'),
                    subtitle: Text(
                      _replyTo!.plaintext ??
                          _replyTo!.fileName ??
                          'Pièce jointe',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Annuler la réponse',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _replyTo = null),
                    ),
                  ),
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
                          child: Focus(
                            onKeyEvent: (_, event) {
                              final desktop = [
                                TargetPlatform.macOS,
                                TargetPlatform.windows,
                                TargetPlatform.linux,
                              ].contains(defaultTargetPlatform);
                              if (desktop &&
                                  event is KeyDownEvent &&
                                  event.logicalKey ==
                                      LogicalKeyboardKey.enter &&
                                  !HardwareKeyboard.instance.isShiftPressed &&
                                  !_controller.value.composing.isValid) {
                                _send(app);
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 6,
                              keyboardType: TextInputType.multiline,
                              decoration: InputDecoration(
                                hintText: 'Message chiffré…',
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                                border: const OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(24),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Envoyer le message',
                          onPressed: _sending ? null : () => _send(app),
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _react(ChatMessage message, String emoji) async {
    try {
      await widget.app.react(_chatId, message.id, emoji, isGroup: _isGroup);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Réaction non enregistrée. Vérifie la compatibilité des contacts.',
            ),
          ),
        );
      }
    }
  }

  void _showMessageMenu(ChatMessage message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.app.canReact(_chatId, isGroup: _isGroup))
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final emoji in AppState.reactionEmojis)
                        ActionChip(
                          label: Text(emoji),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _react(message, emoji);
                          },
                        ),
                    ],
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Réactions : échange d’abord un message avec la version à jour de chaque contact.',
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Répondre'),
                onTap: () {
                  Navigator.pop(ctx);
                  _messageAction(message, 'reply');
                },
              ),
              if (!message.isFile)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copier le texte'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _messageAction(message, 'copy');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Supprimer pour moi'),
                onTap: () {
                  Navigator.pop(ctx);
                  _messageAction(message, 'delete');
                },
              ),
            ],
          ),
        ),
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
                  Text(
                    gg.displayName,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
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
                                  onPressed: () async {
                                    try {
                                      await app.removeMember(gg.id, id);
                                    } catch (error) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              error is StateError
                                                  ? error.message
                                                  : 'Retrait non enregistré.',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
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
                      final confirmed = await confirmChatDeletion(
                        ctx,
                        'Quitter le groupe ?',
                        'Le groupe et son historique seront supprimés de cet appareil. Les autres membres conserveront leurs messages.',
                      );
                      if (!confirmed || !ctx.mounted) return;
                      try {
                        await app.deleteGroup(gg.id);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) Navigator.of(context).pop();
                      } catch (_) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Impossible de quitter le groupe. Réessaie.',
                              ),
                            ),
                          );
                        }
                      }
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
                          title: Text(c.displayName),
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
              'Une comparaison par un canal fiable permet de vérifier les clés de votre contact.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await app.verifyContact(_chatId, !app.isVerified(_chatId));
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Vérification non enregistrée.'),
                    ),
                  );
                }
              }
            },
            child: Text(
              app.isVerified(_chatId)
                  ? 'Retirer la vérification'
                  : 'J’ai comparé et confirmé les numéros',
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
