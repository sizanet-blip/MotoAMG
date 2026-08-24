import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

/// Rumbo de navegación: GPS si hay brújula, si no el tramo de ruta más cercano.
double resolveNavigationBearing({
  required double lat,
  required double lng,
  double? headingDegrees,
  required List<GeoPoint> polyline,
}) {
  if (headingDegrees != null && headingDegrees >= 0) {
    return headingDegrees;
  }
  if (polyline.length < 2) {
    return 0;
  }

  var closestIndex = 0;
  var minDistance = double.infinity;
  for (var i = 0; i < polyline.length; i++) {
    final point = polyline[i];
    final distance = Geolocator.distanceBetween(
      lat,
      lng,
      point.lat,
      point.lng,
    );
    if (distance < minDistance) {
      minDistance = distance;
      closestIndex = i;
    }
  }

  final nextIndex = closestIndex < polyline.length - 1
      ? closestIndex + 1
      : closestIndex;
  final from = polyline[closestIndex];
  final to = polyline[nextIndex];
  if (from == to) {
    return 0;
  }
  return Geolocator.bearingBetween(from.lat, from.lng, to.lat, to.lng);
}
