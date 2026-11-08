import 'package:flutter/material.dart';

import '../models/chat_settings.dart';
import '../state/app_state.dart';
import 'avatar_art.dart';
import 'emoji_symbol.dart';

/// Illustrated avatar of a contact or group. A legacy emoji icon is still
/// shown as an emoji; without any choice the illustration comes from [seed].
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    this.symbol,
    this.isGroup = false,
    this.seed,
    this.size = 40,
    this.verified = false,
  });
  final String name;
  final String? symbol;
  final bool isGroup;
  final String? seed;
  final double size;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final index = ChatSettings.avatarIndex(symbol);
    final Widget picture = symbol != null && index == null
        ? CircleAvatar(
            radius: size / 2,
            child: EmojiSymbol(symbol!, fontSize: size * .5),
          )
        : AvatarArt(
            index: index ?? ChatSettings.defaultAvatarFor(seed ?? name),
            group: isGroup,
            size: size,
          );
    return Semantics(
      label: verified ? '$name, contact vérifié' : name,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            picture,
            if (verified)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: size * .4,
                  height: size * .4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Icon(
                    Icons.verified_user,
                    size: size * .3,
                    color: const Color(0xFF34D399),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmChatDeletion(
  BuildContext context,
  String title,
  String description,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmer la suppression'),
          ),
        ],
      ),
    ) ??
    false;

class ChatActionsMenu extends StatelessWidget {
  const ChatActionsMenu({
    super.key,
    required this.app,
    required this.chatId,
    this.isGroup = false,
    this.onRemoved,
  });
  final AppState app;
  final String chatId;
  final bool isGroup;
  final VoidCallback? onRemoved;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: isGroup ? 'Actions du groupe' : 'Actions du contact',
    icon: const Icon(Icons.more_horiz),
    onSelected: (action) async {
      if (action == 'pin' || action == 'archive') {
        try {
          final s = app.settingsFor(chatId);
          await app.setChatFlag(
            chatId,
            pinned: action == 'pin' ? !s.pinned : null,
            archived: action == 'archive' ? !s.archived : null,
          );
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Modification non enregistrée.')),
            );
          }
        }
        return;
      }
      if (action == 'customize') {
        await showChatCustomization(context, app, chatId);
        return;
      }
      final title = switch (action) {
        'clear' => 'Effacer l’historique ?',
        'contact' => 'Supprimer le contact ?',
        'group' => 'Quitter et supprimer le groupe ?',
        _ => 'Supprimer la conversation ?',
      };
      final explanation = switch (action) {
        'contact' => 'Le contact et sa conversation seront supprimés de cet appareil. Les groupes communs seront conservés. Pour lui écrire de nouveau, il faudra vous appairer à nouveau.',
        'group' => 'Vous quitterez ce groupe et son historique sera supprimé de cet appareil. Les autres membres conserveront le groupe. Si vous êtes propriétaire, la propriété sera transmise à un autre membre restant.',
        'clear' => 'Les messages seront effacés uniquement sur cet appareil. Vous conserverez le contact ou le groupe.',
        _ => 'L’historique sera effacé sur cet appareil. Le contact restera accessible dans l’onglet Contacts.',
      };
      final confirmed = await confirmChatDeletion(
        context,
        title,
        '$explanation\n\nLes copies des autres participants et les fichiers déjà enregistrés seront conservés. Les envois non transmis seront annulés ; ceux déjà confiés au relais peuvent encore être livrés.',
      );
      if (!confirmed || !context.mounted) return;
      try {
        switch (action) {
          case 'contact':
            await app.deleteContact(chatId);
          case 'group':
            await app.deleteGroup(chatId);
          case 'clear':
            await app.clearHistory(chatId);
          default:
            await app.deleteConversation(chatId);
        }
        if (context.mounted && action != 'clear') onRemoved?.call();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Suppression impossible. Vérifie le stockage et réessaie.',
              ),
            ),
          );
        }
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(
        value: 'pin',
        child: ListTile(
          leading: const Icon(Icons.push_pin_outlined),
          title: Text(
            app.settingsFor(chatId).pinned ? 'Désépingler' : 'Épingler',
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'archive',
        child: ListTile(
          leading: const Icon(Icons.archive_outlined),
          title: Text(
            app.settingsFor(chatId).archived ? 'Désarchiver' : 'Archiver',
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: 'customize',
        child: ListTile(
          leading: Icon(Icons.edit_outlined),
          title: Text('Nom et icône'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      if (isGroup) ...[
        const PopupMenuItem(
          value: 'clear',
          child: ListTile(
            leading: Icon(Icons.cleaning_services_outlined),
            title: Text('Effacer l’historique'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'group',
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Quitter et supprimer'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ] else ...[
        const PopupMenuItem(
          value: 'conversation',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Supprimer la conversation'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'contact',
          child: ListTile(
            leading: Icon(Icons.person_remove_outlined),
            title: Text('Supprimer le contact'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ],
  );
}

Future<void> showChatCustomization(
  BuildContext context,
  AppState app,
  String chatId,
) async {
  final controller = TextEditingController(text: app.chatName(chatId));
  final isGroup = app.groups.any((g) => g.id == chatId);
  String? symbol = app.chatIcon(chatId);
  String? error;
  bool busy = false;
  try {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Nom et icône'),
          scrollable: true,
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Personnalisation visible uniquement sur cet appareil.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  enabled: !busy,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: 'Nom affiché',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Par défaut'),
                      selected: symbol == null,
                      onSelected: busy
                          ? null
                          : (_) => update(() => symbol = null),
                    ),
                    ...ChatSettings.icons.map(
                      (icon) => ChoiceChip(
                        label: EmojiSymbol(icon, fontSize: 22),
                        selected: symbol == icon,
                        onSelected: busy
                            ? null
                            : (_) => update(() => symbol = icon),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ou une illustration',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < ChatSettings.avatarCount; i++)
                      Semantics(
                        button: true,
                        selected: symbol == ChatSettings.avatarIcon(i),
                        label: '${isGroup ? 'Avatar de groupe' : 'Avatar'} ${i + 1}',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: busy
                              ? null
                              : () => update(
                                  () => symbol = ChatSettings.avatarIcon(i),
                                ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                width: 2,
                                color: symbol == ChatSettings.avatarIcon(i)
                                    ? Theme.of(ctx).colorScheme.primary
                                    : Colors.transparent,
                              ),
                            ),
                            child: AvatarArt(
                              index: i,
                              group: isGroup,
                              size: 52,
                            ),
                          ),
                        ),
                      ),
                  ],
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
                      if (busy) return;
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        update(() => error = 'Indique un nom.');
                        return;
                      }
                      update(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await app.setChatAppearance(
                          chatId,
                          name: name,
                          icon: symbol,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (_) {
                        if (ctx.mounted) {
                          update(() {
                            busy = false;
                            error =
                                'Personnalisation non enregistrée. Réessaie.';
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Enregistrement…' : 'Enregistrer'),
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
