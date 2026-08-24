import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/groups/data/datasources/group_remote_datasource.dart';
import 'package:loc_motos/features/groups/data/repositories/group_repository_impl.dart';
import 'package:loc_motos/features/groups/domain/entities/group_member.dart';
import 'package:loc_motos/features/groups/domain/entities/group_membership.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_group.dart';
import 'package:loc_motos/features/groups/domain/exceptions/group_exceptions.dart';
import 'package:loc_motos/features/groups/domain/repositories/group_repository.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepositoryImpl(GroupRemoteDataSource());
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

  void _setLocalGroup(AppUser user, String groupId) {
    final current = ref.read(signedInUserProvider) ?? user;
    ref.read(signedInUserProvider.notifier).state = current.copyWith(
      currentGroupId: groupId,
    );
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
