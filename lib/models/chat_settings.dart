/// Personal presentation and deletion markers; never sent to the relay.
class ChatSettings {
  ChatSettings({
    this.alias,
    this.icon,
    this.hidden = false,
    this.pinned = false,
    this.archived = false,
    this.verifiedFingerprint,
    Set<String>? features,
    Set<String>? deletedMessageIds,
  }) : features = features ?? <String>{},
       deletedMessageIds = deletedMessageIds ?? <String>{};

  String? alias;
  String? icon;
  bool hidden;
  bool pinned;
  bool archived;
  String? verifiedFingerprint;
  final Set<String> features;
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
    'pinned': pinned,
    'features': features.toList(),
    'archived': archived,
    if (verifiedFingerprint != null) 'verifiedFingerprint': verifiedFingerprint,
    'deletedMessageIds': deletedMessageIds.toList(),
  };

  factory ChatSettings.fromJson(Map<String, dynamic>? json) => ChatSettings(
    alias: json?['alias'] as String?,
    icon: json?['icon'] as String?,
    hidden: json?['hidden'] as bool? ?? false,
    features: (json?['features'] as List?)?.cast<String>().toSet(),
    pinned: json?['pinned'] as bool? ?? false,
    archived: json?['archived'] as bool? ?? false,
    verifiedFingerprint: json?['verifiedFingerprint'] as String?,
    deletedMessageIds: (json?['deletedMessageIds'] as List?)
        ?.cast<String>()
        .toSet(),
  );
}
