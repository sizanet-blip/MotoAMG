import 'package:moto_amg/core/api/motoamg_api_client.dart';
import 'package:moto_amg/features/clubs/domain/entities/moto_club.dart';

class MysqlClubRemoteDataSource {
  MysqlClubRemoteDataSource(this._api);

  final MotoAmgApiClient _api;

  Future<List<({MotoClub club, String role})>> listClubs() async {
    final data = await _api.get('/motoamg/clubs');
    final raw = data['clubs'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          (
            club: MotoClub(
              id: '${item['id']}',
              name: '${item['name'] ?? 'Club'}',
              status: '${item['status']}' == 'suspended'
                  ? MotoClubStatus.suspended
                  : MotoClubStatus.active,
              adminUids: const [],
              inviteCode: '${item['inviteCode'] ?? ''}',
              createdAt: DateTime.now(),
            ),
            role: '${item['role'] ?? 'member'}',
          ),
    ];
  }

  Future<List<MotoClubMembership>> listMemberships() async {
    final rows = await listClubs();
    return [
      for (final row in rows)
        MotoClubMembership(
          clubId: row.club.id,
          clubName: row.club.name,
          role: row.role == 'admin'
              ? MotoClubMemberRole.admin
              : MotoClubMemberRole.member,
          joinedAt: DateTime.now(),
          inviteCode: row.club.inviteCode.trim().isEmpty
              ? null
              : row.club.inviteCode.trim(),
        ),
    ]..sort((a, b) => a.clubName.compareTo(b.clubName));
  }

  /// Polling suave (MySQL no tiene listeners).
  Stream<List<MotoClubMembership>> watchMemberships(String uid) async* {
    yield await listMemberships();
    await for (final _ in Stream<void>.periodic(const Duration(seconds: 15))) {
      try {
        yield await listMemberships();
      } catch (_) {
        // Mantener último valor implícito: reintentar en el siguiente tick.
      }
    }
  }

  Future<MotoClub> createClub({required String name}) async {
    throw const MotoAmgApiException(
      'Crear club requiere aprobación del panel. Usa la solicitud de alta.',
    );
  }

  Future<MotoClub> joinClub({required String inviteCode}) async {
    final data = await _api.post(
      '/motoamg/clubs/join',
      body: {'inviteCode': inviteCode},
      auth: true,
    );
    final c = data['club'];
    if (c is! Map) {
      throw const MotoAmgApiException('Respuesta de club inválida');
    }
    return MotoClub(
      id: '${c['id']}',
      name: '${c['name']}',
      status: MotoClubStatus.active,
      adminUids: const [],
      inviteCode: '${c['inviteCode'] ?? ''}',
      createdAt: DateTime.now(),
    );
  }

  Future<MotoClub> joinWithInviteCode({
    required String uid,
    required String displayName,
    required String rawCode,
  }) {
    final code = rawCode.trim().toUpperCase().replaceAll(' ', '');
    if (code.length < 4) {
      throw StateError('Código demasiado corto.');
    }
    return joinClub(inviteCode: code);
  }

  /// Activa el club en el panel (current_club_id).
  Future<void> setActiveClub({
    required String uid,
    required String clubId,
  }) async {
    await _api.post(
      '/motoamg/clubs/active',
      body: {'clubId': clubId},
      auth: true,
    );
  }

  /// Solicitud de alta: queda pendiente hasta aprobar en el panel.
  Future<String> submitClubRequest({
    required String uid,
    required String displayName,
    required String clubName,
    String? email,
    String? phone,
    String? region,
  }) async {
    final data = await _api.post(
      '/motoamg/clubs',
      body: {'name': clubName},
      auth: true,
    );
    final request = data['request'];
    final requestId = data['pendingClubRequestId'] ??
        (request is Map ? request['id'] : null);
    if (requestId == null || '$requestId'.isEmpty) {
      throw const MotoAmgApiException('Solicitud sin id');
    }
    return '$requestId';
  }

  Future<void> clearPendingRequest(String uid) async {}

  Future<ClubJoinRequest?> fetchRequest(String requestId) async {
    final data = await _api.get('/motoamg/clubs/requests/$requestId');
    final raw = data['request'];
    if (raw is! Map) return null;
    return _requestFromMap(Map<String, dynamic>.from(raw));
  }

  Stream<ClubJoinRequest?> watchRequest(String requestId) async* {
    yield await fetchRequest(requestId);
    await for (final _ in Stream<void>.periodic(const Duration(seconds: 5))) {
      try {
        yield await fetchRequest(requestId);
      } catch (_) {
        // Reintentar en el siguiente tick.
      }
    }
  }

  ClubJoinRequest _requestFromMap(Map<String, dynamic> raw) {
    final statusRaw = '${raw['status'] ?? 'pending'}';
    final status = switch (statusRaw) {
      'approved' => ClubJoinRequestStatus.approved,
      'rejected' => ClubJoinRequestStatus.rejected,
      _ => ClubJoinRequestStatus.pending,
    };
    final createdRaw = raw['createdAt'];
    final createdAt = createdRaw is int
        ? DateTime.fromMillisecondsSinceEpoch(createdRaw * 1000)
        : DateTime.now();
    final inviteRaw = raw['inviteCode'];
    final inviteCode = inviteRaw == null ? null : '$inviteRaw'.trim();
    return ClubJoinRequest(
      id: '${raw['id']}',
      uid: '${raw['uid'] ?? ''}',
      displayName: '${raw['displayName'] ?? ''}',
      clubName: '${raw['clubName'] ?? ''}',
      status: status,
      createdAt: createdAt,
      email: raw['email'] as String?,
      phone: raw['phone'] as String?,
      region: raw['region'] as String?,
      reviewNote: raw['reviewNote'] as String?,
      resultingClubId: raw['resultingClubId'] == null
          ? null
          : '${raw['resultingClubId']}',
      inviteCode: (inviteCode == null || inviteCode.isEmpty) ? null : inviteCode,
    );
  }
}

class MysqlGroupRemoteDataSource {
  MysqlGroupRemoteDataSource(this._api);

  final MotoAmgApiClient _api;

  Future<List<Map<String, dynamic>>> listGroups() async {
    final data = await _api.get('/motoamg/groups');
    final raw = data['groups'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<Map<String, dynamic>> createGroup({required String name}) async {
    final data = await _api.post(
      '/motoamg/groups',
      body: {'name': name},
      auth: true,
    );
    final g = data['group'];
    if (g is! Map) {
      throw const MotoAmgApiException('Respuesta de grupo inválida');
    }
    return Map<String, dynamic>.from(g);
  }

  Future<Map<String, dynamic>> joinGroup({required String code}) async {
    final data = await _api.post(
      '/motoamg/groups/join',
      body: {'code': code},
      auth: true,
    );
    final g = data['group'];
    if (g is! Map) {
      throw const MotoAmgApiException('Respuesta de grupo inválida');
    }
    return Map<String, dynamic>.from(g);
  }

  Future<List<Map<String, dynamic>>> listMembers(String groupId) async {
    final data = await _api.get('/motoamg/groups/$groupId/members');
    final raw = data['members'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<Map<String, dynamic>?> fetchSharedRoute(String groupId) async {
    final data = await _api.get('/motoamg/groups/$groupId/route');
    final route = data['route'];
    if (route is! Map) return null;
    return Map<String, dynamic>.from(route);
  }

  Future<void> publishSharedRoute({
    required String groupId,
    required Map<String, dynamic> routeJson,
  }) async {
    await _api.post(
      '/motoamg/groups/$groupId/route',
      body: {'route': routeJson},
      auth: true,
    );
  }

  Future<void> clearSharedRoute(String groupId) async {
    await _api.delete('/motoamg/groups/$groupId/route');
  }

  Future<Map<String, dynamic>> setIntercomEnabled({
    required String groupId,
    required bool enabled,
  }) async {
    final data = await _api.post(
      '/motoamg/groups/$groupId/intercom',
      body: {'enabled': enabled},
      auth: true,
    );
    final g = data['group'];
    if (g is Map) {
      return Map<String, dynamic>.from(g);
    }
    return {'id': groupId, 'intercomEnabled': enabled};
  }

  Future<void> leaveGroup(String groupId) async {
    await _api.post('/motoamg/groups/$groupId/leave', auth: true);
  }

  Future<void> deleteGroup(String groupId) async {
    await _api.delete('/motoamg/groups/$groupId');
  }

  Future<void> removeMember({
    required String groupId,
    required String memberUid,
  }) async {
    await _api.delete('/motoamg/groups/$groupId/members/$memberUid');
  }

  Future<void> setMemberAdmin({
    required String groupId,
    required String memberUid,
    required bool isAdmin,
  }) async {
    await _api.post(
      '/motoamg/groups/$groupId/members/$memberUid/admin',
      body: {'isAdmin': isAdmin},
      auth: true,
    );
  }

  Future<void> setMemberRideRole({
    required String groupId,
    required String memberUid,
    required String? rideRole,
  }) async {
    await _api.post(
      '/motoamg/groups/$groupId/members/$memberUid/ride-role',
      body: {'rideRole': rideRole},
      auth: true,
    );
  }
}
