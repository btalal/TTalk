import 'dart:convert';

class Group {
  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
    this.adminIds = const [],
    this.epoch = 1,
  });

  final String id;
  final String name;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;
  List<String> adminIds;
  int epoch;

  bool isAdmin(String peerId) => adminIds.contains(peerId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'memberIds': memberIds,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'adminIds': adminIds,
        'epoch': epoch,
      };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        memberIds: (json['memberIds'] as List).map((e) => e as String).toList(),
        createdBy: json['createdBy'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        adminIds: ((json['adminIds'] as List?) ?? []).map((e) => e as String).toList(),
        epoch: json['epoch'] as int? ?? 1,
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
    this.adminIds = const [],
    this.epoch = 1,
  });

  final String groupId;
  final String name;
  final String groupKeyB64;
  final List<String> memberIds;
  final String fromId;
  final String fromName;
  final List<String> adminIds;
  final int epoch;

  String toJsonString() => jsonEncode({
        'groupId': groupId,
        'name': name,
        'groupKeyB64': groupKeyB64,
        'memberIds': memberIds,
        'adminIds': adminIds,
        'epoch': epoch,
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
      adminIds: ((j['adminIds'] as List?) ?? []).map((e) => e as String).toList(),
      epoch: j['epoch'] as int? ?? 1,
      fromId: fromId,
      fromName: fromName,
    );
  }
}

class GroupControl {
  GroupControl({
    required this.kind,
    required this.groupId,
    required this.memberIds,
    required this.adminIds,
    required this.epoch,
    this.newGroupKeyB64,
    this.removedId,
  });

  final String kind;
  final String groupId;
  final List<String> memberIds;
  final List<String> adminIds;
  final int epoch;
  final String? newGroupKeyB64;
  final String? removedId;

  String toJsonString() => jsonEncode({
        'kind': kind,
        'groupId': groupId,
        'memberIds': memberIds,
        'adminIds': adminIds,
        'epoch': epoch,
        if (newGroupKeyB64 != null) 'newGroupKeyB64': newGroupKeyB64,
        if (removedId != null) 'removedId': removedId,
      });

  factory GroupControl.fromJsonString(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    return GroupControl(
      kind: j['kind'] as String,
      groupId: j['groupId'] as String,
      memberIds: (j['memberIds'] as List).map((e) => e as String).toList(),
      adminIds: ((j['adminIds'] as List?) ?? []).map((e) => e as String).toList(),
      epoch: j['epoch'] as int? ?? 1,
      newGroupKeyB64: j['newGroupKeyB64'] as String?,
      removedId: j['removedId'] as String?,
    );
  }
}
