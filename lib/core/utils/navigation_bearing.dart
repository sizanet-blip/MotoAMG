import 'package:geolocator/geolocator.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

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
  return _polylineBearingAt(lat, lng, polyline) ?? 0;
}

/// Mezcla rumbo actual con el de un punto ~[lookAheadMeters] por delante.
double resolveLookAheadBearing({
  required double lat,
  required double lng,
  required double headingDegrees,
  required List<GeoPoint> polyline,
  double lookAheadMeters = 90,
  double blend = 0.32,
}) {
  if (polyline.length < 2 || blend <= 0) {
    return headingDegrees;
  }
  final ahead = _pointAheadOnPolyline(
    lat,
    lng,
    polyline,
    lookAheadMeters,
  );
  if (ahead == null) {
    return headingDegrees;
  }
  final target = Geolocator.bearingBetween(lat, lng, ahead.lat, ahead.lng);
  final delta = shortestBearingDelta(headingDegrees, target);
  return normalizeBearing(headingDegrees + delta * blend);
}

/// EMA + deadband para evitar temblores del puck/cámara.
class NavigationBearingFilter {
  double? _smoothed;

  double next(double rawDegrees, {required double speedMps}) {
    final raw = normalizeBearing(rawDegrees);
    final prev = _smoothed;
    if (prev == null) {
      _smoothed = raw;
      return raw;
    }
    final delta = shortestBearingDelta(prev, raw);
    final abs = delta.abs();
    if (abs < 1.2) {
      return prev;
    }
    if (abs < 3 && speedMps < 1.5) {
      return prev;
    }
    final alpha = speedMps < 3
        ? 0.18
        : speedMps < 12
            ? 0.28
            : 0.42;
    final next = normalizeBearing(prev + delta * alpha);
    _smoothed = next;
    return next;
  }

  void reset() => _smoothed = null;
}

double normalizeBearing(double degrees) {
  var d = degrees % 360;
  if (d < 0) {
    d += 360;
  }
  return d;
}

double shortestBearingDelta(double from, double to) {
  var d = normalizeBearing(to) - normalizeBearing(from);
  if (d > 180) {
    d -= 360;
  }
  if (d < -180) {
    d += 360;
  }
  return d;
}

double? _polylineBearingAt(double lat, double lng, List<GeoPoint> polyline) {
  if (polyline.length < 2) {
    return null;
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
  final nextIndex =
      closestIndex < polyline.length - 1 ? closestIndex + 1 : closestIndex;
  final from = polyline[closestIndex];
  final to = polyline[nextIndex];
  if (from == to) {
    return null;
  }
  return Geolocator.bearingBetween(from.lat, from.lng, to.lat, to.lng);
}

GeoPoint? _pointAheadOnPolyline(
  double lat,
  double lng,
  List<GeoPoint> polyline,
  double meters,
) {
  if (polyline.length < 2 || meters <= 0) {
    return null;
  }
  var closestIndex = 0;
  var minDistance = double.infinity;
  for (var i = 0; i < polyline.length; i++) {
    final d = Geolocator.distanceBetween(
      lat,
      lng,
      polyline[i].lat,
      polyline[i].lng,
    );
    if (d < minDistance) {
      minDistance = d;
      closestIndex = i;
    }
  }

  var remaining = meters;
  var cursor = GeoPoint(lat: lat, lng: lng);
  for (var i = closestIndex; i < polyline.length - 1; i++) {
    final next = polyline[i + 1];
    final seg = Geolocator.distanceBetween(
      cursor.lat,
      cursor.lng,
      next.lat,
      next.lng,
    );
    if (seg >= remaining || i == polyline.length - 2) {
      if (seg < 1e-3) {
        return next;
      }
      final t = (remaining / seg).clamp(0.0, 1.0);
      return GeoPoint(
        lat: cursor.lat + (next.lat - cursor.lat) * t,
        lng: cursor.lng + (next.lng - cursor.lng) * t,
      );
    }
    remaining -= seg;
    cursor = next;
  }
  return polyline.last;
}
