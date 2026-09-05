import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/groups/domain/entities/group_member.dart';
import 'package:moto_amg/features/groups/domain/entities/group_membership.dart';
import 'package:moto_amg/features/groups/domain/entities/ride_group.dart';
import 'package:moto_amg/features/groups/domain/entities/ride_role.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';

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

  /// Borra el grupo por completo (solo el creador).
  Future<void> deleteGroup({
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

  Future<void> setMemberAdmin({
    required AppUser actor,
    required String groupId,
    required String memberUid,
    required bool isAdmin,
  });

  Future<void> setMemberRideRole({
    required AppUser actor,
    required String groupId,
    required String memberUid,
    required RideRole? role,
  });

  Future<void> publishSharedRoute({
    required AppUser actor,
    required String groupId,
    required NavigationRoute route,
  });

  Future<void> clearSharedRoute({
    required AppUser actor,
    required String groupId,
  });

  /// Activa o desactiva el intercom del grupo (solo el creador).
  Future<void> setGroupIntercomEnabled({
    required AppUser actor,
    required String groupId,
    required bool enabled,
  });

  Stream<RideGroup?> watchGroup(String groupId);

  Stream<List<GroupMember>> watchMembers(String groupId);

  Stream<List<GroupMembership>> watchMyGroups(String uid);

  Stream<NavigationRoute?> watchSharedRoute(String groupId);

  /// True si el grupo ya tiene documento de ruta compartida.
  Stream<bool> watchHasSharedRoute(String groupId);
}
