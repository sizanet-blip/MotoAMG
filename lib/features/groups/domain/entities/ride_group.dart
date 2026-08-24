import 'package:equatable/equatable.dart';

class RideGroup extends Equatable {
  const RideGroup({
    required this.id,
    required this.name,
    required this.code,
    required this.ownerId,
    required this.createdAt,
    required this.isActive,
  });

  final String id;
  final String name;
  final String code;
  final String ownerId;
  final DateTime createdAt;
  final bool isActive;

  bool isOwner(String uid) => ownerId == uid;

  @override
  List<Object?> get props => [id, name, code, ownerId, createdAt, isActive];
}
