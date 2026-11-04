/// Personal presentation and deletion markers; never sent to the relay.
class ChatSettings {
  ChatSettings({
    this.alias,
    this.icon,
    this.hidden = false,
    Set<String>? deletedMessageIds,
  }) : deletedMessageIds = deletedMessageIds ?? <String>{};

  String? alias;
  String? icon;
  bool hidden;
  final Set<String> deletedMessageIds;

  static const icons = [
    '👤',
    '👥',
    '💬',
    '🏠',
    '👪',
    '❤️',
    '⭐',
    '🎓',
    '📚',
    '💼',
    '💻',
    '🎮',
    '🎵',
    '⚽',
    '🌍',
    '🌿',
    '🐱',
    '🐶',
    '🚀',
    '🔒',
  ];

  Map<String, dynamic> toJson() => {
    if (alias != null) 'alias': alias,
    if (icon != null) 'icon': icon,
    'hidden': hidden,
    'deletedMessageIds': deletedMessageIds.toList(),
  };

  factory ChatSettings.fromJson(Map<String, dynamic>? json) => ChatSettings(
    alias: json?['alias'] as String?,
    icon: json?['icon'] as String?,
    hidden: json?['hidden'] as bool? ?? false,
    deletedMessageIds: (json?['deletedMessageIds'] as List?)
        ?.cast<String>()
        .toSet(),
  );
}
