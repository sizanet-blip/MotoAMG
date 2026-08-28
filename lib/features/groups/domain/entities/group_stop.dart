import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

/// Parada planificada visible para todo el grupo en el mapa.
enum GroupStopType {
  cafe,
  gasolinera,
  esperarAqui,
  reunion,
}

extension GroupStopTypeX on GroupStopType {
  String get label => switch (this) {
        GroupStopType.cafe => 'Café / descanso',
        GroupStopType.gasolinera => 'Gasolinera',
        GroupStopType.esperarAqui => 'Esperar aquí',
        GroupStopType.reunion => 'Punto de reunión',
      };

  String get shortLabel => switch (this) {
        GroupStopType.cafe => 'Café',
        GroupStopType.gasolinera => 'Gasolinera',
        GroupStopType.esperarAqui => 'Esperar aquí',
        GroupStopType.reunion => 'Reunión',
      };

  String get storageValue => name;

  static GroupStopType? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    for (final type in GroupStopType.values) {
      if (type.name == raw) {
        return type;
      }
    }
    return null;
  }
}

class GroupStop extends Equatable {
  const GroupStop({
    required this.id,
    required this.type,
    required this.point,
    required this.at,
    required this.createdBy,
    this.displayName,
    this.active = true,
  });

  final String id;
  final GroupStopType type;
  final GeoPoint point;
  final DateTime at;
  final String createdBy;
  final String? displayName;
  final bool active;

  Map<String, dynamic> toRtdb() => {
        'type': type.storageValue,
        'lat': point.lat,
        'lng': point.lng,
        'at': at.toIso8601String(),
        'createdBy': createdBy,
        'active': active,
        if (displayName != null) 'displayName': displayName,
      };

  factory GroupStop.fromRtdb(String id, Map<dynamic, dynamic> data) {
    return GroupStop(
      id: id,
      type: GroupStopTypeX.tryParse(data['type']?.toString()) ??
          GroupStopType.esperarAqui,
      point: GeoPoint(
        lat: (data['lat'] as num?)?.toDouble() ?? 0,
        lng: (data['lng'] as num?)?.toDouble() ?? 0,
      ),
      at: DateTime.tryParse(data['at']?.toString() ?? '') ?? DateTime.now(),
      createdBy: data['createdBy']?.toString() ?? '',
      displayName: data['displayName']?.toString(),
      active: data['active'] != false,
    );
  }

  @override
  List<Object?> get props => [id, type, point, at, createdBy, displayName, active];
}
