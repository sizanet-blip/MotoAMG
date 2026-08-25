import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:loc_motos/features/navigation/domain/entities/speed_limit_segment.dart';

/// Ruta calculada lista para navegar (online o desde caché).
class NavigationRoute extends Equatable {
  const NavigationRoute({
    required this.id,
    required this.origin,
    required this.destination,
    required this.polyline,
    required this.maneuvers,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.createdAt,
    this.waypoints = const [],
    this.speedLimitKmh,
    this.speedLimitSegments = const [],
    this.originLabel,
    this.destinationLabel,
  });

  final String id;
  final GeoPoint origin;
  final GeoPoint destination;

  /// Paradas intermedias entre origen y destino (orden del itinerario).
  final List<GeoPoint> waypoints;

  final List<GeoPoint> polyline;
  final List<NavigationManeuver> maneuvers;
  final double distanceMeters;
  final int durationSeconds;
  final DateTime createdAt;

  /// Límite de referencia (p. ej. primer tramo); el HUD usa [speedLimitSegments].
  final int? speedLimitKmh;

  /// Límites a lo largo de la polilínea (índices de forma Valhalla).
  final List<SpeedLimitSegment> speedLimitSegments;

  /// Texto legible del origen (dirección o "Mi ubicación").
  final String? originLabel;

  /// Texto legible del destino (dirección buscada).
  final String? destinationLabel;

  bool get hasWaypoints => waypoints.isNotEmpty;

  NavigationManeuver? get firstManeuver =>
      maneuvers.isEmpty ? null : maneuvers.first;

  String get originDisplay {
    final label = originLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return _coordLabel(origin);
  }

  String get destinationDisplay {
    final label = destinationLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return _coordLabel(destination);
  }

  static String _coordLabel(GeoPoint point) =>
      '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}';

  @override
  List<Object?> get props => [
        id,
        origin,
        destination,
        waypoints,
        polyline,
        maneuvers,
        distanceMeters,
        durationSeconds,
        createdAt,
        speedLimitKmh,
        speedLimitSegments,
        originLabel,
        destinationLabel,
      ];
}
