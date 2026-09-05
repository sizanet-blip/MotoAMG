import 'dart:math' as math;

import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';

/// Detección de desvío y orientación básica hacia el tramo original.
class RouteDeviationService {
  bool isOffRoute({
    required GeoPoint position,
    required NavigationRoute route,
  }) {
    return distanceToPolylineMeters(position, route.polyline) >
        NavigationConstants.deviationThresholdMeters;
  }

  /// Distancia mínima del punto a la polilínea (metros, aproximación plana).
  double distanceToPolylineMeters(GeoPoint point, List<GeoPoint> polyline) {
    if (polyline.isEmpty) {
      return double.infinity;
    }
    if (polyline.length == 1) {
      return _haversineMeters(point, polyline.first);
    }
    var minDistance = double.infinity;
    for (var i = 0; i < polyline.length - 1; i++) {
      final d = _distanceToSegment(point, polyline[i], polyline[i + 1]);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }

  /// Punto más cercano en la ruta (para volver al trazado sin recalcular).
  GeoPoint? nearestPointOnRoute(
    GeoPoint position,
    List<GeoPoint> polyline,
  ) {
    if (polyline.isEmpty) {
      return null;
    }
    var best = polyline.first;
    var bestDistance = _haversineMeters(position, best);
    for (final point in polyline) {
      final d = _haversineMeters(position, point);
      if (d < bestDistance) {
        bestDistance = d;
        best = point;
      }
    }
    return best;
  }

  double _distanceToSegment(GeoPoint p, GeoPoint a, GeoPoint b) {
    final ax = a.lng;
    final ay = a.lat;
    final bx = b.lng;
    final by = b.lat;
    final px = p.lng;
    final py = p.lat;
    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) {
      return _haversineMeters(p, a);
    }
    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    final proj = GeoPoint(
      lat: ay + clamped * dy,
      lng: ax + clamped * dx,
    );
    return _haversineMeters(p, proj);
  }

  double _haversineMeters(GeoPoint a, GeoPoint b) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(b.lat - a.lat);
    final dLng = _toRadians(b.lng - a.lng);
    final lat1 = _toRadians(a.lat);
    final lat2 = _toRadians(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  double _toRadians(double deg) => deg * math.pi / 180;
}
