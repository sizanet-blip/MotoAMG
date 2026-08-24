import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loc_motos/core/utils/timestamp_converter.dart';
import 'package:loc_motos/features/groups/domain/entities/group_membership.dart';

class GroupMembershipModel extends GroupMembership {
  const GroupMembershipModel({
    required super.groupId,
    required super.name,
    required super.code,
    required super.isOwner,
    required super.joinedAt,
    super.isActive,
  });

  factory GroupMembershipModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return GroupMembershipModel(
      groupId: snapshot.id,
      name: data['name'] as String? ?? 'Grupo',
      code: data['code'] as String? ?? '',
      isOwner: data['isOwner'] as bool? ?? false,
      joinedAt: parseFirestoreDate(data['joinedAt']),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code,
      'isOwner': isOwner,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isActive': isActive,
    };
  }
}
