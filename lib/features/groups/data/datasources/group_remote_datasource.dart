import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/core/utils/code_generator.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/groups/data/models/group_member_model.dart';
import 'package:loc_motos/features/groups/data/models/group_membership_model.dart';
import 'package:loc_motos/features/groups/data/models/group_model.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_role.dart';
import 'package:loc_motos/features/groups/domain/exceptions/group_exceptions.dart';
import 'package:loc_motos/features/navigation/data/models/navigation_route_model.dart';
import 'package:loc_motos/firebase_options.dart';

class GroupRemoteDataSource {
  GroupRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseDatabase? database,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _database =
           database ??
           FirebaseDatabase.instanceFor(
             app: Firebase.app(),
             databaseURL: DefaultFirebaseOptions.realtimeDatabaseUrl,
           );

  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;
  final Set<String> _pruning = {};

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection(AppConstants.groupsCollection);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);

  CollectionReference<Map<String, dynamic>> _members(String groupId) {
    return _groups.doc(groupId).collection(AppConstants.membersSubcollection);
  }

  CollectionReference<Map<String, dynamic>> _memberships(String uid) {
    return _users.doc(uid).collection(AppConstants.membershipsSubcollection);
  }

  Map<String, dynamic> _membershipPayload({
    required GroupModel group,
    required String uid,
    required DateTime joinedAt,
  }) {
    return GroupMembershipModel(
      groupId: group.id,
      name: group.name,
      code: group.code,
      isOwner: group.ownerId == uid,
      joinedAt: joinedAt,
      isActive: group.isActive,
      clubId: group.clubId,
    ).toFirestore();
  }

  Future<bool> _codeExists(String code) async {
    final result = await _groups.where('code', isEqualTo: code).limit(1).get();
    return result.docs.isNotEmpty;
  }

  Future<String> _uniqueCode() async {
    for (var i = 0; i < 10; i++) {
      final code = CodeGenerator.groupCode();
      if (!await _codeExists(code)) {
        return code;
      }
    }
    throw const GroupException(
      'No se pudo generar un código. Inténtalo otra vez.',
    );
  }

  Future<GroupModel> createGroup({
    required AppUser user,
    required String name,
  }) async {
    if (user.isAnonymous) {
      throw const GroupException(
        'Con un nombre suelto solo puedes unirte a un grupo. '
        'Crea una cuenta para organizar la ruta.',
      );
    }
    final clubId = user.currentClubId;
    if (clubId == null || clubId.isEmpty) {
      throw const GroupException(
        'Necesitas pertenecer a un club para crear un grupo de ruta.',
      );
    }
    try {
      final code = await _uniqueCode();
      final groupRef = _groups.doc();
      final now = DateTime.now();
      final group = GroupModel(
        id: groupRef.id,
        name: name,
        code: code,
        ownerId: user.uid,
        createdAt: now,
        isActive: true,
        adminUids: const [],
        clubId: clubId,
      );
      final member = GroupMemberModel.fromUser(user, now);
      final batch = _firestore.batch();
      batch.set(groupRef, group.toFirestore());
      batch.set(_members(groupRef.id).doc(user.uid), member.toFirestore());
      batch.set(
        _memberships(user.uid).doc(groupRef.id),
        _membershipPayload(group: group, uid: user.uid, joinedAt: now),
      );
      batch.set(_users.doc(user.uid), {
        'currentGroupId': groupRef.id,
      }, SetOptions(merge: true));
      await batch.commit();
      return group;
    } on GroupException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GroupException(
        'No se pudo crear el grupo. ${error.message ?? error.code}',
      );
    }
  }

  Future<GroupModel> joinGroup({
    required AppUser user,
    required String code,
  }) async {
    final normalized = code.trim().toUpperCase().replaceAll(' ', '');
    if (normalized.length != AppConstants.groupCodeLength) {
      throw const GroupException(
        'El código tiene ${AppConstants.groupCodeLength} caracteres.',
      );
    }
    try {
      final found = await _groups
          .where('code', isEqualTo: normalized)
          .limit(5)
          .get();
      if (found.docs.isEmpty) {
        throw const GroupException('No hay ningún grupo con ese código.');
      }
      final activeDocs = found.docs.where(
        (doc) => (doc.data()['isActive'] as bool?) ?? true,
      );
      if (activeDocs.isEmpty) {
        throw const GroupException('Ese grupo ya está cerrado.');
      }
      final group = GroupModel.fromFirestore(activeDocs.first);

      // Grupos de otra peña: no se puede entrar con el código.
      final userClub = user.currentClubId;
      if (group.clubId != null &&
          group.clubId!.isNotEmpty &&
          !user.isAnonymous) {
        if (userClub == null || userClub.isEmpty) {
          throw const GroupException(
            'Ese grupo es de un club. Únete al club antes.',
          );
        }
        if (group.clubId != userClub) {
          throw const GroupException(
            'Ese grupo pertenece a otro club.',
          );
        }
      }

      final alreadyMember = await _members(group.id).doc(user.uid).get();
      if (alreadyMember.exists) {
        await _members(group.id).doc(user.uid).set({
          'displayName': user.displayName,
          'bikeBrand': user.bikeBrand,
          'bikeModel': user.bikeModel,
          'bikePlate': user.bikePlate,
        }, SetOptions(merge: true));
        await setActiveGroup(uid: user.uid, groupId: group.id);
        return group;
      }
      if (user.isAnonymous && user.isInGroup) {
        throw const GroupException(
          'Como invitado solo puedes estar en un grupo.',
        );
      }

      final now = DateTime.now();
      final member = GroupMemberModel.fromUser(user, now);
      final batch = _firestore.batch();
      batch.set(_members(group.id).doc(user.uid), member.toFirestore());
      batch.set(
        _memberships(user.uid).doc(group.id),
        _membershipPayload(group: group, uid: user.uid, joinedAt: now),
      );
      batch.set(_users.doc(user.uid), {
        'currentGroupId': group.id,
      }, SetOptions(merge: true));
      await batch.commit();
      return group;
    } on GroupException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GroupException(
        'No se pudo unir al grupo. ${error.message ?? error.code}',
      );
    }
  }

  Future<void> _deleteQueryBatch(
    Query<Map<String, dynamic>> query,
  ) async {
    while (true) {
      final snap = await query.limit(450).get();
      if (snap.docs.isEmpty) {
        return;
      }
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Elimina el grupo, sus miembros, membresías, ruta compartida y datos RTDB.
  Future<void> deleteGroup({
    required AppUser user,
    required String groupId,
  }) async {
    if (groupId.isEmpty) {
      return;
    }
    try {
      final groupSnap = await _groups.doc(groupId).get();
      if (!groupSnap.exists) {
        return;
      }
      final group = GroupModel.fromFirestore(groupSnap);
      if (!group.isOwner(user.uid)) {
        throw const GroupException(
          'Solo el creador puede eliminar el grupo.',
        );
      }

      final membersSnap = await _members(groupId).get();
      final memberUids = membersSnap.docs.map((doc) => doc.id).toList();

      for (final uid in memberUids) {
        try {
          final userSnap = await _users.doc(uid).get();
          if (userSnap.data()?['currentGroupId'] == groupId) {
            await _users.doc(uid).set({
              'currentGroupId': null,
            }, SetOptions(merge: true));
          }
          await _memberships(uid).doc(groupId).delete();
        } catch (_) {}
      }

      await _deleteQueryBatch(_members(groupId));
      try {
        await _sharedRouteRef(groupId).delete();
      } catch (_) {}
      await _groups.doc(groupId).delete();

      try {
        await _database
            .ref('${AppConstants.liveLocationsPath}/$groupId')
            .remove();
      } catch (_) {}
      try {
        await _database
            .ref('${AppConstants.groupAlertsPath}/$groupId')
            .remove();
      } catch (_) {}
      try {
        await _database
            .ref('${AppConstants.groupVoicePath}/$groupId')
            .remove();
      } catch (_) {}
      try {
        await _database
            .ref('${AppConstants.groupStopsPath}/$groupId')
            .remove();
      } catch (_) {}
    } on GroupException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GroupException(
        'No se pudo eliminar el grupo. ${error.message ?? error.code}',
      );
    }
  }

  Future<void> leaveGroup({
    required AppUser user,
    required String groupId,
  }) async {
    if (groupId.isEmpty) {
      return;
    }
    try {
      DocumentSnapshot<Map<String, dynamic>>? groupSnap;
      try {
        groupSnap = await _groups.doc(groupId).get();
      } on FirebaseException {
        groupSnap = null;
      }
      final userSnap = await _users.doc(user.uid).get();
      final activeId = userSnap.data()?['currentGroupId'] as String?;
      final batch = _firestore.batch();
      batch.delete(_members(groupId).doc(user.uid));
      batch.delete(_memberships(user.uid).doc(groupId));
      if (activeId == groupId) {
        batch.set(_users.doc(user.uid), {
          'currentGroupId': null,
        }, SetOptions(merge: true));
      }
      if (groupSnap != null &&
          groupSnap.exists &&
          groupSnap.data()?['ownerId'] == user.uid) {
        batch.update(_groups.doc(groupId), {'isActive': false});
      }
      await batch.commit();
    } on FirebaseException {
      await _users.doc(user.uid).set({
        'currentGroupId': null,
      }, SetOptions(merge: true));
    }
  }

  Future<void> setActiveGroup({
    required String uid,
    required String? groupId,
  }) async {
    await _users.doc(uid).set({
      'currentGroupId': groupId,
    }, SetOptions(merge: true));
  }

  Stream<List<GroupMembershipModel>> watchMyGroups(String uid) {
    return _memberships(uid).snapshots().asyncMap((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final items = snapshot.docs
            .map(GroupMembershipModel.fromFirestore)
            .toList();
        items.sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
        return items;
      }
      return _legacyMemberships(uid);
    });
  }

  Future<List<GroupMembershipModel>> _legacyMemberships(String uid) async {
    try {
      final userSnap = await _users.doc(uid).get();
      final groupId = userSnap.data()?['currentGroupId'] as String?;
      if (groupId == null || groupId.isEmpty) {
        return const [];
      }
      final groupSnap = await _groups.doc(groupId).get();
      if (!groupSnap.exists) {
        return const [];
      }
      final group = GroupModel.fromFirestore(groupSnap);
      final membership = GroupMembershipModel(
        groupId: group.id,
        name: group.name,
        code: group.code,
        isOwner: group.ownerId == uid,
        joinedAt: group.createdAt,
        isActive: group.isActive,
        clubId: group.clubId,
      );
      await _memberships(uid).doc(group.id).set(membership.toFirestore());
      return [membership];
    } catch (_) {
      return const [];
    }
  }

  Future<void> removeMember({
    required AppUser owner,
    required String groupId,
    required String memberUid,
  }) async {
    if (owner.uid == memberUid) {
      throw const GroupException(
        'No puedes quitarte a ti mismo. Usa salir del grupo.',
      );
    }
    try {
      final groupSnap = await _groups.doc(groupId).get();
      if (!groupSnap.exists) {
        throw const GroupException('Ese grupo no existe.');
      }
      final group = GroupModel.fromFirestore(groupSnap);
      if (!group.isAdmin(owner.uid)) {
        throw const GroupException(
          'Solo un administrador puede quitar a alguien.',
        );
      }
      if (group.isOwner(memberUid)) {
        throw const GroupException('No se puede quitar al creador del grupo.');
      }
      final batch = _firestore.batch();
      batch.delete(_members(groupId).doc(memberUid));
      batch.delete(_memberships(memberUid).doc(groupId));
      if (group.adminUids.contains(memberUid)) {
        batch.update(_groups.doc(groupId), {
          'adminUids': FieldValue.arrayRemove([memberUid]),
        });
      }
      final memberUser = await _users.doc(memberUid).get();
      if (memberUser.data()?['currentGroupId'] == groupId) {
        batch.set(_users.doc(memberUid), {
          'currentGroupId': null,
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } on GroupException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GroupException(
        'No se pudo quitar a esa persona. ${error.message ?? error.code}',
      );
    }
  }

  Future<void> setMemberAdmin({
    required AppUser actor,
    required String groupId,
    required String memberUid,
    required bool isAdmin,
  }) async {
    try {
      final groupSnap = await _groups.doc(groupId).get();
      if (!groupSnap.exists) {
        throw const GroupException('Ese grupo no existe.');
      }
      final group = GroupModel.fromFirestore(groupSnap);
      if (!group.isOwner(actor.uid)) {
        throw const GroupException(
          'Solo el creador puede nombrar administradores.',
        );
      }
      if (group.isOwner(memberUid)) {
        return;
      }
      await _groups.doc(groupId).update({
        'adminUids': isAdmin
            ? FieldValue.arrayUnion([memberUid])
            : FieldValue.arrayRemove([memberUid]),
      });
    } on GroupException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GroupException(
        'No se pudo actualizar el administrador. ${error.message ?? error.code}',
      );
    }
  }

  Future<void> setMemberRideRole({
    required AppUser actor,
    required String groupId,
    required String memberUid,
    required RideRole? role,
  }) async {
    try {
      final groupSnap = await _groups.doc(groupId).get();
      if (!groupSnap.exists) {
        throw const GroupException('Ese grupo no existe.');
      }
      final group = GroupModel.fromFirestore(groupSnap);
      if (!group.isAdmin(actor.uid)) {
        throw const GroupException(
          'Solo un administrador puede asignar cabecera o cola.',
        );
      }
      final batch = _firestore.batch();
      if (role != null) {
        final members = await _members(groupId).get();
        for (final doc in members.docs) {
          if (doc.id == memberUid) {
            continue;
          }
          final current = RideRoleX.tryParse(doc.data()['rideRole'] as String?);
          if (current == role) {
            batch.update(doc.reference, {'rideRole': null});
          }
        }
      }
      batch.set(
        _members(groupId).doc(memberUid),
        {'rideRole': role?.firestoreValue},
        SetOptions(merge: true),
      );
      await batch.commit();
    } on GroupException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GroupException(
        'No se pudo asignar el rol. ${error.message ?? error.code}',
      );
    }
  }

  DocumentReference<Map<String, dynamic>> _sharedRouteRef(String groupId) {
    return _groups
        .doc(groupId)
        .collection(AppConstants.sharedRouteSubcollection)
        .doc(AppConstants.sharedRouteDocId);
  }

  Future<void> publishSharedRoute({
    required AppUser actor,
    required String groupId,
    required NavigationRouteModel route,
  }) async {
    try {
      final groupSnap = await _groups.doc(groupId).get();
      if (!groupSnap.exists) {
        throw const GroupException('Ese grupo no existe.');
      }
      final group = GroupModel.fromFirestore(groupSnap);
      if (!group.isAdmin(actor.uid)) {
        throw const GroupException(
          'Solo un administrador puede publicar la ruta del grupo.',
        );
      }
      await _sharedRouteRef(groupId).set({
        'route': route.toJson(),
        'publishedBy': actor.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on GroupException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GroupException(
        'No se pudo publicar la ruta. ${error.message ?? error.code}',
      );
    }
  }

  Future<void> setGroupIntercomEnabled({
    required AppUser actor,
    required String groupId,
    required bool enabled,
  }) async {
    try {
      final groupSnap = await _groups.doc(groupId).get();
      if (!groupSnap.exists) {
        throw const GroupException('Ese grupo no existe.');
      }
      final group = GroupModel.fromFirestore(groupSnap);
      if (!group.isOwner(actor.uid)) {
        throw const GroupException(
          'Solo el creador del grupo puede activar el intercom.',
        );
      }
      await _groups.doc(groupId).update({'intercomEnabled': enabled});
    } on GroupException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GroupException(
        'No se pudo cambiar el intercom. ${error.message ?? error.code}',
      );
    }
  }

  Stream<NavigationRouteModel?> watchSharedRoute(String groupId) {
    return _sharedRouteRef(groupId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) {
        return null;
      }
      final raw = data['route'];
      if (raw is! Map) {
        return null;
      }
      try {
        return NavigationRouteModel.fromJson(_deepStringKeyedMap(raw));
      } catch (_) {
        return null;
      }
    });
  }

  /// Solo presencia del doc (para UI «Actualizar» aunque falle el parseo).
  Stream<bool> watchHasSharedRoute(String groupId) {
    return _sharedRouteRef(groupId).snapshots().map((snap) => snap.exists);
  }

  Map<String, dynamic> _deepStringKeyedMap(Map<dynamic, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((key, value) {
      out[key.toString()] = _deepConvert(value);
    });
    return out;
  }

  dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return _deepStringKeyedMap(Map<dynamic, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(_deepConvert).toList(growable: false);
    }
    return value;
  }

  Stream<GroupModel?> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return GroupModel.fromFirestore(snapshot);
    });
  }

  Stream<List<GroupMemberModel>> watchMembers(String groupId) {
    return _members(groupId).snapshots().asyncMap((snapshot) async {
      final members = snapshot.docs
          .map(GroupMemberModel.fromFirestore)
          .toList();
      members.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
      final alive = <GroupMemberModel>[];
      for (final member in members) {
        try {
          final userSnap = await _users.doc(member.uid).get();
          if (userSnap.exists && userSnap.data() != null) {
            alive.add(member);
          } else {
            _pruneGhostMember(groupId, member.uid);
          }
        } catch (_) {
          alive.add(member);
        }
      }
      return alive;
    });
  }

  void _pruneGhostMember(String groupId, String uid) {
    final key = '$groupId/$uid';
    if (!_pruning.add(key)) {
      return;
    }
    () async {
      try {
        await _members(groupId).doc(uid).delete();
      } catch (_) {}
      try {
        await _memberships(uid).doc(groupId).delete();
      } catch (_) {}
      try {
        await _database
            .ref('${AppConstants.liveLocationsPath}/$groupId/$uid')
            .remove();
      } catch (_) {}
      _pruning.remove(key);
    }();
  }
}
