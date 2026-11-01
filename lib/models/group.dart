import 'dart:convert';

class Group {
  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'memberIds': memberIds,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        memberIds: (json['memberIds'] as List).map((e) => e as String).toList(),
        createdBy: json['createdBy'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class GroupInvite {
  GroupInvite({
    required this.groupId,
    required this.name,
    required this.groupKeyB64,
    required this.memberIds,
    required this.fromId,
    required this.fromName,
  });

  final String groupId;
  final String name;
  final String groupKeyB64;
  final List<String> memberIds;
  final String fromId;
  final String fromName;

  String toJsonString() => jsonEncode({
        'groupId': groupId,
        'name': name,
        'groupKeyB64': groupKeyB64,
        'memberIds': memberIds,
        'fromId': fromId,
        'fromName': fromName,
      });

  factory GroupInvite.fromJsonString(String s, {required String fromId, required String fromName}) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    return GroupInvite(
      groupId: j['groupId'] as String,
      name: j['name'] as String,
      groupKeyB64: j['groupKeyB64'] as String,
      memberIds: (j['memberIds'] as List).map((e) => e as String).toList(),
      fromId: fromId,
      fromName: fromName,
    );
  }
}
