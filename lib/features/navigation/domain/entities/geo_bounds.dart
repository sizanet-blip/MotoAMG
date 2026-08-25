import 'package:equatable/equatable.dart';

/// Caja geográfica (WGS84) de una región de mapa offline.
class GeoBounds extends Equatable {
  const GeoBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  bool contains(double latitude, double longitude) {
    return longitude >= west &&
        longitude <= east &&
        latitude >= south &&
        latitude <= north;
  }

  @override
  List<Object?> get props => [west, south, east, north];
}
