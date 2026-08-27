import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/groups/data/datasources/group_remote_datasource.dart';
import 'package:loc_motos/features/groups/domain/entities/group_member.dart';
import 'package:loc_motos/features/groups/domain/entities/group_membership.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_group.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_role.dart';
import 'package:loc_motos/features/groups/domain/repositories/group_repository.dart';
import 'package:loc_motos/features/navigation/data/models/navigation_route_model.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';

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
  Future<void> setMemberAdmin({
    required AppUser actor,
    required String groupId,
    required String memberUid,
    required bool isAdmin,
  }) {
    return _remote.setMemberAdmin(
      actor: actor,
      groupId: groupId,
      memberUid: memberUid,
      isAdmin: isAdmin,
    );
  }

  @override
  Future<void> setMemberRideRole({
    required AppUser actor,
    required String groupId,
    required String memberUid,
    required RideRole? role,
  }) {
    return _remote.setMemberRideRole(
      actor: actor,
      groupId: groupId,
      memberUid: memberUid,
      role: role,
    );
  }

  @override
  Future<void> publishSharedRoute({
    required AppUser actor,
    required String groupId,
    required NavigationRoute route,
  }) {
    final model = route is NavigationRouteModel
        ? route
        : NavigationRouteModel(
            id: route.id,
            origin: route.origin,
            destination: route.destination,
            waypoints: route.waypoints,
            polyline: route.polyline,
            maneuvers: route.maneuvers,
            distanceMeters: route.distanceMeters,
            durationSeconds: route.durationSeconds,
            createdAt: route.createdAt,
            speedLimitKmh: route.speedLimitKmh,
            speedLimitSegments: route.speedLimitSegments,
            alerts: route.alerts,
            originLabel: route.originLabel,
            destinationLabel: route.destinationLabel,
          );
    return _remote.publishSharedRoute(
      actor: actor,
      groupId: groupId,
      route: model,
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

  @override
  Stream<NavigationRoute?> watchSharedRoute(String groupId) {
    return _remote.watchSharedRoute(groupId);
  }

  @override
  Stream<bool> watchHasSharedRoute(String groupId) {
    return _remote.watchHasSharedRoute(groupId);
  }
}
