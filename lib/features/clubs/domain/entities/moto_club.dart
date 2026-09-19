import 'package:equatable/equatable.dart';

enum MotoClubStatus { active, suspended }

enum MotoClubMemberRole { member, admin }

/// Club (acceso a la app; distinto del grupo de ruta / salida).
class MotoClub extends Equatable {
  const MotoClub({
    required this.id,
    required this.name,
    required this.status,
    required this.adminUids,
    required this.inviteCode,
    required this.createdAt,
    this.region,
    this.apiQuotaMonthly = 500,
  });

  final String id;
  final String name;
  final MotoClubStatus status;
  final List<String> adminUids;
  final String inviteCode;
  final DateTime createdAt;
  final String? region;
  final int apiQuotaMonthly;

  bool get isActive => status == MotoClubStatus.active;

  bool isAdmin(String uid) => adminUids.contains(uid);

  @override
  List<Object?> get props =>
      [id, name, status, adminUids, inviteCode, createdAt, region, apiQuotaMonthly];
}

class MotoClubMembership extends Equatable {
  const MotoClubMembership({
    required this.clubId,
    required this.clubName,
    required this.role,
    required this.joinedAt,
    this.inviteCode,
  });

  final String clubId;
  final String clubName;
  final MotoClubMemberRole role;
  final DateTime joinedAt;

  /// Solo para admin; miembros lo reciben vacío/null.
  final String? inviteCode;

  bool get isAdmin => role == MotoClubMemberRole.admin;

  bool get hasInviteCode =>
      inviteCode != null && inviteCode!.trim().isNotEmpty;

  @override
  List<Object?> get props => [clubId, clubName, role, joinedAt, inviteCode];
}

enum ClubJoinRequestStatus { pending, approved, rejected }

class ClubJoinRequest extends Equatable {
  const ClubJoinRequest({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.clubName,
    required this.status,
    required this.createdAt,
    this.email,
    this.phone,
    this.region,
    this.reviewNote,
    this.resultingClubId,
    this.inviteCode,
  });

  final String id;
  final String uid;
  final String displayName;
  final String clubName;
  final ClubJoinRequestStatus status;
  final DateTime createdAt;
  final String? email;
  final String? phone;
  final String? region;
  final String? reviewNote;
  final String? resultingClubId;

  /// Código de invitación tras aprobar (solo para el solicitante/admin).
  final String? inviteCode;

  bool get isPending => status == ClubJoinRequestStatus.pending;

  @override
  List<Object?> get props => [
        id,
        uid,
        displayName,
        clubName,
        status,
        createdAt,
        email,
        phone,
        region,
        reviewNote,
        resultingClubId,
        inviteCode,
      ];
}
