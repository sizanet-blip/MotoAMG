import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';

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
    this.speedLimitKmh,
  });

  final String id;
  final GeoPoint origin;
  final GeoPoint destination;
  final List<GeoPoint> polyline;
  final List<NavigationManeuver> maneuvers;
  final double distanceMeters;
  final int durationSeconds;
  final DateTime createdAt;
  final int? speedLimitKmh;

  NavigationManeuver? get firstManeuver =>
      maneuvers.isEmpty ? null : maneuvers.first;

  @override
  List<Object?> get props => [
    id,
    origin,
    destination,
    polyline,
    maneuvers,
    distanceMeters,
    durationSeconds,
    createdAt,
    speedLimitKmh,
  ];
}
