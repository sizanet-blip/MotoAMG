import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/groups/domain/entities/group_member.dart';
import 'package:loc_motos/features/groups/domain/entities/group_membership.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_group.dart';

abstract class GroupRepository {
  Future<RideGroup> createGroup({
    required AppUser user,
    required String name,
  });

  Future<RideGroup> joinGroup({
    required AppUser user,
    required String code,
  });

  Future<void> leaveGroup({
    required AppUser user,
    required String groupId,
  });

  Future<void> setActiveGroup({
    required String uid,
    required String? groupId,
  });

  Future<void> removeMember({
    required AppUser owner,
    required String groupId,
    required String memberUid,
  });

  Stream<RideGroup?> watchGroup(String groupId);

  Stream<List<GroupMember>> watchMembers(String groupId);

  Stream<List<GroupMembership>> watchMyGroups(String uid);
}

