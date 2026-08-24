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
  });

  final String groupId;
  final String name;
  final String code;
  final bool isOwner;
  final DateTime joinedAt;
  final bool isActive;

  @override
  List<Object?> get props => [groupId, name, code, isOwner, joinedAt, isActive];
}
