import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loc_motos/core/utils/timestamp_converter.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_group.dart';

class GroupModel extends RideGroup {
  const GroupModel({
    required super.id,
    required super.name,
    required super.code,
    required super.ownerId,
    required super.createdAt,
    required super.isActive,
    super.adminUids,
    super.intercomEnabled,
  });

  factory GroupModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('El grupo ${snapshot.id} no tiene datos');
    }
    final rawAdmins = data['adminUids'];
    final adminUids = <String>[
      if (rawAdmins is List)
        for (final item in rawAdmins)
          if (item is String && item.isNotEmpty) item,
    ];
    return GroupModel(
      id: snapshot.id,
      name: data['name'] as String? ?? 'Grupo',
      code: data['code'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      createdAt: parseFirestoreDate(data['createdAt']),
      isActive: data['isActive'] as bool? ?? true,
      adminUids: List.unmodifiable(adminUids),
      intercomEnabled: data['intercomEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code,
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'adminUids': adminUids,
      'intercomEnabled': intercomEnabled,
    };
  }
}
