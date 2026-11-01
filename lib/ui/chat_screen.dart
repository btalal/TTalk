import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../state/app_state.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.app, required this.conversation});

  final AppState app;
  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.app.markConversationRead(widget.conversation.id);
    });
    widget.app.addListener(_onAppChanged);
  }

  void _onAppChanged() {
    widget.app.markConversationRead(widget.conversation.id);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onAppChanged);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(AppState app) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    app.sendMessage(widget.conversation.id, text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final msgs = app.messagesByConv[widget.conversation.id] ?? [];
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => _build(context, app, msgs),
    );
  }

  Widget _build(BuildContext context, AppState app, List<ChatMessage> msgs) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conversation.peerName),
            Text(
              'Chiffré de bout en bout',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
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
                final mine = m.fromMe;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: mine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
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
                                Icons.done_all,
                                size: 14,
                                color: m.read
                                    ? Colors.blueAccent
                                    : Theme.of(context).textTheme.labelSmall?.color,
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
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

  void _showSafetyNumber(BuildContext context, AppState app) {
    final fp = app.safetyNumberFor(widget.conversation.id);
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
        ],
      ),
    );
  }
}
