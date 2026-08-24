import 'package:equatable/equatable.dart';

/// Punto geográfico WGS84 usado en rutas y maniobras.
class GeoPoint extends Equatable {
  const GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  List<Object?> get props => [lat, lng];
}
