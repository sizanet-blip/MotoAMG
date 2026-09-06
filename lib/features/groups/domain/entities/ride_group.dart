import 'package:equatable/equatable.dart';

class RideGroup extends Equatable {
  const RideGroup({
    required this.id,
    required this.name,
    required this.code,
    required this.ownerId,
    required this.createdAt,
    required this.isActive,
    this.adminUids = const [],
    this.intercomEnabled = false,
    this.clubId,
  });

  final String id;
  final String name;
  final String code;
  final String ownerId;
  final DateTime createdAt;
  final bool isActive;

  /// Admins explícitos (el [ownerId] siempre cuenta como admin).
  final List<String> adminUids;

  /// Canal de voz del pelotón (lo activa solo el creador).
  final bool intercomEnabled;

  /// Club al que pertenece este grupo de ruta (null = legado).
  final String? clubId;

  bool isOwner(String uid) => ownerId == uid;

  bool isAdmin(String uid) => isOwner(uid) || adminUids.contains(uid);

  @override
  List<Object?> get props => [
        id,
        name,
        code,
        ownerId,
        createdAt,
        isActive,
        adminUids,
        intercomEnabled,
        clubId,
      ];
}
