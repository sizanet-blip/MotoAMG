import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/groups/data/datasources/group_incident_remote_datasource.dart';
import 'package:loc_motos/features/groups/data/datasources/group_stop_remote_datasource.dart';
import 'package:loc_motos/features/groups/data/datasources/group_voice_remote_datasource.dart';
import 'package:loc_motos/features/groups/data/datasources/group_remote_datasource.dart';
import 'package:loc_motos/features/groups/data/repositories/group_pack_alert_repository.dart';
import 'package:loc_motos/features/groups/data/repositories/group_repository_impl.dart';
import 'package:loc_motos/features/groups/domain/entities/group_incident.dart';
import 'package:loc_motos/features/groups/domain/entities/group_member.dart';
import 'package:loc_motos/features/groups/domain/entities/group_stop.dart';
import 'package:loc_motos/features/groups/domain/entities/group_membership.dart';
import 'package:loc_motos/features/groups/domain/entities/group_voice_announcement.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_group.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_role.dart';
import 'package:loc_motos/features/groups/domain/exceptions/group_exceptions.dart';
import 'package:loc_motos/features/groups/domain/repositories/group_repository.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepositoryImpl(GroupRemoteDataSource());
});

final groupPackAlertRepositoryProvider = Provider<GroupPackAlertRepository>((
  ref,
) {
  return GroupPackAlertRepository();
});

final groupPackAlertProvider =
    NotifierProvider<GroupPackAlertController, GroupPackAlertPreferences>(
  GroupPackAlertController.new,
);

class GroupPackAlertController extends Notifier<GroupPackAlertPreferences> {
  @override
  GroupPackAlertPreferences build() {
    Future.microtask(_hydrate);
    return GroupPackAlertPreferences.defaults;
  }

  Future<void> _hydrate() async {
    final loaded = await ref.read(groupPackAlertRepositoryProvider).load();
    state = loaded;
  }

  Future<void> _persist(GroupPackAlertPreferences next) async {
    state = next;
    await ref.read(groupPackAlertRepositoryProvider).save(next);
  }

  Future<void> setEnabled(bool value) {
    return _persist(state.copyWith(enabled: value));
  }

  Future<void> setBehindMeters(double meters) {
    return _persist(state.copyWith(behindMeters: meters));
  }

  Future<void> setFarMeters(double meters) {
    return _persist(state.copyWith(farMeters: meters));
  }

  Future<void> setMateDisplayMode(GroupMateDisplayMode mode) {
    return _persist(state.copyWith(mateDisplayMode: mode));
  }

  Future<void> setShowGroupOnNavigation(bool value) {
    return _persist(state.copyWith(showGroupOnNavigation: value));
  }

  Future<void> setPreferExternalNavigation(bool value) {
    return _persist(state.copyWith(preferExternalNavigation: value));
  }

  Future<void> mutePackAlertsFor(Duration duration) {
    final until = DateTime.now().add(duration);
    return _persist(state.copyWith(packAlertsMutedUntil: until));
  }

  Future<void> clearPackAlertsMute() {
    return _persist(state.copyWith(clearPackAlertsMute: true));
  }

  Future<void> reset() => _persist(GroupPackAlertPreferences.defaults);
}

final groupIncidentDatasourceProvider =
    Provider<GroupIncidentRemoteDataSource>((ref) {
  return GroupIncidentRemoteDataSource();
});

final groupIncidentsProvider =
    StreamProvider.family<List<GroupIncident>, String>((ref, groupId) {
  return ref.watch(groupIncidentDatasourceProvider).watchGroup(groupId);
});

final groupVoiceDatasourceProvider =
    Provider<GroupVoiceRemoteDataSource>((ref) {
  return GroupVoiceRemoteDataSource();
});

final groupVoiceAnnouncementsProvider =
    StreamProvider.family<List<GroupVoiceAnnouncement>, String>((ref, groupId) {
  return ref.watch(groupVoiceDatasourceProvider).watchGroup(groupId);
});

final groupStopDatasourceProvider =
    Provider<GroupStopRemoteDataSource>((ref) {
  return GroupStopRemoteDataSource();
});

final groupStopsProvider =
    StreamProvider.family<List<GroupStop>, String>((ref, groupId) {
  return ref.watch(groupStopDatasourceProvider).watchGroup(groupId);
});

final liveUserProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(authRepositoryProvider).watchUser(uid);
});

final rideGroupProvider = StreamProvider.family<RideGroup?, String>((
  ref,
  groupId,
) {
  return ref.watch(groupRepositoryProvider).watchGroup(groupId);
});

final groupMembersProvider = StreamProvider.family<List<GroupMember>, String>((
  ref,
  groupId,
) {
  return ref.watch(groupRepositoryProvider).watchMembers(groupId);
});

final groupSharedRouteProvider =
    StreamProvider.family<NavigationRoute?, String>((ref, groupId) {
  if (groupId.isEmpty) {
    return Stream<NavigationRoute?>.value(null);
  }
  return ref.watch(groupRepositoryProvider).watchSharedRoute(groupId);
});

final groupHasSharedRouteProvider =
    StreamProvider.family<bool, String>((ref, groupId) {
  if (groupId.isEmpty) {
    return Stream<bool>.value(false);
  }
  return ref.watch(groupRepositoryProvider).watchHasSharedRoute(groupId);
});

final myGroupsProvider = StreamProvider.family<List<GroupMembership>, String>((
  ref,
  uid,
) {
  return ref.watch(groupRepositoryProvider).watchMyGroups(uid);
});

final groupActionControllerProvider =
    NotifierProvider<GroupActionController, AsyncValue<void>>(
      GroupActionController.new,
    );

/// El mapa del grupo solo se muestra si el usuario lo abre en esta sesión.
/// Al arrancar la app queda en false → página de inicio (Mis grupos).
final groupMapSessionOpenProvider = StateProvider<bool>((ref) => false);

class GroupActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  GroupRepository get _repo => ref.read(groupRepositoryProvider);

  Future<void> createGroup({required AppUser user, required String name}) {
    return _run(() async {
      final group = await _repo.createGroup(user: user, name: name);
      _setLocalGroup(user, group.id);
    });
  }

  Future<void> joinGroup({required AppUser user, required String code}) {
    return _run(() async {
      final group = await _repo.joinGroup(user: user, code: code);
      _setLocalGroup(user, group.id);
    });
  }

  Future<void> leaveGroup({
    required AppUser user,
    required String groupId,
  }) {
    return _run(() async {
      await _repo.leaveGroup(user: user, groupId: groupId);
      await ref.read(locationRepositoryProvider).clearLocation(
        groupId: groupId,
        uid: user.uid,
      );
      final current = ref.read(signedInUserProvider);
      if (current != null && current.currentGroupId == groupId) {
        ref.read(signedInUserProvider.notifier).state = current.copyWith(
          clearCurrentGroupId: true,
        );
      }
      ref.read(groupMapSessionOpenProvider.notifier).state = false;
    });
  }

  Future<void> deleteGroup({
    required AppUser user,
    required String groupId,
  }) {
    return _run(() async {
      await _repo.deleteGroup(user: user, groupId: groupId);
      try {
        await ref.read(locationRepositoryProvider).clearLocation(
          groupId: groupId,
          uid: user.uid,
        );
      } catch (_) {}
      final current = ref.read(signedInUserProvider);
      if (current != null && current.currentGroupId == groupId) {
        ref.read(signedInUserProvider.notifier).state = current.copyWith(
          clearCurrentGroupId: true,
        );
      }
      ref.read(groupMapSessionOpenProvider.notifier).state = false;
    });
  }

  Future<void> openGroup({
    required AppUser user,
    required String groupId,
  }) {
    return _run(() async {
      final previousId = user.currentGroupId;
      if (previousId != null &&
          previousId.isNotEmpty &&
          previousId != groupId) {
        try {
          await ref.read(locationRepositoryProvider).clearLocation(
            groupId: previousId,
            uid: user.uid,
          );
        } catch (_) {}
      }
      await _repo.setActiveGroup(uid: user.uid, groupId: groupId);
      _setLocalGroup(user, groupId);
    });
  }

  Future<void> closeMap({required AppUser user}) {
    return _run(() async {
      final groupId = user.currentGroupId;
      await _repo.setActiveGroup(uid: user.uid, groupId: null);
      if (groupId != null && groupId.isNotEmpty) {
        try {
          await ref.read(locationRepositoryProvider).clearLocation(
            groupId: groupId,
            uid: user.uid,
          );
        } catch (_) {}
      }
      final current = ref.read(signedInUserProvider);
      if (current != null) {
        ref.read(signedInUserProvider.notifier).state = current.copyWith(
          clearCurrentGroupId: true,
        );
      }
      ref.read(groupMapSessionOpenProvider.notifier).state = false;
    });
  }

  Future<void> removeMember({
    required AppUser owner,
    required String groupId,
    required GroupMember member,
  }) {
    return _run(() async {
      await _repo.removeMember(
        owner: owner,
        groupId: groupId,
        memberUid: member.uid,
      );
      try {
        await ref.read(locationRepositoryProvider).clearLocation(
          groupId: groupId,
          uid: member.uid,
        );
      } catch (_) {}
    });
  }

  Future<void> setMemberAdmin({
    required AppUser actor,
    required String groupId,
    required String memberUid,
    required bool isAdmin,
  }) {
    return _run(() async {
      await _repo.setMemberAdmin(
        actor: actor,
        groupId: groupId,
        memberUid: memberUid,
        isAdmin: isAdmin,
      );
    });
  }

  Future<void> setMemberRideRole({
    required AppUser actor,
    required String groupId,
    required String memberUid,
    required RideRole? role,
  }) {
    return _run(() async {
      await _repo.setMemberRideRole(
        actor: actor,
        groupId: groupId,
        memberUid: memberUid,
        role: role,
      );
    });
  }

  Future<void> publishSharedRoute({
    required AppUser actor,
    required String groupId,
    required NavigationRoute route,
  }) {
    return _run(() async {
      await _repo.publishSharedRoute(
        actor: actor,
        groupId: groupId,
        route: route,
      );
    });
  }

  Future<void> clearSharedRoute({
    required AppUser actor,
    required String groupId,
  }) {
    return _run(() async {
      await _repo.clearSharedRoute(
        actor: actor,
        groupId: groupId,
      );
    });
  }

  Future<void> setGroupIntercomEnabled({
    required AppUser actor,
    required String groupId,
    required bool enabled,
  }) {
    return _run(() async {
      await _repo.setGroupIntercomEnabled(
        actor: actor,
        groupId: groupId,
        enabled: enabled,
      );
    });
  }

  Future<void> raiseIncident({
    required String groupId,
    required String uid,
    required String displayName,
    required GroupIncidentType type,
    required GeoPoint point,
    GroupIncidentSeverity? severity,
  }) async {
    await _run(() async {
      final cached =
          ref.read(groupIncidentsProvider(groupId)).valueOrNull ??
              const <GroupIncident>[];
      GroupIncident? mine;
      for (final i in cached) {
        if (i.uid == uid) {
          mine = i;
          break;
        }
      }
      if (mine != null) {
        if (mine.type == GroupIncidentType.emergencia &&
            type != GroupIncidentType.emergencia) {
          throw const GroupException(
            'Tienes una emergencia activa. Cancélala antes o mantén el aviso.',
          );
        }
      }
      await ref.read(groupIncidentDatasourceProvider).publish(
            groupId,
            GroupIncident(
              uid: uid,
              type: type,
              point: point,
              at: DateTime.now(),
              severity: type == GroupIncidentType.emergencia
                  ? (severity ?? GroupIncidentSeverity.alta)
                  : null,
              displayName: displayName,
            ),
          );
    });
    final failure = state.asError;
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
  }

  Future<void> clearIncident({
    required String groupId,
    required String uid,
  }) async {
    await _run(() async {
      await ref.read(groupIncidentDatasourceProvider).clear(
            groupId: groupId,
            uid: uid,
          );
    });
    final failure = state.asError;
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
  }

  void _setLocalGroup(AppUser user, String groupId) {
    final current = ref.read(signedInUserProvider) ?? user;
    ref.read(signedInUserProvider.notifier).state = current.copyWith(
      currentGroupId: groupId,
    );
    ref.read(groupMapSessionOpenProvider.notifier).state = true;
  }

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
    } on GroupException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    } catch (error, stackTrace) {
      state = AsyncError(GroupException(error.toString()), stackTrace);
    }
  }
}

