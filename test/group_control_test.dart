import 'package:flutter_test/flutter_test.dart';

import 'package:ttalk/models/group.dart';
import 'package:ttalk/models/message.dart';

void main() {
  Group group({List<String> joined = const ['alice', 'bob']}) => Group(
        id: 'group',
        name: 'Amis',
        memberIds: ['alice', 'bob', 'carol'],
        createdBy: 'alice',
        createdAt: DateTime(2026),
        adminIds: ['alice'],
        ownerId: 'alice',
        joinedMemberIds: joined,
      );

  GroupControl control(String kind,
          {String? owner,
          String? member,
          String? removed,
          String? key,
          int epoch = 1,
          String id = 'group'}) =>
      GroupControl(
        kind: kind,
        groupId: id,
        memberIds: ['alice', 'bob', 'carol'],
        adminIds: ['alice'],
        epoch: epoch,
        ownerId: owner,
        memberId: member,
        memberName: 'Carole',
        removedId: removed,
        newGroupKeyB64: key,
      );

  test(
      'owner transfers to an accepted member, loses admin rights, and persists',
      () {
    final g = group();
    final transfer = control('transfer', owner: 'bob');
    final updated = g.applyControl(transfer, senderId: 'alice')!;
    expect(updated.ownerId, 'bob');
    expect(updated.createdBy, 'alice');
    expect(updated.memberIds, g.memberIds);
    expect(updated.isAdmin('bob'), isTrue);
    expect(updated.isAdmin('alice'), isFalse);
    expect(Group.fromJson(updated.toJson()).ownerId, 'bob');
    expect(updated.applyControl(transfer, senderId: 'alice'), isNull);
  });

  test('rejects unauthorized, pending, missing, self and cross-group transfers',
      () {
    final g = group();
    expect(g.applyControl(control('transfer', owner: 'bob'), senderId: 'carol'),
        isNull);
    for (final next in ['carol', 'outsider', 'alice']) {
      expect(
          g.applyControl(control('transfer', owner: next), senderId: 'alice'),
          isNull);
    }
    expect(
        g.applyControl(control('transfer', owner: 'bob', id: 'other'),
            senderId: 'alice'),
        isNull);
  });

  test('join requires the invited sender and is deduplicated after persistence',
      () {
    final g = group();
    final join = control('join', member: 'carol');
    expect(g.applyControl(join, senderId: 'bob'), isNull);
    expect(g.applyControl(join, senderId: 'outsider'), isNull);
    final updated = g.applyControl(join, senderId: 'carol')!;
    expect(updated.joinedMemberIds, ['alice', 'bob', 'carol']);
    expect(updated.ownerId, 'alice');
    final restored = Group.fromJson(updated.toJson());
    expect(restored.applyControl(join, senderId: 'carol'), isNull);
    expect(
        restored
            .applyControl(control('transfer', owner: 'carol'),
                senderId: 'alice')!
            .ownerId,
        'carol');
  });

  test('join rejects stale and future epochs without changing the group', () {
    for (final epoch in [0, 2]) {
      expect(
          group().applyControl(control('join', member: 'carol', epoch: epoch),
              senderId: 'carol'),
          isNull);
    }
    expect(group().joinedMemberIds, ['alice', 'bob']);
  });

  test('ownership survives invitations sent by another administrator', () {
    final invite = GroupInvite(
      groupId: 'group',
      name: 'Amis',
      groupKeyB64: 'key',
      memberIds: ['alice', 'bob'],
      fromId: 'carol',
      fromName: 'Carole',
      adminIds: ['alice', 'carol'],
      ownerId: 'alice',
      joinedMemberIds: ['alice'],
    );
    final decoded = GroupInvite.fromJsonString(invite.toJsonString(),
        fromId: 'carol', fromName: 'Carole');
    expect(decoded.ownerId, 'alice');
    expect(decoded.joinedMemberIds, ['alice']);
  });

  test('legacy groups retain a valid owner when their creator has left', () {
    final json = group().toJson()
      ..remove('ownerId')
      ..remove('joinedMemberIds');
    json['adminIds'] = ['bob'];
    final legacy = Group.fromJson(json);
    expect(legacy.ownerId, 'bob');
    expect(legacy.joinedMemberIds, legacy.memberIds);
  });

  test('owner departure promotes a remaining accepted member at the same epoch',
      () {
    final updated = group()
        .applyControl(control('leave', removed: 'alice'), senderId: 'alice')!;
    expect(updated.ownerId, 'bob');
    expect(updated.adminIds, ['bob']);
    expect(updated.joinedMemberIds, ['bob']);
    expect(updated.memberIds, ['bob', 'carol']);
  });

  test('members cannot change membership and admins cannot remove the owner',
      () {
    expect(group().applyControl(control('members'), senderId: 'bob'), isNull);
    expect(
        group().applyControl(
            control('remove', removed: 'alice', key: 'key', epoch: 2),
            senderId: 'alice'),
        isNull);
    final removed = group().applyControl(
        control('remove', removed: 'bob', key: 'key', epoch: 2),
        senderId: 'alice')!;
    expect(removed.memberIds, ['alice', 'carol']);
    expect(removed.joinedMemberIds, ['alice']);
    expect(
        removed.applyControl(control('join', member: 'bob', epoch: 2),
            senderId: 'bob'),
        isNull);
  });

  test('encrypted control data and local system events round trip', () {
    final decoded = GroupControl.fromJsonString(
        control('join', member: 'carol').toJsonString());
    expect(decoded.memberId, 'carol');
    expect(decoded.memberName, 'Carole');
    final transfer = GroupControl.fromJsonString(
        control('transfer', owner: 'bob').toJsonString());
    expect(transfer.ownerId, 'bob');
    final event = ChatMessage(
      id: 'event',
      conversationId: 'group',
      fromMe: false,
      ciphertext: [],
      timestamp: DateTime(2026),
      plaintext: 'Carole a rejoint le groupe.',
      kind: 'system',
      isGroup: true,
      read: true,
    );
    final restored = ChatMessage.fromJson(event.toJson());
    expect(restored.isSystem, isTrue);
    expect(restored.plaintext, event.plaintext);
  });
}
