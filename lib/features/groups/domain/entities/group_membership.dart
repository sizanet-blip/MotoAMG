import 'package:equatable/equatable.dart';

/// Grupo al que pertenece el usuario (puede haber varios).
class GroupMembership extends Equatable {
  const GroupMembership({
    required this.groupId,
    required this.name,
    required this.code,
    required this.isOwner,
    required this.joinedAt,
    this.isActive = true,
    this.clubId,
  });

  final String groupId;
  final String name;
  final String code;
  final bool isOwner;
  final DateTime joinedAt;
  final bool isActive;

  /// Peña del grupo (para filtrar al cambiar de club).
  final String? clubId;

  @override
  List<Object?> get props =>
      [groupId, name, code, isOwner, joinedAt, isActive, clubId];
}
