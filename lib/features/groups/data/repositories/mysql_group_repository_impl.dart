import 'package:moto_amg/core/api/motoamg_api_client.dart';
import 'package:moto_amg/features/auth/data/datasources/mysql_club_group_remote_datasource.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/groups/domain/entities/group_member.dart';
import 'package:moto_amg/features/groups/domain/entities/group_membership.dart';
import 'package:moto_amg/features/groups/domain/entities/ride_group.dart';
import 'package:moto_amg/features/groups/domain/entities/ride_role.dart';
import 'package:moto_amg/features/groups/domain/exceptions/group_exceptions.dart';
import 'package:moto_amg/features/groups/domain/repositories/group_repository.dart';
import 'package:moto_amg/features/navigation/data/models/navigation_route_model.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';

class MysqlGroupRepositoryImpl implements GroupRepository {
  MysqlGroupRepositoryImpl(this._remote);

  final MysqlGroupRemoteDataSource _remote;

  GroupException _map(Object error) {
    if (error is GroupException) return error;
    if (error is MotoAmgApiException) {
      return GroupException(error.message);
    }
    return GroupException(error.toString());
  }

  RideGroup _mapGroup(Map<String, dynamic> g, {String? fallbackOwnerUid}) {
    final ownerUid = g['ownerUid']?.toString();
    final adminRaw = g['adminUids'];
    final adminUids = <String>[
      if (adminRaw is List)
        for (final item in adminRaw)
          if ('$item'.isNotEmpty) '$item',
    ];
    return RideGroup(
      id: '${g['id']}',
      name: '${g['name'] ?? 'Grupo'}',
      code: '${g['code'] ?? ''}',
      ownerId: (ownerUid != null && ownerUid.isNotEmpty)
          ? ownerUid
          : (fallbackOwnerUid ?? '${g['ownerUserId'] ?? ''}'),
      createdAt: DateTime.now(),
      isActive: g['isActive'] != false && '${g['isActive']}' != '0',
      adminUids: adminUids,
      intercomEnabled: g['intercomEnabled'] == true ||
          '${g['intercomEnabled']}' == '1',
      clubId: g['clubId'] == null ? null : '${g['clubId']}',
    );
  }

  GroupMember _mapMember(Map<String, dynamic> m) {
    return GroupMember(
      uid: '${m['uid']}',
      displayName: '${m['displayName'] ?? m['uid']}',
      joinedAt: DateTime.now(),
      rideRole: RideRoleX.tryParse(m['rideRole']?.toString()),
    );
  }

  @override
  Future<RideGroup> createGroup({
    required AppUser user,
    required String name,
  }) async {
    if (user.currentClubId == null || user.currentClubId!.isEmpty) {
      throw const GroupException(
        'Necesitas pertenecer a un club para crear un grupo de ruta.',
      );
    }
    try {
      final raw = await _remote.createGroup(name: name.trim());
      return _mapGroup(raw, fallbackOwnerUid: user.uid);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<RideGroup> joinGroup({
    required AppUser user,
    required String code,
  }) async {
    try {
      final raw = await _remote.joinGroup(
        code: code.trim().toUpperCase().replaceAll(' ', ''),
      );
      return _mapGroup(raw);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> leaveGroup({
    required AppUser user,
    required String groupId,
  }) async {
    try {
      await _remote.leaveGroup(groupId);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> deleteGroup({
    required AppUser user,
    required String groupId,
  }) async {
    try {
      await _remote.deleteGroup(groupId);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> setActiveGroup({
    required String uid,
    required String? groupId,
  }) async {
    // La app guarda currentGroupId en signedInUserProvider.
  }

  @override
  Future<void> removeMember({
    required AppUser owner,
    required String groupId,
    required String memberUid,
  }) async {
    try {
      await _remote.removeMember(groupId: groupId, memberUid: memberUid);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> setMemberAdmin({
    required AppUser actor,
    required String groupId,
    required String memberUid,
    required bool isAdmin,
  }) async {
    try {
      await _remote.setMemberAdmin(
        groupId: groupId,
        memberUid: memberUid,
        isAdmin: isAdmin,
      );
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> setMemberRideRole({
    required AppUser actor,
    required String groupId,
    required String memberUid,
    required RideRole? role,
  }) async {
    try {
      await _remote.setMemberRideRole(
        groupId: groupId,
        memberUid: memberUid,
        rideRole: role?.name,
      );
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> publishSharedRoute({
    required AppUser actor,
    required String groupId,
    required NavigationRoute route,
  }) async {
    try {
      await _remote.publishSharedRoute(
        groupId: groupId,
        routeJson: _routeToJson(route),
      );
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> clearSharedRoute({
    required AppUser actor,
    required String groupId,
  }) async {
    try {
      await _remote.clearSharedRoute(groupId);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> setGroupIntercomEnabled({
    required AppUser actor,
    required String groupId,
    required bool enabled,
  }) async {
    try {
      await _remote.setIntercomEnabled(groupId: groupId, enabled: enabled);
    } catch (e) {
      throw _map(e);
    }
  }

  Map<String, dynamic> _routeToJson(NavigationRoute route) {
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
            mapPois: route.mapPois,
            originLabel: route.originLabel,
            destinationLabel: route.destinationLabel,
          );
    return model.toJson();
  }

  NavigationRoute? _routeFromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return NavigationRouteModel.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<RideGroup?> watchGroup(String groupId) async* {
    RideGroup? mapFromList(List<Map<String, dynamic>> groups) {
      for (final g in groups) {
        if ('${g['id']}' == groupId) {
          return _mapGroup(g);
        }
      }
      return null;
    }

    try {
      yield mapFromList(await _remote.listGroups());
    } catch (_) {
      yield null;
    }
    await for (final _ in Stream<void>.periodic(const Duration(seconds: 12))) {
      try {
        yield mapFromList(await _remote.listGroups());
      } catch (_) {}
    }
  }

  @override
  Stream<List<GroupMember>> watchMembers(String groupId) async* {
    try {
      final raw = await _remote.listMembers(groupId);
      yield [for (final m in raw) _mapMember(m)];
    } catch (_) {
      yield const [];
    }
    await for (final _ in Stream<void>.periodic(const Duration(seconds: 8))) {
      try {
        final raw = await _remote.listMembers(groupId);
        yield [for (final m in raw) _mapMember(m)];
      } catch (_) {}
    }
  }

  @override
  Stream<List<GroupMembership>> watchMyGroups(String uid) async* {
    List<GroupMembership> mapList(List<Map<String, dynamic>> groups) {
      return [
        for (final g in groups)
          GroupMembership(
            groupId: '${g['id']}',
            name: '${g['name'] ?? 'Grupo'}',
            code: '${g['code'] ?? ''}',
            isOwner: '${g['ownerUid'] ?? ''}' == uid,
            joinedAt: DateTime.now(),
            isActive: g['isActive'] != false && '${g['isActive']}' != '0',
            clubId: g['clubId'] == null ? null : '${g['clubId']}',
          ),
      ];
    }

    try {
      yield mapList(await _remote.listGroups());
    } catch (_) {
      yield const [];
    }
    await for (final _ in Stream<void>.periodic(const Duration(seconds: 12))) {
      try {
        yield mapList(await _remote.listGroups());
      } catch (_) {}
    }
  }

  @override
  Stream<NavigationRoute?> watchSharedRoute(String groupId) async* {
    try {
      yield _routeFromJson(await _remote.fetchSharedRoute(groupId));
    } catch (_) {
      yield null;
    }
    await for (final _ in Stream<void>.periodic(const Duration(seconds: 6))) {
      try {
        yield _routeFromJson(await _remote.fetchSharedRoute(groupId));
      } catch (_) {}
    }
  }

  @override
  Stream<bool> watchHasSharedRoute(String groupId) {
    return watchSharedRoute(groupId).map((route) => route != null);
  }
}
