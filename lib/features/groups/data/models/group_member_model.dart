import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loc_motos/core/utils/timestamp_converter.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/groups/domain/entities/group_member.dart';

class GroupMemberModel extends GroupMember {
  const GroupMemberModel({
    required super.uid,
    required super.displayName,
    required super.joinedAt,
    super.isSharingLocation,
    super.bikeBrand,
    super.bikeModel,
    super.bikePlate,
  });

  factory GroupMemberModel.fromUser(AppUser user, DateTime joinedAt) {
    return GroupMemberModel(
      uid: user.uid,
      displayName: user.displayName,
      joinedAt: joinedAt,
      bikeBrand: user.bikeBrand,
      bikeModel: user.bikeModel,
      bikePlate: user.bikePlate,
    );
  }

  factory GroupMemberModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('El miembro ${snapshot.id} no tiene datos');
    }
    return GroupMemberModel(
      uid: snapshot.id,
      displayName: data['displayName'] as String? ?? 'Motero',
      joinedAt: parseFirestoreDate(data['joinedAt']),
      isSharingLocation: data['isSharingLocation'] as bool? ?? true,
      bikeBrand: data['bikeBrand'] as String?,
      bikeModel: data['bikeModel'] as String?,
      bikePlate: data['bikePlate'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isSharingLocation': isSharingLocation,
      'bikeBrand': bikeBrand,
      'bikeModel': bikeModel,
      'bikePlate': bikePlate,
    };
  }
}
