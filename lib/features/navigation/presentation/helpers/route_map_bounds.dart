import 'dart:math' as math;

import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

LatLngBounds boundsForPoints(Iterable<GeoPoint> points) {
  var minLat = double.infinity;
  var maxLat = -double.infinity;
  var minLng = double.infinity;
  var maxLng = -double.infinity;

  for (final point in points) {
    minLat = math.min(minLat, point.lat);
    maxLat = math.max(maxLat, point.lat);
    minLng = math.min(minLng, point.lng);
    maxLng = math.max(maxLng, point.lng);
  }

  if (minLat == double.infinity) {
    return LatLngBounds(
      southwest: const LatLng(0, 0),
      northeast: const LatLng(0, 0),
    );
  }

  const minSpan = 0.004;
  if ((maxLat - minLat).abs() < minSpan) {
    final mid = (minLat + maxLat) / 2;
    minLat = mid - minSpan / 2;
    maxLat = mid + minSpan / 2;
  }
  if ((maxLng - minLng).abs() < minSpan) {
    final mid = (minLng + maxLng) / 2;
    minLng = mid - minSpan / 2;
    maxLng = mid + minSpan / 2;
  }

  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}
