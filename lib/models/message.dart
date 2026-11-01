import 'dart:convert';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.fromMe,
    required this.ciphertext,
    required this.timestamp,
    this.plaintext,
    this.read = false,
  });

  final String id;
  final String conversationId;
  final bool fromMe;
  final List<int> ciphertext;
  final DateTime timestamp;
  String? plaintext;
  bool read;

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'fromMe': fromMe,
        'ciphertext': base64Encode(ciphertext),
        'timestamp': timestamp.toIso8601String(),
        'read': read,
        if (plaintext != null) 'plaintext': plaintext,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        fromMe: json['fromMe'] as bool,
        ciphertext: base64Decode(json['ciphertext'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        plaintext: json['plaintext'] as String?,
        read: json['read'] as bool? ?? false,
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
  });

  final String id;
  final String peerId;
  final String peerName;
  final List<int> peerPublicKey;
  final DateTime createdAt;
  DateTime? lastMessageAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerId': peerId,
        'peerName': peerName,
        'peerPublicKey': base64Encode(peerPublicKey),
        'createdAt': createdAt.toIso8601String(),
        if (lastMessageAt != null)
          'lastMessageAt': lastMessageAt!.toIso8601String(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        peerId: json['peerId'] as String,
        peerName: json['peerName'] as String,
        peerPublicKey: base64Decode(json['peerPublicKey'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastMessageAt: json['lastMessageAt'] == null
            ? null
            : DateTime.parse(json['lastMessageAt'] as String),
      );
}
