import 'dart:convert';
import 'dart:typed_data';

class OutboundPacket {
  OutboundPacket({
    required this.id,
    required this.type,
    required this.recipients,
    required this.payload,
    this.groupId,
  });
  final String id;
  final String type;
  final List<String> recipients;
  final Uint8List payload;
  final String? groupId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'recipients': recipients,
    'payload': base64Encode(payload),
    'groupId': groupId,
  };
  factory OutboundPacket.fromJson(Map<String, dynamic> json) => OutboundPacket(
    id: json['id'] as String,
    type: json['type'] as String,
    recipients: (json['recipients'] as List).cast<String>().toList(),
    payload: base64Decode(json['payload'] as String),
    groupId: json['groupId'] as String?,
  );
}
