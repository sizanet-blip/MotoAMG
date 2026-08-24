import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';

class NavigationRouteModel extends NavigationRoute {
  const NavigationRouteModel({
    required super.id,
    required super.origin,
    required super.destination,
    required super.polyline,
    required super.maneuvers,
    required super.distanceMeters,
    required super.durationSeconds,
    required super.createdAt,
    super.speedLimitKmh,
  });

  factory NavigationRouteModel.fromValhalla(
    Map<String, dynamic> json, {
    required GeoPoint origin,
    required GeoPoint destination,
  }) {
    final trip = json['trip'] as Map<String, dynamic>?;
    final legs = trip?['legs'] as List<dynamic>? ?? const [];
    if (legs.isEmpty) {
      throw const RouteNotFoundException();
    }
    final leg = legs.first as Map<String, dynamic>;
    final summary = leg['summary'] as Map<String, dynamic>? ?? const {};
    final maneuversJson = leg['maneuvers'] as List<dynamic>? ?? const [];
    final shape = leg['shape'] as String? ?? '';
    // Valhalla devuelve longitudes en km cuando units=kilometers.
    const lengthToMeters = 1000.0;
    final maneuvers = <NavigationManeuver>[];
    for (var i = 0; i < maneuversJson.length; i++) {
      final m = maneuversJson[i] as Map<String, dynamic>;
      maneuvers.add(
        NavigationManeuver(
          index: i,
          type: _maneuverType(m['type'] as int? ?? 0),
          instruction: (m['verbal_pre_transition_instruction'] as String?) ??
              (m['instruction'] as String? ?? 'Continúa'),
          distanceMeters:
              ((m['length'] as num?)?.toDouble() ?? 0) * lengthToMeters,
          location: GeoPoint(
            lat: (m['lat'] as num?)?.toDouble() ?? origin.lat,
            lng: (m['lon'] as num?)?.toDouble() ?? origin.lng,
          ),
          streetName: m['street_names'] is List && (m['street_names'] as List).isNotEmpty
              ? (m['street_names'] as List).first.toString()
              : null,
          roundaboutExit: m['roundabout_exit_count'] as int?,
        ),
      );
    }
    return NavigationRouteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      origin: origin,
      destination: destination,
      polyline: _decodePolyline6(shape),
      maneuvers: maneuvers,
      distanceMeters:
          ((summary['length'] as num?)?.toDouble() ?? 0) * lengthToMeters,
      durationSeconds: (summary['time'] as num?)?.round() ?? 0,
      createdAt: DateTime.now(),
    );
  }

  factory NavigationRouteModel.demo({
    required GeoPoint origin,
    required GeoPoint destination,
  }) {
    final mid = GeoPoint(
      lat: (origin.lat + destination.lat) / 2,
      lng: (origin.lng + destination.lng) / 2,
    );
    return NavigationRouteModel(
      id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
      origin: origin,
      destination: destination,
      polyline: [origin, mid, destination],
      maneuvers: [
        NavigationManeuver(
          index: 0,
          type: ManeuverType.depart,
          instruction: 'Sal de tu posición actual',
          distanceMeters: 200,
          location: origin,
        ),
        NavigationManeuver(
          index: 1,
          type: ManeuverType.turn,
          instruction: 'Gira a la derecha hacia la carretera secundaria',
          distanceMeters: 1200,
          location: mid,
          streetName: 'Carretera demo',
        ),
        NavigationManeuver(
          index: 2,
          type: ManeuverType.arrive,
          instruction: 'Has llegado al destino',
          distanceMeters: 0,
          location: destination,
        ),
      ],
      distanceMeters: 8500,
      durationSeconds: 720,
      createdAt: DateTime.now(),
      speedLimitKmh: 90,
    );
  }

  factory NavigationRouteModel.fromJson(Map<String, dynamic> json) {
    return NavigationRouteModel(
      id: json['id'] as String,
      origin: GeoPoint(
        lat: (json['originLat'] as num).toDouble(),
        lng: (json['originLng'] as num).toDouble(),
      ),
      destination: GeoPoint(
        lat: (json['destinationLat'] as num).toDouble(),
        lng: (json['destinationLng'] as num).toDouble(),
      ),
      polyline: (json['polyline'] as List<dynamic>)
          .map(
            (point) => GeoPoint(
              lat: (point['lat'] as num).toDouble(),
              lng: (point['lng'] as num).toDouble(),
            ),
          )
          .toList(),
      maneuvers: (json['maneuvers'] as List<dynamic>)
          .map(
            (m) => NavigationManeuver(
              index: m['index'] as int,
              type: ManeuverType.values[m['type'] as int],
              instruction: m['instruction'] as String,
              distanceMeters: (m['distanceMeters'] as num).toDouble(),
              location: GeoPoint(
                lat: (m['lat'] as num).toDouble(),
                lng: (m['lng'] as num).toDouble(),
              ),
              streetName: m['streetName'] as String?,
              laneHint: m['laneHint'] as String?,
              roundaboutExit: m['roundaboutExit'] as int?,
            ),
          )
          .toList(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      durationSeconds: json['durationSeconds'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      speedLimitKmh: json['speedLimitKmh'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originLat': origin.lat,
      'originLng': origin.lng,
      'destinationLat': destination.lat,
      'destinationLng': destination.lng,
      'polyline': polyline
          .map((point) => {'lat': point.lat, 'lng': point.lng})
          .toList(),
      'maneuvers': maneuvers
          .map(
            (m) => {
              'index': m.index,
              'type': m.type.index,
              'instruction': m.instruction,
              'distanceMeters': m.distanceMeters,
              'lat': m.location.lat,
              'lng': m.location.lng,
              'streetName': m.streetName,
              'laneHint': m.laneHint,
              'roundaboutExit': m.roundaboutExit,
            },
          )
          .toList(),
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
      'speedLimitKmh': speedLimitKmh,
    };
  }

  static ManeuverType _maneuverType(int type) {
    return switch (type) {
      1 || 2 => ManeuverType.depart,
      4 || 5 || 6 => ManeuverType.turn,
      10 || 11 => ManeuverType.roundabout,
      15 => ManeuverType.merge,
      16 || 17 || 18 => ManeuverType.ramp,
      20 => ManeuverType.arrive,
      8 => ManeuverType.continueStraight,
      _ => ManeuverType.unknown,
    };
  }

  /// Decodifica polyline6 de Valhalla (precisión 1e6).
  static List<GeoPoint> _decodePolyline6(String encoded) {
    if (encoded.isEmpty) {
      return const [];
    }
    final points = <GeoPoint>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;
      points.add(GeoPoint(lat: lat / 1e6, lng: lng / 1e6));
    }
    return points;
  }
}
