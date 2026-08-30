import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/core/utils/timestamp_converter.dart';
import 'package:loc_motos/features/clubs/domain/entities/moto_club.dart';

class ClubRemoteDataSource {
  ClubRemoteDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(AppConstants.usersCollection).doc(uid);

  CollectionReference<Map<String, dynamic>> get _clubs =>
      _db.collection(AppConstants.clubsCollection);

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection(AppConstants.clubInvitesCollection);

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection(AppConstants.clubRequestsCollection);

  Stream<List<MotoClubMembership>> watchMemberships(String uid) {
    return _userRef(uid)
        .collection(AppConstants.clubMembershipsSubcollection)
        .snapshots()
        .map((snap) {
      final list = <MotoClubMembership>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        list.add(
          MotoClubMembership(
            clubId: doc.id,
            clubName: (data['clubName'] as String?) ?? 'Club',
            role: (data['role'] as String?) == 'admin'
                ? MotoClubMemberRole.admin
                : MotoClubMemberRole.member,
            joinedAt: parseFirestoreDate(data['joinedAt']),
          ),
        );
      }
      list.sort((a, b) => a.clubName.compareTo(b.clubName));
      return list;
    });
  }

  Future<MotoClub?> fetchClub(String clubId) async {
    final doc = await _clubs.doc(clubId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return _clubFrom(doc.id, doc.data()!);
  }

  Future<ClubJoinRequest?> fetchRequest(String requestId) async {
    final doc = await _requests.doc(requestId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return _requestFrom(doc.id, doc.data()!);
  }

  Stream<ClubJoinRequest?> watchRequest(String requestId) {
    return _requests.doc(requestId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return _requestFrom(doc.id, doc.data()!);
    });
  }

  /// Envía solicitud de alta de peña (la aprueba el panel AMG).
  Future<String> submitClubRequest({
    required String uid,
    required String displayName,
    required String clubName,
    String? email,
    String? phone,
    String? region,
  }) async {
    final ref = _requests.doc();
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    batch.set(ref, {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'phone': phone,
      'clubName': clubName.trim(),
      'region': region?.trim().isEmpty == true ? null : region?.trim(),
      'status': 'pending',
      'createdAt': now,
    });
    batch.update(_userRef(uid), {
      'pendingClubRequestId': ref.id,
      // Evita que un club activo huérfano tape la pantalla de pendiente.
      'currentClubId': FieldValue.delete(),
    });
    await batch.commit();
    return ref.id;
  }

  Future<void> clearPendingRequest(String uid) async {
    await _userRef(uid).update({
      'pendingClubRequestId': FieldValue.delete(),
    });
  }

  Future<void> setActiveClub({
    required String uid,
    required String clubId,
  }) async {
    await _userRef(uid).update({'currentClubId': clubId});
  }

  /// Une al usuario con código de invitación (creado en el panel).
  Future<MotoClub> joinWithInviteCode({
    required String uid,
    required String displayName,
    required String rawCode,
  }) async {
    final code = rawCode.trim().toUpperCase().replaceAll(' ', '');
    if (code.length < 4) {
      throw StateError('Código demasiado corto.');
    }
    final inviteSnap = await _invites.doc(code).get();
    if (!inviteSnap.exists || inviteSnap.data() == null) {
      throw StateError('Código no válido.');
    }
    final invite = inviteSnap.data()!;
    if (invite['active'] != true) {
      throw StateError('Esta invitación ya no está activa.');
    }
    final clubId = invite['clubId'] as String?;
    if (clubId == null || clubId.isEmpty) {
      throw StateError('Invitación incompleta.');
    }
    final club = await fetchClub(clubId);
    if (club == null || !club.isActive) {
      throw StateError('El club no está disponible.');
    }

    final memberRef = _clubs
        .doc(clubId)
        .collection(AppConstants.clubMembersSubcollection)
        .doc(uid);
    final membershipRef = _userRef(uid)
        .collection(AppConstants.clubMembershipsSubcollection)
        .doc(clubId);
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    batch.set(memberRef, {
      'uid': uid,
      'displayName': displayName,
      'role': 'member',
      'joinedAt': now,
    }, SetOptions(merge: true));
    batch.set(membershipRef, {
      'clubName': club.name,
      'role': 'member',
      'joinedAt': now,
    }, SetOptions(merge: true));
    batch.update(_userRef(uid), {
      'currentClubId': clubId,
      'pendingClubRequestId': FieldValue.delete(),
    });
    batch.update(_invites.doc(code), {
      'usedCount': FieldValue.increment(1),
      'lastUsedAt': now,
    });
    await batch.commit();
    return club;
  }

  MotoClub _clubFrom(String id, Map<String, dynamic> data) {
    final statusRaw = data['status'] as String? ?? 'active';
    return MotoClub(
      id: id,
      name: (data['name'] as String?) ?? 'Club',
      status: statusRaw == 'suspended'
          ? MotoClubStatus.suspended
          : MotoClubStatus.active,
      adminUids: [
        for (final u in (data['adminUids'] as List<dynamic>? ?? const []))
          u.toString(),
      ],
      inviteCode: (data['inviteCode'] as String?) ?? '',
      createdAt: parseFirestoreDate(data['createdAt']),
      region: data['region'] as String?,
      apiQuotaMonthly: (data['apiQuotaMonthly'] as num?)?.toInt() ?? 500,
    );
  }

  ClubJoinRequest _requestFrom(String id, Map<String, dynamic> data) {
    final statusRaw = data['status'] as String? ?? 'pending';
    final status = switch (statusRaw) {
      'approved' => ClubJoinRequestStatus.approved,
      'rejected' => ClubJoinRequestStatus.rejected,
      _ => ClubJoinRequestStatus.pending,
    };
    return ClubJoinRequest(
      id: id,
      uid: (data['uid'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      clubName: (data['clubName'] as String?) ?? '',
      status: status,
      createdAt: parseFirestoreDate(data['createdAt']),
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      region: data['region'] as String?,
      reviewNote: data['reviewNote'] as String?,
      resultingClubId: data['resultingClubId'] as String?,
    );
  }
}
