import 'package:equatable/equatable.dart';

class GroupMember extends Equatable {
  const GroupMember({
    required this.uid,
    required this.displayName,
    required this.joinedAt,
    this.isSharingLocation = true,
    this.bikeBrand,
    this.bikeModel,
    this.bikePlate,
  });

  final String uid;
  final String displayName;
  final DateTime joinedAt;
  final bool isSharingLocation;
  final String? bikeBrand;
  final String? bikeModel;
  final String? bikePlate;

  String get bikeLabel {
    final parts = [
      bikeBrand,
      bikeModel,
    ].where((value) => value != null && value.trim().isNotEmpty);
    return parts.map((value) => value!.trim()).join(' ');
  }

  @override
  List<Object?> get props => [
    uid,
    displayName,
    joinedAt,
    isSharingLocation,
    bikeBrand,
    bikeModel,
    bikePlate,
  ];
}
