import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/lane_guidance.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';
import 'package:loc_motos/features/navigation/domain/entities/speed_limit_segment.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:loc_motos/features/navigation/domain/services/dgt_speed_limit_resolver.dart';

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
    super.waypoints,
    super.speedLimitKmh,
    super.speedLimitSegments,
    super.alerts,
    super.originLabel,
    super.destinationLabel,
  });

  NavigationRouteModel copyWithLabels({
    String? originLabel,
    String? destinationLabel,
  }) {
    return NavigationRouteModel(
      id: id,
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      polyline: polyline,
      maneuvers: maneuvers,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      createdAt: createdAt,
      speedLimitKmh: speedLimitKmh,
      speedLimitSegments: speedLimitSegments,
      alerts: alerts,
      originLabel: originLabel ?? this.originLabel,
      destinationLabel: destinationLabel ?? this.destinationLabel,
    );
  }

  NavigationRouteModel copyWithSpeedLimits(
    List<SpeedLimitSegment> segments,
  ) {
    return NavigationRouteModel(
      id: id,
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      polyline: polyline,
      maneuvers: maneuvers,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      createdAt: createdAt,
      speedLimitKmh: segments.isEmpty ? speedLimitKmh : segments.first.speedLimitKmh,
      speedLimitSegments: segments,
      alerts: alerts,
      originLabel: originLabel,
      destinationLabel: destinationLabel,
    );
  }

  NavigationRouteModel copyWithAlerts(List<RouteAlert> alerts) {
    return NavigationRouteModel(
      id: id,
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      polyline: polyline,
      maneuvers: maneuvers,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      createdAt: createdAt,
      speedLimitKmh: speedLimitKmh,
      speedLimitSegments: speedLimitSegments,
      alerts: List.unmodifiable(alerts),
      originLabel: originLabel,
      destinationLabel: destinationLabel,
    );
  }

  factory NavigationRouteModel.fromValhalla(
    Map<String, dynamic> json, {
    required GeoPoint origin,
    required GeoPoint destination,
    List<GeoPoint> waypoints = const [],
    List<SpeedLimitSegment> speedLimitSegments = const [],
    String? id,
  }) {
    final trip = json['trip'] as Map<String, dynamic>?;
    final legs = trip?['legs'] as List<dynamic>? ?? const [];
    if (legs.isEmpty) {
      throw const RouteNotFoundException();
    }

    const lengthToMeters = 1000.0;
    final polyline = <GeoPoint>[];
    final maneuvers = <NavigationManeuver>[];
    var totalDistanceMeters = 0.0;
    var totalDurationSeconds = 0;
    var maneuverIndex = 0;

    for (final legDyn in legs) {
      final leg = legDyn as Map<String, dynamic>;
      final summary = leg['summary'] as Map<String, dynamic>? ?? const {};
      final maneuversJson = leg['maneuvers'] as List<dynamic>? ?? const [];
      final shape = leg['shape'] as String? ?? '';
      final legPolyline = decodePolyline6(shape);
      final shapeOffset = polyline.length;

      totalDistanceMeters +=
          ((summary['length'] as num?)?.toDouble() ?? 0) * lengthToMeters;
      totalDurationSeconds += (summary['time'] as num?)?.round() ?? 0;

      if (legPolyline.isEmpty) {
        continue;
      }
      // Concatenar tramos; el punto de enlace puede repetirse (inofensivo).
      polyline.addAll(legPolyline);

      for (final raw in maneuversJson) {
        final m = raw as Map<String, dynamic>;
        final beginShapeIndex = (m['begin_shape_index'] as num?)?.toInt() ?? 0;
        final absoluteIndex = shapeOffset + beginShapeIndex;
        final clampedIndex = polyline.isEmpty
            ? 0
            : absoluteIndex.clamp(0, polyline.length - 1);
        final location =
            polyline.isEmpty ? origin : polyline[clampedIndex];
        final shortInstruction =
            (m['instruction'] as String?)?.trim().isNotEmpty == true
                ? (m['instruction'] as String).trim()
                : null;
        final verbal =
            (m['verbal_pre_transition_instruction'] as String?)?.trim();
        final lanesJson = m['lanes'] as List<dynamic>? ?? const [];
        final lanes = <LaneInfo>[
          for (final raw in lanesJson)
            if (raw is Map<String, dynamic>) LaneInfo.fromValhalla(raw)
            else if (raw is Map)
              LaneInfo.fromValhalla(Map<String, dynamic>.from(raw)),
        ];
        maneuvers.add(
          NavigationManeuver(
            index: maneuverIndex++,
            type: _maneuverType(m['type'] as int? ?? 0),
            instruction: shortInstruction ?? verbal ?? 'Continúa',
            voiceInstruction: verbal,
            distanceMeters:
                ((m['length'] as num?)?.toDouble() ?? 0) * lengthToMeters,
            location: location,
            beginShapeIndex: clampedIndex,
            streetName: m['street_names'] is List &&
                    (m['street_names'] as List).isNotEmpty
                ? (m['street_names'] as List).first.toString()
                : null,
            lanes: List.unmodifiable(lanes),
            roundaboutExit: m['roundabout_exit_count'] as int?,
          ),
        );
      }
    }

    // Preferir resumen global del viaje si Valhalla lo envía.
    final tripSummary = trip?['summary'] as Map<String, dynamic>?;
    if (tripSummary != null) {
      totalDistanceMeters =
          ((tripSummary['length'] as num?)?.toDouble() ?? 0) * lengthToMeters;
      totalDurationSeconds = (tripSummary['time'] as num?)?.round() ?? 0;
    }

    final now = DateTime.now();
    return NavigationRouteModel(
      id: id ?? now.millisecondsSinceEpoch.toString(),
      origin: origin,
      destination: destination,
      waypoints: List.unmodifiable(waypoints),
      polyline: List.unmodifiable(polyline),
      maneuvers: List.unmodifiable(maneuvers),
      distanceMeters: totalDistanceMeters,
      durationSeconds: totalDurationSeconds,
      createdAt: now,
      speedLimitKmh: speedLimitSegments.isEmpty
          ? null
          : speedLimitSegments.first.speedLimitKmh,
      speedLimitSegments: speedLimitSegments,
    );
  }

  /// Une tramos consecutivos con el mismo límite.
  static List<SpeedLimitSegment> coalesceSpeedLimits(
    Iterable<SpeedLimitSegment> raw,
  ) {
    final segments = <SpeedLimitSegment>[];
    for (final next in raw) {
      if (next.speedLimitKmh <= 0) {
        continue;
      }
      if (segments.isEmpty) {
        segments.add(next);
        continue;
      }
      final last = segments.last;
      if (last.speedLimitKmh == next.speedLimitKmh &&
          next.beginShapeIndex <= last.endShapeIndex + 1) {
        segments[segments.length - 1] = SpeedLimitSegment(
          beginShapeIndex: last.beginShapeIndex,
          endShapeIndex: next.endShapeIndex > last.endShapeIndex
              ? next.endShapeIndex
              : last.endShapeIndex,
          speedLimitKmh: last.speedLimitKmh,
        );
      } else {
        segments.add(next);
      }
    }
    return List.unmodifiable(segments);
  }

  static List<SpeedLimitSegment> speedLimitsFromTraceAttributes(
    Map<String, dynamic> json, {
    int Function(int matchedIndex)? toRouteShapeIndex,
  }) {
    final edges = json['edges'] as List<dynamic>? ?? const [];
    final raw = <SpeedLimitSegment>[];
    for (final edge in edges) {
      if (edge is! Map<String, dynamic>) {
        continue;
      }
      final limit = resolveEdgeSpeedLimitKmh(edge);
      if (limit == null) {
        continue;
      }
      final beginMatched = (edge['begin_shape_index'] as num?)?.toInt() ?? 0;
      final endMatched =
          (edge['end_shape_index'] as num?)?.toInt() ?? beginMatched;
      final begin = toRouteShapeIndex?.call(beginMatched) ?? beginMatched;
      final end = toRouteShapeIndex?.call(endMatched) ?? endMatched;
      raw.add(
        SpeedLimitSegment(
          beginShapeIndex: begin <= end ? begin : end,
          endShapeIndex: begin <= end ? end : begin,
          speedLimitKmh: limit,
        ),
      );
    }
    return coalesceSpeedLimits(raw);
  }

  /// Prioridad: maxspeed OSM/Valhalla → fallback genérico DGT por clase de vía.
  static int? resolveEdgeSpeedLimitKmh(Map<String, dynamic> edge) {
    final posted = (edge['speed_limit'] as num?)?.round();
    if (posted != null && posted > 0 && posted <= 160) {
      return posted;
    }
    return DgtSpeedLimitResolver.fromValhallaEdge(edge);
  }

  factory NavigationRouteModel.demo({
    required GeoPoint origin,
    required GeoPoint destination,
    List<GeoPoint> waypoints = const [],
  }) {
    final points = <GeoPoint>[origin, ...waypoints, destination];
    final polyline = <GeoPoint>[];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      polyline.add(a);
      polyline.add(
        GeoPoint(lat: (a.lat + b.lat) / 2, lng: (a.lng + b.lng) / 2),
      );
    }
    polyline.add(destination);
    final maneuvers = <NavigationManeuver>[
      NavigationManeuver(
        index: 0,
        type: ManeuverType.depart,
        instruction: 'Sal de tu posición actual',
        distanceMeters: 200,
        location: origin,
        beginShapeIndex: 0,
      ),
      for (var i = 0; i < waypoints.length; i++)
        NavigationManeuver(
          index: i + 1,
          type: ManeuverType.arrive,
          instruction: 'Parada ${i + 1}',
          distanceMeters: 0,
          location: waypoints[i],
          beginShapeIndex: (i * 2 + 2).clamp(0, polyline.length - 1),
        ),
      NavigationManeuver(
        index: waypoints.length + 1,
        type: ManeuverType.arrive,
        instruction: 'Has llegado al destino',
        distanceMeters: 0,
        location: destination,
        beginShapeIndex: polyline.length - 1,
      ),
    ];
    const segments = [
      SpeedLimitSegment(
        beginShapeIndex: 0,
        endShapeIndex: 1,
        speedLimitKmh: 50,
      ),
      SpeedLimitSegment(
        beginShapeIndex: 1,
        endShapeIndex: 2,
        speedLimitKmh: 90,
      ),
    ];
    return NavigationRouteModel(
      id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
      origin: origin,
      destination: destination,
      waypoints: List.unmodifiable(waypoints),
      polyline: polyline,
      maneuvers: maneuvers,
      distanceMeters: 8500.0 * (waypoints.length + 1),
      durationSeconds: 720 * (waypoints.length + 1),
      createdAt: DateTime.now(),
      speedLimitKmh: 50,
      speedLimitSegments: segments,
    );
  }

  factory NavigationRouteModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> asMap(dynamic raw) =>
        Map<String, dynamic>.from(raw as Map);

    final segmentsJson = json['speedLimitSegments'] as List<dynamic>?;
    final segments = segmentsJson == null
        ? const <SpeedLimitSegment>[]
        : segmentsJson
            .whereType<Map>()
            .map((raw) => SpeedLimitSegment.fromJson(asMap(raw)))
            .toList(growable: false);
    final waypointsJson = json['waypoints'] as List<dynamic>?;
    final waypoints = waypointsJson == null
        ? const <GeoPoint>[]
        : waypointsJson
            .whereType<Map>()
            .map((point) {
              final map = asMap(point);
              return GeoPoint(
                lat: (map['lat'] as num).toDouble(),
                lng: (map['lng'] as num).toDouble(),
              );
            })
            .toList(growable: false);
    final alertsJson = json['alerts'] as List<dynamic>?;
    final alerts = alertsJson == null
        ? const <RouteAlert>[]
        : alertsJson
            .whereType<Map>()
            .map((raw) => RouteAlert.fromJson(asMap(raw)))
            .toList(growable: false);
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
      waypoints: waypoints,
      polyline: (json['polyline'] as List<dynamic>)
          .whereType<Map>()
          .map((point) {
            final map = asMap(point);
            return GeoPoint(
              lat: (map['lat'] as num).toDouble(),
              lng: (map['lng'] as num).toDouble(),
            );
          })
          .toList(),
      maneuvers: (json['maneuvers'] as List<dynamic>)
          .whereType<Map>()
          .map((raw) {
            final m = asMap(raw);
            return NavigationManeuver(
              index: (m['index'] as num).toInt(),
              type: ManeuverType.values[(m['type'] as num).toInt()],
              instruction: m['instruction'] as String,
              distanceMeters: (m['distanceMeters'] as num).toDouble(),
              location: GeoPoint(
                lat: (m['lat'] as num).toDouble(),
                lng: (m['lng'] as num).toDouble(),
              ),
              beginShapeIndex: (m['beginShapeIndex'] as num?)?.toInt() ?? 0,
              streetName: m['streetName'] as String?,
              laneHint: m['laneHint'] as String?,
              lanes: (m['lanes'] as List<dynamic>? ?? const [])
                  .whereType<Map>()
                  .map((lane) => LaneInfo.fromJson(asMap(lane)))
                  .toList(growable: false),
              roundaboutExit: (m['roundaboutExit'] as num?)?.toInt(),
              voiceInstruction: m['voiceInstruction'] as String?,
            );
          })
          .toList(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      speedLimitKmh: (json['speedLimitKmh'] as num?)?.toInt(),
      speedLimitSegments: segments,
      alerts: alerts,
      originLabel: json['originLabel'] as String?,
      destinationLabel: json['destinationLabel'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originLat': origin.lat,
      'originLng': origin.lng,
      'destinationLat': destination.lat,
      'destinationLng': destination.lng,
      'waypoints': waypoints
          .map((point) => {'lat': point.lat, 'lng': point.lng})
          .toList(growable: false),
      'originLabel': originLabel,
      'destinationLabel': destinationLabel,
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
              'beginShapeIndex': m.beginShapeIndex,
              'streetName': m.streetName,
              'laneHint': m.laneHint,
              'lanes': m.lanes.map((l) => l.toJson()).toList(growable: false),
              'roundaboutExit': m.roundaboutExit,
              'voiceInstruction': m.voiceInstruction,
            },
          )
          .toList(),
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
      'speedLimitKmh': speedLimitKmh,
      'speedLimitSegments':
          speedLimitSegments.map((s) => s.toJson()).toList(growable: false),
      'alerts': alerts.map((a) => a.toJson()).toList(growable: false),
    };
  }

  static ManeuverType _maneuverType(int type) {
    // Códigos oficiales Valhalla (directions.proto).
    return switch (type) {
      1 || 2 || 3 => ManeuverType.depart,
      4 || 5 || 6 => ManeuverType.arrive,
      8 || 22 => ManeuverType.continueStraight,
      9 || 10 || 11 => ManeuverType.turnRight,
      12 || 13 => ManeuverType.turn, // cambio de sentido
      14 || 15 || 16 => ManeuverType.turnLeft,
      17 || 18 || 19 || 20 || 21 => ManeuverType.ramp,
      23 || 24 => ManeuverType.continueStraight,
      25 || 37 || 38 => ManeuverType.merge,
      26 || 27 => ManeuverType.roundabout,
      _ => ManeuverType.unknown,
    };
  }

  /// Expone el mapeo Valhalla→dominio para tests.
  static ManeuverType mapValhallaManeuverType(int type) => _maneuverType(type);

  /// Decodifica polyline6 de Valhalla (precisión 1e6).
  static List<GeoPoint> decodePolyline6(String encoded) {
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
