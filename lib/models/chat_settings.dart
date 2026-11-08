import 'profile_icons.dart';

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

  /// Illustrated avatars are stored in [icon] as `avatar:<0-19>`, next to the
  /// legacy emoji icons, so existing vaults keep their format.
  static const avatarCount = 20;
  static const _avatarPrefix = 'avatar:';

  static String avatarIcon(int index) => '$_avatarPrefix$index';

  static int? avatarIndex(String? icon) {
    if (icon == null || !icon.startsWith(_avatarPrefix)) return null;
    final index = int.tryParse(icon.substring(_avatarPrefix.length));
    return index != null && index >= 0 && index < avatarCount ? index : null;
  }

  static bool isValidIcon(String icon) =>
      icons.contains(icon) ||
      avatarIndex(icon) != null ||
      ProfileIcons.find(icon) != null;

  /// Stable default illustration for a chat: same id, same avatar on every
  /// device (FNV-1a, independent of Dart's hashCode).
  static int defaultAvatarFor(String seed) {
    var hash = 0x811c9dc5;
    for (final unit in seed.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash % avatarCount;
  }

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
