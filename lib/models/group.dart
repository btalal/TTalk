import 'dart:convert';

import 'chat_settings.dart';

class Group {
  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
    this.adminIds = const [],
    this.epoch = 1,
    this.requiresRecreation = false,
    this.ownershipVersion = 0,
    String? ownerId,
    List<String>? joinedMemberIds,
    ChatSettings? localSettings,
  }) : localSettings = localSettings ?? ChatSettings(),
       ownerId =
           ownerId ??
           (adminIds.contains(createdBy) || adminIds.isEmpty
               ? createdBy
               : adminIds.first),
       joinedMemberIds = joinedMemberIds ?? List.of(memberIds);

  final bool requiresRecreation;
  final int ownershipVersion;
  final String id;
  final String name;
  final ChatSettings localSettings;
  String get displayName => localSettings.alias ?? name;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;
  final String ownerId;
  final List<String> joinedMemberIds;
  List<String> adminIds;
  int epoch;

  bool isOwner(String peerId) => ownerId == peerId;

  bool isAdmin(String peerId) => adminIds.contains(peerId);

  /// Returns null for stale, unauthorized or duplicate control messages.
  Group? applyControl(GroupControl control, {required String senderId}) {
    if (requiresRecreation ||
        control.groupId != id ||
        !memberIds.contains(senderId) ||
        control.epoch < epoch) {
      return null;
    }
    var members = List<String>.of(memberIds);
    var admins = List<String>.of(adminIds);
    var joined = List<String>.of(joinedMemberIds);
    var owner = ownerId;
    switch (control.kind) {
      case 'join':
        if (control.epoch != epoch ||
            control.memberId != senderId ||
            joined.contains(senderId)) {
          return null;
        }
        joined.add(senderId);
        break;
      case 'transfer':
        final next = control.ownerId;
        if (control.epoch != epoch ||
            !isOwner(senderId) ||
            control.ownerVersion != ownershipVersion + 1 ||
            next == null ||
            next == ownerId ||
            !members.contains(next) ||
            !joined.contains(next)) {
          return null;
        }
        owner = next;
        admins = {...admins.where((id) => id != senderId), next}.toList();
        break;
      case 'members':
        if (control.epoch != epoch ||
            !isAdmin(senderId) ||
            !control.memberIds.toSet().containsAll(members)) {
          return null;
        }
        members = control.memberIds.toSet().toList();
        break;
      case 'sync':
        if (control.epoch != epoch ||
            !isOwner(senderId) ||
            control.joinedMemberIds == null ||
            !control.memberIds.toSet().containsAll(members) ||
            !control.memberIds.toSet().containsAll(control.joinedMemberIds!)) {
          return null;
        }
        members = control.memberIds.toSet().toList();
        joined = {...joined, ...control.joinedMemberIds!}.toList();
        break;
      case 'remove':
        if (!isAdmin(senderId) ||
            control.epoch != epoch + 1 ||
            control.newGroupKeyB64 == null ||
            control.removedId == ownerId ||
            !members.contains(control.removedId)) {
          return null;
        }
        members.remove(control.removedId);
        admins.remove(control.removedId);
        joined.remove(control.removedId);
        break;
      case 'leave':
        if (control.epoch != epoch || control.removedId != senderId) {
          return null;
        }
        members.remove(senderId);
        admins.remove(senderId);
        joined.remove(senderId);
        if (members.isNotEmpty) {
          if (admins.isEmpty) {
            admins.add(joined.isNotEmpty ? joined.first : members.first);
          }
          if (owner == senderId) owner = admins.first;
        }
        break;
      default:
        return null;
    }
    return Group(
      id: id,
      name: name,
      memberIds: members,
      createdBy: createdBy,
      createdAt: createdAt,
      adminIds: admins,
      epoch: control.epoch,
      ownerId: owner,
      ownershipVersion: control.kind == 'transfer'
          ? control.ownerVersion!
          : ownershipVersion,
      joinedMemberIds: joined,
      localSettings: localSettings,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'requiresRecreation': requiresRecreation,
    'localSettings': localSettings.toJson(),
    'ownershipVersion': ownershipVersion,
    'name': name,
    'memberIds': memberIds,
    'createdBy': createdBy,
    'ownerId': ownerId,
    'joinedMemberIds': joinedMemberIds,
    'createdAt': createdAt.toIso8601String(),
    'adminIds': adminIds,
    'epoch': epoch,
  };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'] as String,
    requiresRecreation: json['requiresRecreation'] as bool? ?? false,
    localSettings: ChatSettings.fromJson(
      json['localSettings'] as Map<String, dynamic>?,
    ),
    ownershipVersion: json['ownershipVersion'] as int? ?? 0,
    name: json['name'] as String,
    memberIds: (json['memberIds'] as List).map((e) => e as String).toList(),
    createdBy: json['createdBy'] as String,
    ownerId: json['ownerId'] as String?,
    joinedMemberIds: (json['joinedMemberIds'] as List?)?.cast<String>(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    adminIds: ((json['adminIds'] as List?) ?? [])
        .map((e) => e as String)
        .toList(),
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
    this.ownerId,
    this.ownershipVersion = 0,
    this.joinedMemberIds,
  });

  final String groupId;
  final String name;
  final String groupKeyB64;
  final List<String> memberIds;
  final String fromId;
  final String fromName;
  final List<String> adminIds;
  final int epoch;
  final String? ownerId;
  final int ownershipVersion;
  final List<String>? joinedMemberIds;

  String toJsonString() => jsonEncode({
    'groupId': groupId,
    'name': name,
    'groupKeyB64': groupKeyB64,
    'memberIds': memberIds,
    'adminIds': adminIds,
    'epoch': epoch,
    if (ownerId != null) 'ownerId': ownerId,
    'ownershipVersion': ownershipVersion,
    if (joinedMemberIds != null) 'joinedMemberIds': joinedMemberIds,
    'fromId': fromId,
    'fromName': fromName,
  });

  factory GroupInvite.fromJsonString(
    String s, {
    required String fromId,
    required String fromName,
  }) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    return GroupInvite(
      groupId: j['groupId'] as String,
      name: j['name'] as String,
      groupKeyB64: j['groupKeyB64'] as String,
      memberIds: (j['memberIds'] as List).map((e) => e as String).toList(),
      adminIds: ((j['adminIds'] as List?) ?? [])
          .map((e) => e as String)
          .toList(),
      epoch: j['epoch'] as int? ?? 1,
      ownerId: j['ownerId'] as String?,
      ownershipVersion: j['ownershipVersion'] as int? ?? 0,
      joinedMemberIds: (j['joinedMemberIds'] as List?)?.cast<String>(),
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
    this.ownerId,
    this.ownerVersion,
    this.memberId,
    this.memberName,
    this.joinedMemberIds,
  });

  final String kind;
  final String groupId;
  final List<String> memberIds;
  final List<String> adminIds;
  final int epoch;
  final String? newGroupKeyB64;
  final String? removedId;
  final String? ownerId;
  final int? ownerVersion;
  final String? memberId;
  final String? memberName;
  final List<String>? joinedMemberIds;

  String toJsonString() => jsonEncode({
    'kind': kind,
    'groupId': groupId,
    'memberIds': memberIds,
    'adminIds': adminIds,
    'epoch': epoch,
    if (newGroupKeyB64 != null) 'newGroupKeyB64': newGroupKeyB64,
    if (removedId != null) 'removedId': removedId,
    if (ownerId != null) 'ownerId': ownerId,
    if (ownerVersion != null) 'ownerVersion': ownerVersion,
    if (memberId != null) 'memberId': memberId,
    if (memberName != null) 'memberName': memberName,
    if (joinedMemberIds != null) 'joinedMemberIds': joinedMemberIds,
  });

  factory GroupControl.fromJsonString(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    return GroupControl(
      kind: j['kind'] as String,
      groupId: j['groupId'] as String,
      memberIds: (j['memberIds'] as List).map((e) => e as String).toList(),
      adminIds: ((j['adminIds'] as List?) ?? [])
          .map((e) => e as String)
          .toList(),
      epoch: j['epoch'] as int? ?? 1,
      newGroupKeyB64: j['newGroupKeyB64'] as String?,
      removedId: j['removedId'] as String?,
      ownerId: j['ownerId'] as String?,
      ownerVersion: j['ownerVersion'] as int?,
      memberId: j['memberId'] as String?,
      memberName: j['memberName'] as String?,
      joinedMemberIds: (j['joinedMemberIds'] as List?)?.cast<String>(),
    );
  }
}
