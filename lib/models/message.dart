import 'dart:convert';

import 'chat_settings.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.fromMe,
    required this.ciphertext,
    required this.timestamp,
    this.plaintext,
    this.read = false,
    this.delivered = false,
    this.pending = false,
    this.senderId,
    this.isGroup = false,
    this.senderName,
    this.kind = 'text',
    this.fileName,
    this.fileSize,
    this.filePath,
    this.readBy = const [],
    this.replyToId,
    this.replyPreview,
    Map<String, String>? reactions,
    Map<String, int>? reactionVersions,
  }) : reactions = reactions ?? {},
       reactionVersions = reactionVersions ?? {};

  final String id;
  final String conversationId;
  final bool fromMe;
  final List<int> ciphertext;
  final DateTime timestamp;
  String? plaintext;
  bool read;
  bool delivered;
  bool pending;
  String? senderId;
  bool isGroup;
  String? senderName;
  String kind;
  String? fileName;
  int? fileSize;
  String? filePath;
  List<String> readBy;
  final String? replyToId;
  final String? replyPreview;
  final Map<String, String> reactions;
  final Map<String, int> reactionVersions;

  bool get isSystem => kind == 'system';

  bool get isFile => kind == 'file';

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'fromMe': fromMe,
    'ciphertext': base64Encode(ciphertext),
    'timestamp': timestamp.toIso8601String(),
    'read': read,
    'delivered': delivered,
    'pending': pending,
    if (senderId != null) 'senderId': senderId,
    'isGroup': isGroup,
    'kind': kind,
    'readBy': readBy,
    if (replyToId != null) 'replyToId': replyToId,
    if (replyPreview != null) 'replyPreview': replyPreview,
    'reactions': reactions,
    'reactionVersions': reactionVersions,
    if (plaintext != null) 'plaintext': plaintext,
    if (senderName != null) 'senderName': senderName,
    if (fileName != null) 'fileName': fileName,
    if (fileSize != null) 'fileSize': fileSize,
    if (filePath != null) 'filePath': filePath,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    fromMe: json['fromMe'] as bool,
    ciphertext: base64Decode(json['ciphertext'] as String),
    timestamp: DateTime.parse(json['timestamp'] as String),
    plaintext: json['plaintext'] as String?,
    read: json['read'] as bool? ?? false,
    replyToId: json['replyToId'] as String?,
    replyPreview: json['replyPreview'] as String?,
    reactions: json['reactions'] == null
        ? null
        : Map<String, String>.from(json['reactions'] as Map),
    reactionVersions: json['reactionVersions'] == null
        ? null
        : Map<String, int>.from(json['reactionVersions'] as Map),
    delivered: json['delivered'] as bool? ?? false,
    pending: json['pending'] as bool? ?? false,
    senderId: json['senderId'] as String?,
    isGroup: json['isGroup'] as bool? ?? false,
    senderName: json['senderName'] as String?,
    kind: json['kind'] as String? ?? 'text',
    fileName: json['fileName'] as String?,
    fileSize: json['fileSize'] as int?,
    filePath: json['filePath'] as String?,
    readBy:
        (json['readBy'] as List?)?.map((e) => e as String).toList() ?? const [],
  );
}

class Conversation {
  Conversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.peerPublicKey,
    required this.createdAt,
    this.lastMessageAt,
    ChatSettings? localSettings,
  }) : localSettings = localSettings ?? ChatSettings();

  final String id;
  final String peerId;
  final String peerName;
  final ChatSettings localSettings;
  String get displayName => localSettings.alias ?? peerName;
  final List<int> peerPublicKey;
  final DateTime createdAt;
  DateTime? lastMessageAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'peerId': peerId,
    'peerName': peerName,
    'localSettings': localSettings.toJson(),
    'peerPublicKey': base64Encode(peerPublicKey),
    'createdAt': createdAt.toIso8601String(),
    if (lastMessageAt != null)
      'lastMessageAt': lastMessageAt!.toIso8601String(),
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    peerId: json['peerId'] as String,
    peerName: json['peerName'] as String,
    localSettings: ChatSettings.fromJson(
      json['localSettings'] as Map<String, dynamic>?,
    ),
    peerPublicKey: base64Decode(json['peerPublicKey'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastMessageAt: json['lastMessageAt'] == null
        ? null
        : DateTime.parse(json['lastMessageAt'] as String),
  );
}
