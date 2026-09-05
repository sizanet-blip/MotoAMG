import 'dart:math' as math;

import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/domain/services/maneuver_significance.dart';

/// Guidance estilo Waze/Sygic: cartel = próximo punto de decisión + metros hasta él.
class RouteGuidanceService {
  /// Distancia recorrida desde el inicio de la ruta hasta el punto más cercano.
  double distanceAlongRouteMeters(GeoPoint position, List<GeoPoint> polyline) {
    if (polyline.isEmpty) {
      return 0;
    }
    if (polyline.length == 1) {
      return 0;
    }

    var bestAlong = 0.0;
    var bestDist = double.infinity;
    var cumulative = 0.0;

    for (var i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final segmentLength = _haversineMeters(a, b);
      final projected = _projectOnSegment(position, a, b);
      final d = _haversineMeters(position, projected.point);
      if (d < bestDist) {
        bestDist = d;
        bestAlong = cumulative + projected.t * segmentLength;
      }
      cumulative += segmentLength;
    }
    return bestAlong;
  }

  /// Metros desde el inicio hasta el vértice [shapeIndex].
  double distanceAtShapeIndex(List<GeoPoint> polyline, int shapeIndex) {
    if (polyline.length < 2 || shapeIndex <= 0) {
      return 0;
    }
    final last = math.min(shapeIndex, polyline.length - 1);
    var total = 0.0;
    for (var i = 0; i < last; i++) {
      total += _haversineMeters(polyline[i], polyline[i + 1]);
    }
    return total;
  }

  /// Índice del aviso a mostrar: la próxima maniobra cuyo punto aún no has pasado.
  ///
  /// Tras pasar el punto del giro (+ [passedThresholdMeters]), salta al siguiente.
  int resolveUpcomingManeuverIndex({
    required GeoPoint position,
    required NavigationRoute route,
    double passedThresholdMeters =
        NavigationConstants.maneuverPassedThresholdMeters,
  }) {
    final maneuvers = route.maneuvers;
    if (maneuvers.isEmpty) {
      return 0;
    }
    final along = distanceAlongRouteMeters(position, route.polyline);

    int? nearestIndex;
    var nearestBeginAlong = double.infinity;

    for (var i = 0; i < maneuvers.length; i++) {
      if (!_isSignificantUpcoming(route, i)) {
        continue;
      }
      final beginAlong = distanceAtShapeIndex(
        route.polyline,
        maneuvers[i].beginShapeIndex,
      );
      if (along > beginAlong + passedThresholdMeters) {
        continue;
      }
      if (beginAlong < nearestBeginAlong) {
        nearestBeginAlong = beginAlong;
        nearestIndex = i;
      }
    }
    if (nearestIndex != null) {
      return nearestIndex;
    }
    for (var i = maneuvers.length - 1; i >= 0; i--) {
      if (_isSignificantUpcoming(route, i)) {
        return i;
      }
    }
    return maneuvers.length - 1;
  }

  /// True si el cartel de maniobras debe mostrarse (giro real y distancia útil).
  bool shouldShowManeuverCard({
    required NavigationRoute route,
    required int upcomingIndex,
    required double remainingMeters,
  }) {
    if (remainingMeters <= 0 ||
        remainingMeters > NavigationConstants.maneuverMaxLookaheadMeters) {
      return false;
    }
    final maneuvers = route.maneuvers;
    if (maneuvers.isEmpty || upcomingIndex < 0 || upcomingIndex >= maneuvers.length) {
      return false;
    }
    final maneuver = maneuvers[upcomingIndex];
    return ManeuverSignificance.isSignificantNavigationManeuver(
      maneuver,
      next: upcomingIndex + 1 < maneuvers.length
          ? maneuvers[upcomingIndex + 1]
          : null,
      previous: upcomingIndex > 0 ? maneuvers[upcomingIndex - 1] : null,
    );
  }

  bool _isSignificantUpcoming(NavigationRoute route, int index) {
    final maneuvers = route.maneuvers;
    final maneuver = maneuvers[index];
    return ManeuverSignificance.isSignificantNavigationManeuver(
      maneuver,
      next: index + 1 < maneuvers.length ? maneuvers[index + 1] : null,
      previous: index > 0 ? maneuvers[index - 1] : null,
    );
  }

  /// Metros que faltan hasta el punto del aviso [upcomingIndex] (cuenta atrás a 0).
  double remainingMetersToUpcoming({
    required GeoPoint position,
    required NavigationRoute route,
    required int upcomingIndex,
  }) {
    final maneuvers = route.maneuvers;
    if (maneuvers.isEmpty || route.polyline.isEmpty) {
      return 0;
    }
    final index = upcomingIndex.clamp(0, maneuvers.length - 1);
    final beginAlong = distanceAtShapeIndex(
      route.polyline,
      maneuvers[index].beginShapeIndex,
    );
    final along = distanceAlongRouteMeters(position, route.polyline);
    return math.max(0, beginAlong - along);
  }

  /// Metros que faltan hasta el destino a lo largo de la ruta.
  double remainingRouteMeters({
    required GeoPoint position,
    required NavigationRoute route,
  }) {
    if (route.polyline.isEmpty) {
      return math.max(0, route.distanceMeters);
    }
    final along = distanceAlongRouteMeters(position, route.polyline);
    final total = route.distanceMeters > 0
        ? route.distanceMeters
        : _polylineLengthMeters(route.polyline);
    return math.max(0, total - along);
  }

  /// Tiempo restante estimado: velocidad actual si te mueves; si no, prorrateo Valhalla.
  Duration estimateRemainingDuration({
    required double remainingMeters,
    required double speedMps,
    required int routeDurationSeconds,
    required double routeDistanceMeters,
    double minSpeedMps = 1.4, // ~5 km/h
  }) {
    if (remainingMeters <= 0) {
      return Duration.zero;
    }
    if (speedMps >= minSpeedMps) {
      final seconds = (remainingMeters / speedMps).round();
      return Duration(seconds: seconds.clamp(0, 24 * 3600));
    }
    if (routeDistanceMeters <= 0 || routeDurationSeconds <= 0) {
      return Duration(seconds: routeDurationSeconds.clamp(0, 24 * 3600));
    }
    final fraction =
        (remainingMeters / routeDistanceMeters).clamp(0.0, 1.0);
    return Duration(
      seconds: (routeDurationSeconds * fraction).round().clamp(0, 24 * 3600),
    );
  }

  /// Metros en línea recta hasta el destino.
  double distanceToDestinationMeters({
    required GeoPoint position,
    required NavigationRoute route,
  }) {
    return _haversineMeters(position, route.destination);
  }

  /// True si estás lo bastante cerca del destino para dar por terminada la ruta.
  bool hasArrived({
    required GeoPoint position,
    required NavigationRoute route,
    double thresholdMeters = NavigationConstants.arrivalThresholdMeters,
    double maxAlongRemainingMeters =
        NavigationConstants.arrivalMaxAlongRemainingMeters,
  }) {
    final alongRemaining = remainingRouteMeters(
      position: position,
      route: route,
    );
    // Si aún queda mucho trazado, no has llegado (aunque pases cerca del pin).
    if (alongRemaining > maxAlongRemainingMeters) {
      return false;
    }
    final straight = distanceToDestinationMeters(
      position: position,
      route: route,
    );
    if (straight <= thresholdMeters) {
      return true;
    }
    // Casi al final del trazado y cerca del pin (aparcamiento / acera).
    return alongRemaining <= thresholdMeters &&
        straight <= thresholdMeters * 2.5;
  }

  /// Límite legal en el tramo actual (km/h), o null si no hay dato fiable.
  int? resolveSpeedLimitKmh({
    required GeoPoint position,
    required NavigationRoute route,
  }) {
    final segments = route.speedLimitSegments;
    if (segments.isEmpty) {
      return route.speedLimitKmh;
    }
    final along = distanceAlongRouteMeters(position, route.polyline);
    final shapeIndex = shapeIndexAtDistance(route.polyline, along);
    // Solo dentro del tramo: no arrastrar un 50 urbano al siguiente vacío.
    for (final segment in segments) {
      if (shapeIndex < segment.beginShapeIndex) {
        return null;
      }
      if (shapeIndex <= segment.endShapeIndex) {
        return segment.speedLimitKmh;
      }
    }
    return null;
  }

  /// Índice de polilínea correspondiente a [alongMeters] desde el origen.
  int shapeIndexAtDistance(List<GeoPoint> polyline, double alongMeters) {
    if (polyline.isEmpty) {
      return 0;
    }
    if (polyline.length == 1 || alongMeters <= 0) {
      return 0;
    }
    var cumulative = 0.0;
    for (var i = 0; i < polyline.length - 1; i++) {
      final segmentLength = _haversineMeters(polyline[i], polyline[i + 1]);
      final end = cumulative + segmentLength;
      if (alongMeters <= end + 0.5) {
        // En el vértice final del tramo → ese índice (siguiente edge).
        if (alongMeters >= end - 0.5) {
          return i + 1;
        }
        return i;
      }
      cumulative = end;
    }
    return polyline.length - 1;
  }

  double _polylineLengthMeters(List<GeoPoint> polyline) {
    if (polyline.length < 2) {
      return 0;
    }
    var total = 0.0;
    for (var i = 0; i < polyline.length - 1; i++) {
      total += _haversineMeters(polyline[i], polyline[i + 1]);
    }
    return total;
  }

  ({GeoPoint point, double t}) _projectOnSegment(
    GeoPoint p,
    GeoPoint a,
    GeoPoint b,
  ) {
    final ax = a.lng;
    final ay = a.lat;
    final bx = b.lng;
    final by = b.lat;
    final px = p.lng;
    final py = p.lat;
    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) {
      return (point: a, t: 0);
    }
    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    return (
      point: GeoPoint(lat: ay + clamped * dy, lng: ax + clamped * dx),
      t: clamped,
    );
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

/// Evita mostrar "Después · …" si ya viene en la instrucción actual.
bool shouldShowNextManeuverHint(
  NavigationManeuver current,
  NavigationManeuver? next,
) {
  if (next == null) {
    return false;
  }
  final nextText = next.instruction.trim().toLowerCase();
  if (nextText.isEmpty) {
    return false;
  }
  final currentText = current.instruction.toLowerCase();
  if (currentText.contains(nextText)) {
    return false;
  }
  final compactNext = nextText.replaceAll(RegExp(r'[.,]'), ' ').trim();
  final words = compactNext.split(RegExp(r'\s+')).where((w) => w.length > 3);
  var hits = 0;
  for (final word in words.take(4)) {
    if (currentText.contains(word)) {
      hits++;
    }
  }
  return hits < 3;
}
