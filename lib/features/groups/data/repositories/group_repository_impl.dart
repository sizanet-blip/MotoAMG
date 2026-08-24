import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/groups/data/datasources/group_remote_datasource.dart';
import 'package:loc_motos/features/groups/domain/entities/group_member.dart';
import 'package:loc_motos/features/groups/domain/entities/group_membership.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_group.dart';
import 'package:loc_motos/features/groups/domain/repositories/group_repository.dart';

class GroupRepositoryImpl implements GroupRepository {
  GroupRepositoryImpl(this._remote);

  final GroupRemoteDataSource _remote;

  @override
  Future<RideGroup> createGroup({
    required AppUser user,
    required String name,
  }) {
    return _remote.createGroup(user: user, name: name);
  }

  @override
  Future<RideGroup> joinGroup({
    required AppUser user,
    required String code,
  }) {
    return _remote.joinGroup(user: user, code: code);
  }

  @override
  Future<void> leaveGroup({
    required AppUser user,
    required String groupId,
  }) {
    return _remote.leaveGroup(user: user, groupId: groupId);
  }

  @override
  Future<void> setActiveGroup({
    required String uid,
    required String? groupId,
  }) {
    return _remote.setActiveGroup(uid: uid, groupId: groupId);
  }

  @override
  Future<void> removeMember({
    required AppUser owner,
    required String groupId,
    required String memberUid,
  }) {
    return _remote.removeMember(
      owner: owner,
      groupId: groupId,
      memberUid: memberUid,
    );
  }

  @override
  Stream<RideGroup?> watchGroup(String groupId) {
    return _remote.watchGroup(groupId);
  }

  @override
  Stream<List<GroupMember>> watchMembers(String groupId) {
    return _remote.watchMembers(groupId);
  }

  @override
  Stream<List<GroupMembership>> watchMyGroups(String uid) {
    return _remote.watchMyGroups(uid);
  }
}
