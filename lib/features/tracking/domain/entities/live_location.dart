import 'package:equatable/equatable.dart';

/// Posición en vivo de un integrante. Independiente de Realtime Database.
class LiveLocation extends Equatable {
  const LiveLocation({
    required this.uid,
    required this.groupId,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.speed,
    required this.updatedAt,
    required this.displayName,
    this.hasSignal = true,
  });

  final String uid;
  final String groupId;
  final double lat;
  final double lng;
  final double heading;
  final double speed;
  final DateTime updatedAt;
  final String displayName;
  final bool hasSignal;

  LiveLocation copyWith({
    String? uid,
    String? groupId,
    double? lat,
    double? lng,
    double? heading,
    double? speed,
    DateTime? updatedAt,
    String? displayName,
    bool? hasSignal,
  }) {
    return LiveLocation(
      uid: uid ?? this.uid,
      groupId: groupId ?? this.groupId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      updatedAt: updatedAt ?? this.updatedAt,
      displayName: displayName ?? this.displayName,
      hasSignal: hasSignal ?? this.hasSignal,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    groupId,
    lat,
    lng,
    heading,
    speed,
    updatedAt,
    displayName,
    hasSignal,
  ];
}
